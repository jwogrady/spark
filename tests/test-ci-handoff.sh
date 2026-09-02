#!/usr/bin/env bash
# Behavioural suite for #636 — hand off at the CI boundary instead of polling.
#
# When local certification is done and the PR is pushed, the only thing still
# changing is GitHub. An agent that sits in `gh pr checks` spends wall time and
# remote calls re-learning the same answer while having no productive work left.
#
# Three properties are pinned, and two of them are about NOT overreacting:
#
#   * a pending check is not a failure. A run that reported FAIL because CI has
#     not answered yet would send someone to debug work that is correct and
#     merely unfinished elsewhere;
#   * an unchanged read is reported as producing no information, and counted, so
#     a polling loop shows up as spend rather than as diligence;
#   * a failed check resumes from the GitHub failing set, not by replaying the
#     whole local episode to rediscover what CI already named.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "CI handoff without polling (#636)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

mkdir -p "$WORK/bin"
export GH_ROLLUP="$WORK/rollup.tsv"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "view" ]; then
  # ci_live asks for headRefOid + statusCheckRollup in one call and expects the
  # head first, tagged __civ_head__. Emit it only when GH_HEAD is configured, so
  # fixtures that do not exercise head-binding leave the head unreadable (empty).
  [ -n "${GH_HEAD:-}" ] && printf '__civ_head__\t%s\n' "$GH_HEAD"
  # "EMPTY" means gh answered successfully with no checks — a different fact
  # from gh failing, which the fixtures below hold apart.
  if [ "$(cat "$GH_ROLLUP" 2>/dev/null)" = "EMPTY" ]; then exit 0; fi
  [ -s "$GH_ROLLUP" ] || exit 1
  cat "$GH_ROLLUP"
  exit 0
fi
exit 0
STUB
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"
# Real GitHub always answers with a headRefOid; the stub emits one when GH_HEAD is
# set. Default it to the head the fixtures below certify (abc123) so a coherent
# observation exists; the #658 fixtures vary it to move or hide the head.
export GH_HEAD=abc123

rc() {
  local want="$1" desc="$2" got=0; shift 3
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$want" ]; then ok; else bad "$desc (wanted rc $want, got $got)"; fi
}

pending() { printf 'doctor\tPENDING\ngate\tPENDING\ntests\tPENDING\n' > "$GH_ROLLUP"; }
partial() { printf 'doctor\tSUCCESS\ngate\tPENDING\ntests\tPENDING\n' > "$GH_ROLLUP"; }
green_()  { printf 'doctor\tSUCCESS\ngate\tSUCCESS\ntests\tSUCCESS\n' > "$GH_ROLLUP"; }
failing() { printf 'doctor\tSUCCESS\ngate\tSUCCESS\ntests\tFAILURE\n' > "$GH_ROLLUP"; }

# --- the boundary must be recorded well enough to make stopping safe ---------
rc 1 "handoff needs the PR"  -- "$SPARK" ci handoff --run r1 --head abc123
rc 1 "handoff needs the exact head" -- "$SPARK" ci handoff --run r1 --pr 42
assert_contains "and says why the head matters" "cannot tell whether CI answered about this work" \
  "$("$SPARK" ci handoff --run r1 --pr 42 2>&1 || true)"
rc 1 "resuming without a handoff is refused" -- "$SPARK" ci resume --run never

# A flag whose value is missing must produce an error, not a silent abort. Under
# `set -e` a bare `shift` at $# = 0 kills the process with no output at all,
# which reads to a user as a crash rather than as a typo.
TRAIL="$("$SPARK" ci resume --run 2>&1 || true)"
if [ -n "$TRAIL" ]; then ok
else bad "a trailing flag with no value must not exit silently"; fi

pending
HO="$("$SPARK" ci handoff --run r1 --pr 42 --head abc123)"
assert_contains "the handoff records local completion" "local certification is complete" "$HO"
assert_contains "it names the required checks"         "doctor,gate,tests" "$HO"
assert_contains "it records the observed state"        "pending" "$HO"
assert_contains "and says to stop rather than poll"    "Stop here and resume on a CI transition" "$HO"

# The facts #574 must carry so a later resume needs no replay.
TEL="$("$SPARK" telemetry show --run r1 --head abc123)"
assert_contains "telemetry carries the PR"        "42" "$TEL"
assert_contains "telemetry carries the exact head" "abc123" "$TEL"

# --- pending is not a failure ------------------------------------------------
rc 4 "a pending rollup is its own state, not a failure" -- "$SPARK" ci resume --run r1
PEND="$("$SPARK" ci resume --run r1 2>&1 || true)"
assert_contains "it reports pending plainly"      "PENDING" "$PEND"
assert_contains "it says so explicitly"           "not a failure and not a reason to poll" "$PEND"
case "$PEND" in
  *FAIL*|*"CHANGES REQUIRED"*) bad "a pending check must never be reported as failure" ;;
  *) ok ;;
