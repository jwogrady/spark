#!/usr/bin/env bash
# Behavioral suite for `spark course` (#469): which objective is coherent next.
#
# Three questions, three owners, and the blur between them is the defect:
#
#   spark brief   where did the lifecycle leave off?
#   spark course  which objective is coherent to pursue?   <- this verb
#   spark next    which issue inside that objective?
#
# So the suite asserts the five outcomes, that UNKNOWN stays an evidence state
# beside them rather than becoming a sixth, that the verb records nothing, and
# that it neither recomputes brief's stage nor picks an issue.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

tools="git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm"

# --- the snapshot fixtures -------------------------------------------------
#
# A milestone's work state is now read WITH its issue hierarchy in one request,
# because GitHub's raw `open_issues` counts the release gate itself: a milestone
# whose every leaf is closed still counts 1 while its gate waits for
# certification, so the finished state was indistinguishable from the working
# one (#602).
#
# These builders emit the JSON the real query returns, and the stub applies the
# --jq the BINARY passes. Handing back pre-shaped rows would leave the
# production shaping untested — which is exactly how a fixture ends up asserting
# a state the repository cannot actually reach.

# The node builders are the shared ones (lib.sh): `course` and `next` read ONE
# capture now, so a fixture that described the same issue differently for each
# could make the two verbs disagree in a way no repository can.

# lf <n> [parent] — an open issue carrying no sub-issues: actionable leaf work.
# A leaf inside a gated milestone sits under the gate, because the gate carries
# the milestone's scope — an open issue outside it is a governed failure, not a
# shape this suite is free to invent.
lf() { gate_iss "$1" - "${2:--}" OPEN - feature; }

# ct <n> <sub-csv> [subs-truncated] — the RELEASE GATE: an open issue carrying
# sub-issues AND the governed role. Carrying sub-issues is no longer what makes
# it the gate (#605), so the fixture states the role it means.
ct() { SUBS_TRUNCATED="${3:-false}" gate_iss "$1" - - OPEN "$2" chore release-gate; }

# op <n> <sub-csv> [parent] — an ORDINARY parent: a container with no role. The
# distinction ct/op is the one #605 introduced and the one this suite has to be
# able to make, or "has sub-issues" quietly becomes "is the release gate" again.
op() { gate_iss "$1" - "${3:--}" OPEN "$2" chore; }

# mnode <title> <issue-nodes> [issues-truncated] — one open milestone.
mnode() { ISSUES_TRUNCATED="${3:-false}" gate_mil "$1" "$2"; }

# msnap <milestone-nodes> [milestones-truncated] — the whole response.
#
# NOT `snap`: section 8 defines a `snap` of its own for the read-only
# fingerprint, and the later definition would silently take over here.
msnap() { MILESTONES_TRUNCATED="${2:-false}" gate_cap "$1"; }

# stub_path <dir> <snapshot-json> — a PATH whose gh answers the hierarchy
# snapshot with the given JSON and nothing else. Milestone state is the fact
# that decides a course, so each outcome below is driven by it directly.
stub_path() {
  local d="$1" ms="$2" t
  mkdir -p "$d"
  for t in $tools; do
    src="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$src" ] && ln -sf "$src" "$d/$t" 2>/dev/null || true
  done
  printf '%s' "$ms" > "$d/snap.json"
  stub_gh "$d/gh" <<'GHEOF'
case "${1:-}" in
  auth) exit 0 ;;
  repo) printf 'o/r\n'; exit 0 ;;
esac
isq=0; jqexpr=""; prev=""
for a in "$@"; do
  [ "$a" = "graphql" ] && isq=1
  [ "$prev" = "--jq" ] && jqexpr="$a"
  prev="$a"
done
if [ "$isq" = 1 ]; then
  if [ -n "$jqexpr" ]; then jq -r "$jqexpr" "$(dirname "$0")/snap.json"
  else cat "$(dirname "$0")/snap.json"; fi
  exit 0
fi
exit 0
GHEOF
}

r="$WORK/repo"
mkdir -p "$r/src" "$r/.spark" "$r/.github/ISSUE_TEMPLATE"
git -C "$r" init -q
git -C "$r" config user.email t@e.invalid
git -C "$r" config user.name T
echo 'x = 1' > "$r/src/a.py"
echo 'name: Bug' > "$r/.github/ISSUE_TEMPLATE/bug.yml"
echo '## What' > "$r/.github/pull_request_template.md"
echo '{}' > "$r/release-please-config.json"
printf '{\n  "project.classification": "existing",\n  "project.classified": "2026-01-01"\n}\n' \
  > "$r/.spark/preferences.json"
