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

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}
tools="git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm"

# stub_path <dir> <milestones-json> — a PATH whose gh answers the milestone
# query with the given JSON and nothing else. Milestone state is the fact that
# decides a course, so each outcome below is driven by it directly.
stub_path() {
  local d="$1" ms="$2" t
  mkdir -p "$d"
  for t in $tools; do
    src="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$src" ] && ln -sf "$src" "$d/$t" 2>/dev/null || true
  done
  printf '%s' "$ms" > "$d/milestones.json"
  cat > "$d/gh" <<'GHEOF'
#!/usr/bin/env bash
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
  chmod +x "$d/gh"
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

# The milestone query is answered with the raw array; gh's --jq does the rest,
# so the stub returns objects rather than pre-filtered titles.
ACTIVE='[{"title":"v0.9 — Now","open_issues":3},{"title":"v1.0 — Later","open_issues":0}]'
ONLY_ACTIVE='[{"title":"v0.9 — Now","open_issues":3}]'
ONLY_DONE='[{"title":"v0.9 — Now","open_issues":0}]'
NONE='[]'

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

# ============ 6. REPAIR when truth contradicts the course =================
# The recorded intent names only closed issues while a milestone is active: the
# course exists, and what it claims to be pursuing is contradicted.
printf '{\n  "next_action": "finish #4242",\n  "blockers": "",\n  "updated": "2026-01-02"\n}\n' \
  > "$r/.spark/state.json"
git -C "$r" add -A; git -C "$r" commit -qm "chore: intent"
dclosed="$WORK/pclosed"
stub_path "$dclosed" "$ONLY_ACTIVE"
cat > "$dclosed/gh" <<'GHEOF'
#!/usr/bin/env bash
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
    */issues/*) echo closed; exit 0 ;;
  esac
done
exit 0
GHEOF
chmod +x "$dclosed/gh"
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

finish