esac

# --- an unchanged read produces no information, and is counted ---------------
rc 3 "re-reading an unchanged rollup reports no transition" -- "$SPARK" ci status --run r1
NT="$("$SPARK" ci status --run r1 2>&1 || true)"
assert_contains "the read is named as informationless" "NO TRANSITION" "$NT"
assert_contains "and the waste is counted"             "unchanged of" "$NT"
assert_contains "with the cost stated"                 "waiting is free, asking again is not" "$NT"

# Polling is spend, so it lands in the same telemetry that tracks remote calls —
# which is what lets a convergence budget see a poll loop for what it is.
assert_contains "each read is counted as a remote request" "api requests" \
  "$("$SPARK" telemetry show --run r1 --head abc123)"

partial
rc 0 "a genuine state change is a transition" -- "$SPARK" ci status --run r1
rc 3 "the same rollup read again is not news" -- "$SPARK" ci status --run r1

green_
T2="$("$SPARK" ci status --run r1 2>&1 || true)"
# "NO TRANSITION" contains "TRANSITION", so a substring check alone would pass
# whichever answer the code gave. The negative case is what carries the weight.
assert_contains "a further change is reported as a transition" "TRANSITION" "$T2"
case "$T2" in
  *"NO TRANSITION"*) bad "a changed rollup must not report NO TRANSITION" ;;
  *) ok ;;
esac

# --- resume is the default verb, so it must count its own reads --------------
# The anti-polling guarantee cannot depend on a caller remembering to use
# `status`: `resume` is the default action and the one the runbook shows.
B="$("$SPARK" ci resume --run r1 --json)"
A="$("$SPARK" ci resume --run r1 --json)"
pb="$(printf '%s' "$B" | sed 's/.*"polls":\([0-9]*\).*/\1/')"
pa="$(printf '%s' "$A" | sed 's/.*"polls":\([0-9]*\).*/\1/')"
if [ "$pa" -gt "$pb" ]; then ok
else bad "resume must count its own reads (polls went $pb -> $pa)"; fi
ub="$(printf '%s' "$B" | sed 's/.*"unchanged":\([0-9]*\).*/\1/')"
ua="$(printf '%s' "$A" | sed 's/.*"unchanged":\([0-9]*\).*/\1/')"
if [ "$ua" -gt "$ub" ]; then ok
else bad "an unchanged rollup read via resume must still count as unchanged"; fi

# --- status honours --json ---------------------------------------------------
SJ="$("$SPARK" ci status --run r1 --json 2>&1 || true)"
assert_contains "status emits the machine shape" '"transition":' "$SJ"
case "$SJ" in
  *"NO TRANSITION"*) bad "status --json must not fall back to human text" ;;
  *) ok ;;
esac

# --- a failure resumes from GitHub evidence, not from a replay ---------------
failing
rc 2 "a failed rollup asks for changes" -- "$SPARK" ci resume --run r1
FAIL="$("$SPARK" ci resume --run r1 2>&1 || true)"
assert_contains "the verdict is changes required" "CHANGES REQUIRED" "$FAIL"
assert_contains "the failing check is named"      "tests — FAILURE" "$FAIL"
assert_contains "from GitHub, not from a replay"  "from GitHub rather than from replaying" "$FAIL"
assert_contains "and the whole suite is not the way to find it" "do not re-run the whole local certification" "$FAIL"
case "$FAIL" in *doctor\ —*) bad "a passing check must not appear in the failing set" ;; *) ok ;; esac

# --- a pass does not re-open local work --------------------------------------
green_
rc 0 "a green rollup is ready" -- "$SPARK" ci resume --run r1
PASS="$("$SPARK" ci resume --run r1)"
assert_contains "readiness is reported against the exact head" "abc123" "$PASS"
assert_contains "and local certification is not repeated" "do not re-run it" "$PASS"
assert_contains "the wasted reads are surfaced at the end" "produced no new information" "$PASS"

# --- an unreadable rollup is an unknown, never a pass ------------------------
: > "$GH_ROLLUP"
rc 1 "an unreadable rollup is NOT ASSESSED" -- "$SPARK" ci resume --run r1
UNK="$("$SPARK" ci resume --run r1 2>&1 || true)"
assert_contains "and says so"                "NOT ASSESSED" "$UNK"
assert_contains "refusing to call it a pass" "never a pass" "$UNK"
case "$UNK" in *READY*) bad "an unreadable rollup must never read as ready" ;; *) ok ;; esac

# A PR with no checks is a different fact from being unable to ask. Both refuse
# to become a pass; conflating them tells the operator to chase the wrong thing.
printf 'EMPTY\n' > "$GH_ROLLUP"
rc 1 "a PR with no checks is NOT ASSESSED" -- "$SPARK" ci resume --run r1
NOCHK="$("$SPARK" ci resume --run r1 2>&1 || true)"
assert_contains "and is named as having none" "no checks registered" "$NOCHK"
assert_contains "not as an unread rollup"     "not the same as everything having passed" "$NOCHK"
case "$NOCHK" in *READY*) bad "a PR with no checks must never read as ready" ;; *) ok ;; esac