git -C "$r" add -A
git -C "$r" commit -qm "chore: seed"

# The snapshot is answered whole; gh's --jq does the rest, so the stub returns
# the response shape rather than pre-filtered rows.
#
# v0.9 holds a gate (#900) and one open leaf (#901): work to do.
ONLY_ACTIVE="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901,902),$(lf 901 900)")")"
# v0.9 holds work; v1.0 is open with nothing left at all. Two directions.
ACTIVE="$(msnap "$(mnode 'v0.9 — Now' "$(lf 901)"),$(mnode 'v1.0 — Later' '')")"
# v0.9 is open with nothing left at all — no work, and no gate either.
ONLY_DONE="$(msnap "$(mnode 'v0.9 — Now' '')")"
NONE="$(msnap '')"
# THE REAL END-OF-RELEASE SHAPE: the milestone is open, its release gate #900 is
# open, every one of the gate's sub-issues is closed, and GitHub's raw
# open_issues is therefore 1. This is the state every Spark milestone ends in,
# and the one the old fixture could not express.
END_OF_RELEASE="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901,902)")")"
# The same milestone one issue earlier: the gate plus a single open leaf.
END_MINUS_ONE="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901,902),$(lf 901 900)")")"
# An ordinary milestone that runs no release gate at all.
NO_GATE="$(msnap "$(mnode 'v0.9 — Now' "$(lf 901),$(lf 902)")")"
# THE SHAPE "FIRST CONTAINER = GATE" COULD NOT FAIL: an ordinary parent whose
# every child has closed, and no release gate anywhere. It carries sub-issues,
# so shape alone calls it the boundary — and the milestone then reads as
# finished and awaiting certification when it has no boundary at all.
ORDINARY_PARENT="$(msnap "$(mnode 'v0.9 — Now' "$(op 700 701)")")"
# Two containers, one of them the gate. Which one wins must not depend on the
# order GitHub returned them in, so the same milestone is built both ways.
TWO_FWD="$(msnap "$(mnode 'v0.9 — Now' "$(op 800 810 900),$(ct 900 901,902)")")"
TWO_REV="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901,902),$(op 800 810 900)")")"
# A BOUNDARY THAT DOES NOT HOLD. #902 is open in the milestone and outside the
# gate's hierarchy, so the gate does not carry the milestone it is meant to
# certify. Nothing is releasable across a boundary like that.
BROKEN_GATE="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901),$(lf 902)")")"
# Two marked gates: the boundary is ambiguous, and no single issue can be named
# as the thing that remains.
TWO_GATES="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901),$(ct 910 911)")")"

run_course() { # <milestones-json> -> OUT / RC
  local ms="$1" d="$WORK/p$RANDOM"
  stub_path "$d" "$ms"
  RC=0
  OUT="$(cd "$r" && env PATH="$d" "$SPARK" course 2>&1)" || RC=$?
}

# ============ 1. CONTINUE ==================================================
run_course "$ONLY_ACTIVE"
assert_rc "an active milestone with open work continues" 0 "$RC"
assert_contains "and names the course" "Course: CONTINUE CURRENT COURSE" "$OUT"
assert_contains "and hands off to the issue selector" "next: spark next" "$OUT"
# It must not pick the issue itself: that is next's question.
case "$OUT" in
  *"selected  #"*) bad "course selected an issue; that is spark next's job" ;;
  *) ok ;;
esac

# ============ 2. CLOSE / RELEASE ==========================================
run_course "$ONLY_DONE"
assert_rc "a finished milestone is a closure course" 0 "$RC"
assert_contains "named as such" "Course: CLOSE / RELEASE COMPLETED COURSE" "$OUT"
assert_contains "and routed to certification, not new work" "not new feature work" "$OUT"

# ============ 3. PLAN A NEW COURSE ========================================
run_course "$NONE"
assert_rc "no milestone at all is a planning course" 0 "$RC"
assert_contains "named as such" "Course: PLAN A NEW COURSE" "$OUT"
assert_contains "and routed to plan" "spark:plan" "$OUT"

