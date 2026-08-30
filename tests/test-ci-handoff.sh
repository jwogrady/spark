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
  [ -s "$GH_ROLLUP" ] || exit 1
  cat "$GH_ROLLUP"
  exit 0
fi
exit 0
STUB
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

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
assert_contains "and it reports the new state" "TRANSITION" \
  "$("$SPARK" ci status --run r1 2>&1 || true)"

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

# --- MUTATION CONTROL --------------------------------------------------------
# Stop comparing against the recorded snapshot, so every read looks like a
# transition. The no-transition fixture must go red — reporting news where
# there is none is precisely what makes a polling loop feel productive.
MUT="$WORK/plugin/bin/spark-mutant"
sed 's|if \[ "$newdigest" = "$civ_digest" \]; then|if false; then|' "$SPARK" > "$MUT"
chmod +x "$MUT"
if ! cmp -s "$SPARK" "$MUT"; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

mgot=0
"$MUT" ci status --run r1 >/dev/null 2>&1 || mgot=$?
if [ "$mgot" = "3" ]; then
  bad "MUTATION control — the unchanged read still reported no transition; the fixture does not discriminate"
else ok; fi

finish