# --- machine shape -----------------------------------------------------------
green_
J="$("$SPARK" ci resume --run r1 --json)"
assert_contains "json carries the state" '"state":"passing"' "$J"
assert_contains "json carries the head"  '"head":"abc123"' "$J"
assert_contains "json counts the reads"  '"unchanged":' "$J"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$J" | jq empty >/dev/null 2>&1 && ok || bad "--json must emit valid JSON"
else ok; fi

# --- the documented model ----------------------------------------------------
DOC="$repo_root/docs/ops/ci-handoff.md"
[ -f "$DOC" ] && ok || bad "the CI handoff model must be documented at docs/ops/ci-handoff.md"
if [ -f "$DOC" ]; then
  assert_contains "the record states pending is not failure" "not a failure" "$(cat "$DOC")"
fi

# --- #658: a moved PR head cannot report the old certified head READY ----------
# The exact-SHA boundary must survive a push/rebase. Certify head h1 while green,
# then move the PR to a NEW green head h2. resume and status must refuse to call h1
# READY — the live rollup describes h2, which local certification never covered.
green_
export GH_HEAD=h1-certified
"$SPARK" ci handoff --run stale --pr 42 --head h1-certified >/dev/null 2>&1
export GH_HEAD=h2-newhead                       # the PR moves; CI is green on the new head
JS="$("$SPARK" ci resume --run stale --json 2>/dev/null || true)"
assert_contains "resume on a moved head reports stale, not passing" '"state":"stale"' "$JS"
assert_contains "resume records the head the rollup actually described" '"observed_head":"h2-newhead"' "$JS"
rc 5 "a moved-head resume exits stale (5), never READY (0)" -- "$SPARK" ci resume --run stale
HUM="$("$SPARK" ci resume --run stale 2>&1 || true)"
assert_contains "the human output names the stale outcome" "STALE" "$HUM"
if printf '%s' "$HUM" | grep -q "READY"; then bad "a moved head must never print READY for the old commit"; else ok; fi
rc 5 "status on a moved head exits stale (5)" -- "$SPARK" ci status --run stale
assert_contains "status records the observed head" '"observed_head":"h2-newhead"' \
  "$("$SPARK" ci status --run stale --json 2>/dev/null || true)"
# handoff itself refuses a --head that is not the PR's current head.
export GH_HEAD=current-head
rc 1 "handoff refuses a --head that is not the current head" -- "$SPARK" ci handoff --run stale2 --pr 42 --head not-current
assert_contains "handoff names both heads" "not the PR's current head" \
  "$("$SPARK" ci handoff --run stale2 --pr 42 --head not-current 2>&1 || true)"
rc 0 "handoff accepts the PR's current head" -- "$SPARK" ci handoff --run stale3 --pr 42 --head current-head
# A moved head whose new head has NO checks yet is STALE, not "no checks": the
# stale decision precedes sentinel classification.
printf 'EMPTY\n' > "$GH_ROLLUP"; export GH_HEAD=h2-newhead
rc 5 "a moved head with no checks is stale, not nochecks" -- "$SPARK" ci resume --run stale
assert_contains "reported stale, not a nochecks sentinel" '"state":"stale"' \
  "$("$SPARK" ci resume --run stale --json 2>/dev/null || true)"
# A response carrying checks but NO head is not a coherent observation: unreadable,
# never a pass, and handoff refuses to record against it.
green_; unset GH_HEAD
rc 1 "checks with no readable head are unreadable, never a pass" -- "$SPARK" ci resume --run stale
assert_contains "an unreadable head is not a pass" "never a pass" \
  "$("$SPARK" ci resume --run stale 2>&1 || true)"
rc 1 "handoff refuses when the current head is unreadable" -- "$SPARK" ci handoff --run stale4 --pr 42 --head anything
assert_contains "and names the unverifiable certification" "could not read the PR's current head" \
  "$("$SPARK" ci handoff --run stale4 --pr 42 --head anything 2>&1 || true)"
export GH_HEAD=abc123                            # restore the coherent default for later fixtures

# --- MUTATION CONTROL --------------------------------------------------------
# Stop comparing against the recorded snapshot, so every read looks like a
# transition. The no-transition fixture must go red — reporting news where
# there is none is precisely what makes a polling loop feel productive.
mutant_runtime 's|if \[ "$newdigest" = "$civ_digest" \]; then|if false; then|'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

mgot=0
"$MUT" ci status --run r1 >/dev/null 2>&1 || mgot=$?
if [ "$mgot" = "3" ]; then
  bad "MUTATION control — the unchanged read still reported no transition; the fixture does not discriminate"
else ok; fi

finish