# ============ 4. HUMAN DECISION REQUIRED ==================================
# An active milestone AND a finished-but-open one are two materially different
# directions. Spark states both and chooses neither.
run_course "$ACTIVE"
assert_rc "two plausible directions stop for the human" 5 "$RC"
assert_contains "named as such" "Course: HUMAN DECISION REQUIRED" "$OUT"
assert_contains "naming both directions" "two materially different directions" "$OUT"
assert_contains "and refusing to choose" "Spark will not" "$OUT"
# It must not have quietly picked one anyway.
case "$OUT" in
  *"Course: CONTINUE"*|*"Course: CLOSE"*) bad "course chose a direction it had called ambiguous" ;;
  *) ok ;;
esac

# ============ 5. NOT ASSESSED is an evidence state, not an outcome ========
# UNREADABILITY HAS MORE THAN ONE SHAPE, and the earlier version of this section
# only tested the easy one. Removing gh from PATH takes an early branch; an
# authenticated gh whose requests FAIL takes the ordinary path with empty
# results, and that shape reported PLAN A NEW COURSE at exit 0 — a confident
# strategic recommendation built on evidence that was never read.
#
# Both shapes are exercised below, and each must reach NOT ASSESSED.
nogh="$WORK/nogh"; mkdir -p "$nogh"
for t in $tools; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$nogh/$t" 2>/dev/null || true
done
RC=0; OUT="$(cd "$r" && env PATH="$nogh" "$SPARK" course 2>&1)" || RC=$?
assert_rc "an unreadable course is not assessed" 3 "$RC"
assert_contains "named as such" "Course: NOT ASSESSED" "$OUT"
assert_contains "and says what it could not read" "needs an authenticated gh" "$OUT"
# The critical separation: it must not be reported as a decision awaiting a human.
case "$OUT" in
  *"HUMAN DECISION REQUIRED"*) bad "unread evidence was reported as an owed decision" ;;
  *) ok ;;
esac
# ...nor as a negative fact about the repository.
case "$OUT" in
  *"PLAN A NEW COURSE"*) bad "an unreadable milestone surface was read as having none" ;;
  *) ok ;;
esac

# --- shape two: gh present and authenticated, every request failing.
failgh="$WORK/failgh"; mkdir -p "$failgh"
for t in $tools; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$failgh/$t" 2>/dev/null || true
done
stub_gh "$failgh/gh" <<'GHEOF'
case "${1:-}" in auth) exit 0 ;; esac
echo "API rate limit exceeded" >&2
exit 1
GHEOF
RC=0; OUT="$(cd "$r" && env PATH="$failgh" "$SPARK" course 2>&1)" || RC=$?
assert_rc "an authenticated reader whose requests fail is NOT ASSESSED" 3 "$RC"
assert_contains "named as such" "Course: NOT ASSESSED" "$OUT"
# The specific inversion #594 reported: a failed read must never become the
# claim that the repository has no milestones.
case "$OUT" in
  *"PLAN A NEW COURSE"*) bad "a failed milestone read was reported as having no milestones" ;;
  *) ok ;;
esac
case "$OUT" in
  *"HUMAN DECISION REQUIRED"*) bad "a failed read was reported as an owed decision" ;;
  *) ok ;;
esac
# ...and no course may be asserted at exit 0 on evidence that was not read.
if [ "$RC" -eq 0 ]; then bad "a course was asserted at exit 0 after the read failed"; else ok; fi

# --- the two milestone facts come from ONE captured inventory.
#
# Counting reads would be wrong: the reconciliation slate legitimately reads
# milestones for its own residue finding. The PROPERTY is that course's active
# and completed facts describe ONE moment, so the stub below answers differently
# on each call. Derived from a single capture, both facts come from the first
# answer and the verdict is the ambiguity. Derived from separate reads, the
# completed fact would come from the second answer, the ambiguity would vanish,
# and the run would report a confident CONTINUE assembled from two moments.
chggh="$WORK/chggh"; mkdir -p "$chggh"
for t in $tools; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$chggh/$t" 2>/dev/null || true
done
printf '%s' "$ACTIVE" > "$chggh/first.json"
printf '%s' "$ONLY_ACTIVE" > "$chggh/rest.json"
stub_gh "$chggh/gh" <<'GHEOF'
case "${1:-}" in
  auth) exit 0 ;;
  repo) printf 'o/r\n'; exit 0 ;;
esac
isq=0; jqx=""; prev=""
for a in "$@"; do
  [ "$a" = "graphql" ] && isq=1
  [ "$prev" = "--jq" ] && jqx="$a"
  prev="$a"
done
if [ "$isq" = 1 ]; then
  d="$(dirname "$0")"
  if [ -f "$MSFLAG" ]; then f="$d/rest.json"; else f="$d/first.json"; : > "$MSFLAG"; fi
  if [ -n "$jqx" ]; then jq -r "$jqx" "$f"; else cat "$f"; fi
  exit 0
fi
exit 0
GHEOF
export MSFLAG="$WORK/ms.flag"; rm -f "$MSFLAG"
RC=0; OUT="$(cd "$r" && env PATH="$chggh" MSFLAG="$MSFLAG" "$SPARK" course 2>&1)" || RC=$?
assert_contains "both milestone facts come from one captured moment" \
  "HUMAN DECISION REQUIRED" "$OUT"
case "$OUT" in
  *"CONTINUE CURRENT COURSE"*) bad "the completed fact came from a later read than the active one" ;;
  *) ok ;;
esac

# ============ 6. REPAIR when truth contradicts the course =================
# The recorded intent names only closed issues while a milestone is active: the
# course exists, and what it claims to be pursuing is contradicted.
printf '{\n  "next_action": "finish #4242",\n  "blockers": "",\n  "updated": "2026-01-02"\n}\n' \
  > "$r/.spark/state.json"
git -C "$r" add -A; git -C "$r" commit -qm "chore: intent"
dclosed="$WORK/pclosed"
stub_path "$dclosed" "$ONLY_ACTIVE"
stub_gh "$dclosed/gh" <<'GHEOF'
case "${1:-}" in
  auth) exit 0 ;;
  repo) printf 'o/r\n'; exit 0 ;;
esac
isq=0; jqexpr=""; prev=""
for a in "$@"; do
  [ "$a" = "graphql" ] && isq=1
  [ "$prev" = "--jq" ] && jqexpr="$a"
  prev="$a"
done
if [ "$isq" = 1 ]; then
  if [ -n "$jqexpr" ]; then jq -r "$jqexpr" "$(dirname "$0")/snap.json"
  else cat "$(dirname "$0")/snap.json"; fi
  exit 0
fi
for a in "$@"; do
  case "$a" in
    */issues/*) echo closed; exit 0 ;;
  esac
done
exit 0
GHEOF
RC=0; OUT="$(cd "$r" && env PATH="$dclosed" "$SPARK" course 2>&1)" || RC=$?
assert_rc "a contradicted course is a repair course" 0 "$RC"
assert_contains "named as such" "Course: REPAIR CURRENT COURSE" "$OUT"
assert_contains "citing the contradiction" "recorded intent names only closed work" "$OUT"
assert_contains "and routed to reconciliation" "spark reconcile" "$OUT"
rm -f "$r/.spark/state.json"
git -C "$r" add -A; git -C "$r" commit -qm "chore: drop intent"

# ============ 7. it consumes, it does not rediscover ======================
# The evidence lines are produced by the truth pass and the slate. Asserting the
# keys exist is weak; asserting the verb MOVES when those producers move is not.
run_course "$ONLY_ACTIVE"
assert_contains "the report cites truth-pass evidence" "truth: contradictions" "$OUT"
assert_contains "and slate evidence" "slate: decisions owed" "$OUT"
d7="$WORK/p7"; stub_path "$d7" "$ONLY_ACTIVE"
tsv="$(cd "$r" && env PATH="$d7" "$SPARK" course --tsv 2>&1)" || true
for key in truth_mechanical truth_decisions truth_unread intent_spent slate_decisions slate_unread; do
  assert_contains "tsv carries $key from the owning producer" "$key" "$tsv"
done

# ============ 8. READ-ONLY ================================================
snap() {
  ( cd "$1" && find . -path ./.git -prune -o -type f -print0 2>/dev/null \
      | LC_ALL=C sort -z | xargs -0 -r cksum
    echo "--refs--";   git -C "$1" show-ref 2>/dev/null || true
    echo "--status--"; git -C "$1" status --porcelain 2>/dev/null || true
    echo "--objs--";   find "$1/.git/objects" -type f 2>/dev/null | LC_ALL=C sort )
}
before="$(snap "$r")"
d8="$WORK/p8"; stub_path "$d8" "$ACTIVE"
export WLOG="$WORK/writes.log"; : > "$WLOG"
cat > "$d8/gh" <<'GHEOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in
    --method|-X|-f|-F|edit|create|close|delete|label) echo "WRITE $*" >> "$WLOG"; exit 0 ;;
  esac
done
case "${1:-}" in auth) exit 0 ;; esac
jqexpr=""; prev=""
for a in "$@"; do
  [ "$prev" = "--jq" ] && jqexpr="$a"
  prev="$a"
done
for a in "$@"; do
  case "$a" in
    *milestones*)
      if [ -n "$jqexpr" ]; then jq -r "$jqexpr" "$(dirname "$0")/milestones.json"
      else cat "$(dirname "$0")/milestones.json"; fi
      exit 0 ;;
  esac
done
exit 0
GHEOF
chmod +x "$d8/gh"
( cd "$r" && env PATH="$d8" WLOG="$WLOG" "$SPARK" course >/dev/null 2>&1 ) || true
assert_eq "course changes nothing on disk" "$before" "$(snap "$r")"
assert_eq "and makes no write-shaped gh call" "" "$(cat "$WLOG")"
run_course "$ACTIVE"
assert_contains "and says so" "no milestone, priority, disposition or direction was recorded" "$OUT"

# ============ 9. the ownership split is stated, not implied ===============
run_course "$ONLY_ACTIVE"
assert_contains "it points at brief for the lifecycle position" "spark brief" "$OUT"
assert_contains "and at next for the issue" "spark next" "$OUT"
assert_contains "and disclaims both" "This verb answers neither" "$OUT"
# brief's own output must be untouched by this verb existing.
b1="$(cd "$r" && env PATH="$nogh" "$SPARK" brief 2>&1)" || true
case "$b1" in
  *"Course:"*) bad "course leaked its verdict into brief" ;;
  *) ok ;;
esac

# ============ 10. one authority for the current milestone =================
# `next` and `course` must agree about which milestone is running, because they
# read the same function rather than each deciding for themselves.
d10="$WORK/p10"; stub_path "$d10" "$ONLY_ACTIVE"
sel="$(cd "$r" && env PATH="$d10" bash -c '. '"$SPARK"'; current_milestone' 2>/dev/null)"
assert_eq "current_milestone names the active milestone" "v0.9 — Now" "$sel"
tsv10="$(cd "$r" && env PATH="$d10" "$SPARK" course --tsv 2>&1)" || true
assert_contains "and course reports the same one" "$(printf 'active\tv0.9 — Now')" "$tsv10"

# ============ 11. the real end-of-release shape (#602) ====================
# Every Spark milestone ends here: implementation finished, release gate still
# open, and GitHub's raw open_issues therefore 1. Reading that count as "work
# remains" made the finished state indistinguishable from the working one —
# `course` said CONTINUE and routed to `spark next`, which then reported there
# was no leaf to select.
run_course "$END_OF_RELEASE"
assert_rc "a finished-but-unreleased milestone derives a course at exit 0" 0 "$RC"
assert_contains "and it is the closure course" "Course: CLOSE / RELEASE COMPLETED COURSE" "$OUT"
assert_contains "naming the gate as what remains" "release gate #900" "$OUT"
assert_contains "routed to certification, not new work" "not new feature work" "$OUT"
# The specific inversion: it must not send the reader after work that is not there.
case "$OUT" in
  *"CONTINUE CURRENT COURSE"*) bad "an open release gate was counted as open work" ;;
  *) ok ;;
esac
case "$OUT" in
  *"next: spark next"*) bad "a finished milestone routed to the issue selector" ;;
  *) ok ;;
esac

# One open leaf changes the answer, so the case above cannot be passing because
# the verb stopped distinguishing states.
run_course "$END_MINUS_ONE"
assert_rc "the same milestone with one leaf left continues" 0 "$RC"
assert_contains "named as such" "Course: CONTINUE CURRENT COURSE" "$OUT"
assert_contains "and routed to the selector" "next: spark next" "$OUT"

# An ordinary milestone that runs no gate is untouched by any of this.
run_course "$NO_GATE"
assert_rc "a milestone with no gate is unaffected" 0 "$RC"
assert_contains "and still continues" "Course: CONTINUE CURRENT COURSE" "$OUT"

# ============ 11b. a container is not a boundary (#605) ===================
# An ordinary parent carries sub-issues, so under "the first container is the
# gate" this milestone reported that only its release gate remained — a release
# recommendation over a milestone that declares no release boundary at all.
# Which issue is the gate is a governed fact now, and `course` reads it rather
# than recognising a shape.
run_course "$ORDINARY_PARENT"
case "$OUT" in
  *"release gate #700"*) bad "an ordinary parent was named as the release gate" ;;
  *) ok ;;
esac
# The work IS done — every child of #700 has closed — so a closure course is
# the honest reading. What it must not do is claim a boundary that does not
# exist, or claim the milestone holds nothing open when a container remains.
assert_contains "the finished milestone still closes out" \
  "Course: CLOSE / RELEASE COMPLETED COURSE" "$OUT"
case "$OUT" in
  *"no milestone has open work"*)
    bad "an open container was reported as no open work at all" ;;
  *) ok ;;
esac

# With two containers present and exactly one of them marked, the marked one is
# the gate — and the answer cannot depend on the order they arrived in. The
# whole rendered course is compared, so this is a claim about the rule rather
# than about one line of it.
run_course "$TWO_FWD"; FWD_OUT="$OUT"; FWD_RC="$RC"
run_course "$TWO_REV"; REV_OUT="$OUT"; REV_RC="$RC"
assert_contains "the marked container is the gate" "release gate #900" "$FWD_OUT"
case "$FWD_OUT" in
  *"release gate #800"*) bad "the ordinary container was named as the gate" ;;
  *) ok ;;
esac
assert_eq "and enumeration order changes nothing" "$FWD_OUT" "$REV_OUT"
assert_eq "nor the exit code" "$FWD_RC" "$REV_RC"

# ============ 11c. a boundary that does not hold is repaired, not released ==
# A release recommendation is a claim about a boundary. When the projection
# reports that boundary broken — open work outside it, or two of them — there is
# nothing to certify across, and the course is to repair it. Reading a broken
# gate as an ordinary one is how a release gets recommended over work the gate
# does not govern.
run_course "$BROKEN_GATE"
assert_contains "an unsound boundary is a repair course" \
  "Course: REPAIR CURRENT COURSE" "$OUT"
assert_contains "naming what is wrong with it" "outside its hierarchy" "$OUT"
case "$OUT" in
  *"CLOSE / RELEASE COMPLETED COURSE"*)
    bad "a release was recommended across a boundary that does not hold" ;;
  *) ok ;;
esac
# And it is a KNOWN bad state, not an unreadable one: the evidence was read.
case "$OUT" in
  *"Course: NOT ASSESSED"*) bad "a broken gate was reported as unreadable" ;;
  *) ok ;;
esac

run_course "$TWO_GATES"
assert_contains "an ambiguous boundary is a repair course too" \
  "Course: REPAIR CURRENT COURSE" "$OUT"
assert_contains "naming the ambiguity" "at most one release gate" "$OUT"
case "$OUT" in
  *"CLOSE / RELEASE COMPLETED COURSE"*)
    bad "a release was recommended over two rival boundaries" ;;
  *) ok ;;
esac

# ============ 12. an unread hierarchy is never "no work left" =============
# A truncated page and an empty one are different answers. Reading the second
# from the first is how a partial read would become a release recommendation.
for trunc in ms issues subs; do
  case "$trunc" in
    ms)     j="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901,902)")" true)" ;;
    issues) j="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901,902)" true)")" ;;
    subs)   j="$(msnap "$(mnode 'v0.9 — Now' "$(ct 900 901,902 true)")")" ;;
  esac
  run_course "$j"
  assert_rc "a truncated $trunc surface is not assessed" 3 "$RC"
  assert_contains "named as such ($trunc)" "Course: NOT ASSESSED" "$OUT"
  case "$OUT" in
    *"CLOSE / RELEASE"*) bad "an unread $trunc surface was reported as a finished milestone" ;;
    *) ok ;;
  esac
  case "$OUT" in
    *"CONTINUE CURRENT COURSE"*) bad "an unread $trunc surface was reported as active work" ;;
    *) ok ;;
  esac
done

# ============ 13. course and next cannot disagree about work =============
# The whole defect was two implementations of one question. This asserts the
# property directly: for ONE snapshot, both verbs are run and their answers must
# describe the same repository.
agree="$WORK/agree"; mkdir -p "$agree/.spark" "$agree/.github/ISSUE_TEMPLATE"
git -C "$agree" init -q
git -C "$agree" config user.email t@e.invalid
git -C "$agree" config user.name T
echo 'name: Bug' > "$agree/.github/ISSUE_TEMPLATE/bug.yml"
echo '## What' > "$agree/.github/pull_request_template.md"
echo '{}' > "$agree/release-please-config.json"
git -C "$agree" add -A; git -C "$agree" commit -qm seed

abin="$WORK/abin"; mkdir -p "$abin"
for t in $tools; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$abin/$t" 2>/dev/null || true
done
# ISSUES is what `gh issue list` returns; SNAP is the hierarchy snapshot. Both
# are answered through the --jq the BINARY passes.
stub_gh "$abin/gh" <<'AGEOF'
case "${1:-}" in
  auth) exit 0 ;;
  repo) printf 'o/r\n'; exit 0 ;;
esac
isq=0; jqx=""; prev=""
for a in "$@"; do
  [ "$a" = "graphql" ] && isq=1
  [ "$prev" = "--jq" ] && jqx="$a"
  prev="$a"
done
if [ "$isq" = 1 ]; then
  if [ -n "$jqx" ]; then printf '%s' "$SNAP" | jq -r "$jqx"; else printf '%s' "$SNAP"; fi
  exit 0
fi
if [ "${1:-}" = "issue" ]; then
  if [ -n "$jqx" ]; then printf '%s' "$ISSUES" | jq -r "$jqx"; else printf '%s' "$ISSUES"; fi
  exit 0
fi
# The dependency graph is read through the shared reader, which validates every
# row (number, state, repository) before emitting it: "no blockers" is an empty
# answer, never a pre-shaped count that assumed one consumer's jq.
for a in "$@"; do
  case "$a" in *dependencies*) exit 0 ;; esac
done
exit 0
AGEOF

# Both carry a COMPLETE governed slate, so the selection turns on the hierarchy
# rather than on missing metadata: an issue lacking `docs-impact` stops `next`
# at exit 5 with a decision to make, before it ever reaches the question here.
di='{"name":"docs-impact:none"}'
ISS_GATE_ONLY="[{\"number\":900,\"title\":\"Gate\",\"labels\":[{\"name\":\"chore\"},{\"name\":\"P1\"},$di]}]"
ISS_WITH_LEAF="[{\"number\":900,\"title\":\"Gate\",\"labels\":[{\"name\":\"chore\"},{\"name\":\"P1\"},$di]},{\"number\":901,\"title\":\"Real work\",\"labels\":[{\"name\":\"bug\"},{\"name\":\"P1\"},$di]}]"

ag() { # <snap> <issues> <verb...> -> OUT / RC
  local sn="$1" iss="$2"; shift 2
  RC=0
  OUT="$(cd "$agree" && env PATH="$abin" SNAP="$sn" ISSUES="$iss" "$SPARK" "$@" 2>&1)" || RC=$?
}

# The finished shape: course says close it, and next agrees there is no leaf.
ag "$END_OF_RELEASE" "$ISS_GATE_ONLY" course
assert_contains "course closes the finished milestone" "CLOSE / RELEASE COMPLETED COURSE" "$OUT"
ag "$END_OF_RELEASE" "$ISS_GATE_ONLY" next
assert_rc "and next reports the known answer: nothing to select" 1 "$RC"
assert_contains "naming why" "no open leaf issues" "$OUT"

# One leaf later: course continues, and next selects that very leaf.
ag "$END_MINUS_ONE" "$ISS_WITH_LEAF" course
assert_contains "course continues while a leaf is open" "CONTINUE CURRENT COURSE" "$OUT"
ag "$END_MINUS_ONE" "$ISS_WITH_LEAF" next
assert_rc "and next selects it" 0 "$RC"
assert_contains "naming the leaf" "selected  #901" "$OUT"
# The gate is a container and closes last; it is never the selection.
case "$OUT" in
  *"selected  #900"*) bad "next selected the release gate" ;;
  *) ok ;;
esac

finish
