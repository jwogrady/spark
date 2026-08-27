#!/usr/bin/env bash
# Behavioural suite for #517: `verify` checks every mutation-bearing record.
#
# It read title and labels only. So a slate could declare a milestone, a
# parent/child hierarchy, a hard dependency and an explicit delivery order, have
# every one of them absent or wrong on GitHub, and still be certified with
# "PASS — GitHub matches the artifact" — because nothing looked. The milestone
# field was even read from the artifact and then discarded.
#
# The whole call log of the old command, for the artifact below, was:
#
#   gh auth status
#   gh issue view 100 --json title / --json labels
#   gh issue view 101 --json title / --json labels
#
# Every scenario here keeps title and labels CORRECT and breaks exactly one other
# fact, because that is the case the defect made invisible.
#
# Measured discrimination, not asserted: reverting the coverage turns 42 of the
# 48 assertions red, and the last two reproduce the report verbatim — "PASS —
# GitHub matches the artifact" for a repository with the wrong milestone, the
# wrong body, and no hierarchy, dependency or order at all.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
work="$WORK/w"; mkdir -p "$work"

printf 'Parent body line\nsecond line\n' > "$work/parent.md"
printf 'Child body line\n'               > "$work/child.md"
printf 'Second child body\n'             > "$work/child2.md"

# TWO ordered children, deliberately. With one, its relative order among itself
# is trivially correct and no wrong-order fixture can exist — the assertion
# would be unable to fail, which is this milestone's signature defect.
art="$work/plan.tsv"
{ printf 'milestone\tMS\tv9.9 — audit probe\tAudit milestone\n'
  printf 'issue\tP\tAudit parent\tfeature,P1,docs-impact:none\tMS\tparent.md\n'
  printf 'issue\tC\tAudit child\tfeature,P1,docs-impact:none\tMS\tchild.md\n'
  printf 'issue\tD\tAudit second child\tfeature,P1,docs-impact:none\tMS\tchild2.md\n'
  printf 'subissue\tP\tC\n'
  printf 'subissue\tP\tD\n'
  printf 'blockedby\tC\tP\tChild genuinely consumes parent output\n'
  printf 'order\tC\t1\n'
  printf 'order\tD\t2\n'
} > "$art"

st="$work/plan.state"
{ printf 'created\tms:MS\t7\t\n'
  printf 'created\tP\t100\t9100\n'
  printf 'created\tC\t101\t9101\n'
  printf 'created\tD\t102\t9102\n'
} > "$st"

# ---------------------------------------------------------------- the stub
# One stub, driven by SC. Title and labels are always right; SC breaks one other
# fact. `unread:<what>` makes a single endpoint fail so NOT ASSESSED can be
# distinguished from drift.
stub="$work/stub"; mkdir -p "$stub"
cat > "$stub/gh" <<'STUB'
#!/usr/bin/env bash
sc="${SC:-ok}"
args="$*"
case "$1 $2" in
  "auth status") exit 0 ;;
esac
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  n="$3"
  case "$args" in
    *"--json body"*)
      [ "$sc" = "unread:body" ] && exit 1
      if [ "$sc" = "bad-body" ]; then printf 'a body nobody asked for\n'; exit 0; fi
      case "$n" in
        100) cat "$BODY_P" ;;
        101) cat "$BODY_C" ;;
        102) cat "$BODY_D" ;;
      esac
      exit 0 ;;
    *"--json title,labels,milestone"*)
      [ "$sc" = "unread:issue" ] && exit 1
      ms="v9.9 — audit probe"
      [ "$sc" = "bad-milestone" ] && ms="some other milestone"
      [ "$sc" = "no-milestone" ] && ms=""
      case "$n" in
        100) printf '%s\t%s\t%s\n' "Audit parent" "P1,docs-impact:none,feature" "$ms" ;;
        101) printf '%s\t%s\t%s\n' "Audit child"  "P1,docs-impact:none,feature" "$ms" ;;
        102) printf '%s\t%s\t%s\n' "Audit second child" "P1,docs-impact:none,feature" "$ms" ;;
      esac
      exit 0 ;;
  esac
  exit 1
fi
if [ "$1" = "api" ]; then
  case "$args" in
    *"/milestones?"*)
      [ "$sc" = "unread:milestones" ] && exit 1
      [ "$sc" = "no-ms-record" ] && { printf 'something else\tdesc\n'; exit 0; }
      [ "$sc" = "bad-ms-desc" ] && { printf 'v9.9 — audit probe\twrong description\n'; exit 0; }
      printf 'v9.9 — audit probe\tAudit milestone\n'; exit 0 ;;
    *"/issues/100/sub_issues"*)
      [ "$sc" = "unread:subissues" ] && exit 1
      [ "$sc" = "no-hierarchy" ] && exit 0
      # 999 is a sub-issue the artifact never mentions: order is RELATIVE, so
      # its presence must not be read as drift. The two ordered children are
      # what the order check compares, and bad-order swaps exactly them.
      if [ "$sc" = "bad-order" ]; then printf '%s\n%s\n%s\n' 102 999 101
      else printf '%s\n%s\n%s\n' 101 999 102; fi
      exit 0 ;;
    *"/issues/101/dependencies/blocked_by"*)
      [ "$sc" = "unread:blockedby" ] && exit 1
      [ "$sc" = "no-dependency" ] && exit 0
      printf '%s\n' 100; exit 0 ;;
  esac
  exit 1
fi
exit 1
STUB
chmod +x "$stub/gh"

V() { # <SC> -> V_RC / V_OUT (tsv)
  V_RC=0
  V_OUT="$(cd "$work" && env PATH="$stub:$PATH" SC="$1" BODY_P="$work/parent.md" \
    BODY_C="$work/child.md" BODY_D="$work/child2.md" \
    "$SPARK" plan verify "$art" --state "$st" --tsv 2>&1)" || V_RC=$?
}
verdict() { printf '%s\n' "$V_OUT" | awk -F'\t' '$1 == "verdict" { print $2 }'; }
kinds()   { printf '%s\n' "$V_OUT" | awk -F'\t' 'NF > 2 { print $1 }' | LC_ALL=C sort -u | paste -sd, -; }

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}
# drift <SC> <desc> <substring-that-must-appear>
drift() {
  V "$1"
  assert_eq "$2: exits 1" 1 "$V_RC"
  assert_eq "$2: verdict FAIL" "FAIL" "$(verdict)"
  assert_contains "$2: names the drift" "$3" "$V_OUT"
}
# na <SC> <desc>
na() {
  V "$1"
  assert_eq "$2: exits 3" 3 "$V_RC"
  assert_eq "$2: verdict NOT ASSESSED" "NOT ASSESSED" "$(verdict)"
}

# ============ everything correct: PASS, and every surface was looked at =====
V ok
assert_eq "a fully correct repository verifies" 0 "$V_RC"
assert_eq "with a PASS verdict" "PASS" "$(verdict)"
# The defect was invisible precisely because whole KINDS of row were absent.
for k in created milestone hierarchy dependency order; do
  case ",$(kinds)," in
    *",$k,"*) ok ;;
    *) bad "no '$k' row was produced at all — that surface is still unchecked (kinds: $(kinds))" ;;
  esac
done

# ============ each mutation-bearing fact, broken one at a time ==============
# Title and labels stay correct throughout, which is exactly what made the old
# PASS look reasonable.
drift bad-milestone  "a created issue in the wrong milestone" "milestone is"
drift no-milestone   "a created issue with no milestone"      "(none)"
drift bad-body       "a created issue whose body is not the file" "body does not match"
drift no-ms-record   "a declared milestone that does not exist" "no milestone titled"
drift bad-ms-desc    "a milestone whose description drifted"   "description is"
drift no-hierarchy   "a sub-issue link that was never wired"   "NOT a sub-issue"
drift no-dependency  "a blocked-by edge that was never wired"  "NOT blocked by"
drift bad-order      "sub-issues in the wrong declared order"  "order"

# ============ unreadable is NOT ASSESSED, never PASS =======================
na unread:milestones "the milestone list unreadable"
na unread:subissues  "sub-issues unreadable"
na unread:blockedby  "blocked-by unreadable"
na unread:body       "an issue body unreadable"
na unread:issue      "an issue itself unreadable"
for sc in unread:milestones unread:subissues unread:blockedby unread:body unread:issue; do
  V "$sc"
  case "$(verdict)" in
    PASS) bad "$sc reported PASS for state it could not read" ;;
    *) ok ;;
  esac
done

# ============ the #517 scenario, verbatim ==================================
# "returns the expected titles and labels; would return a deliberately wrong
# milestone and body if asked; exposes no matching hierarchy/dependency/order
# data." One stub, everything but title and labels wrong at once.
cat > "$stub/gh" <<'STUB2'
#!/usr/bin/env bash
args="$*"
case "$1 $2" in "auth status") exit 0 ;; esac
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  case "$args" in
    *"--json body"*) printf 'deliberately wrong body\n'; exit 0 ;;
    *"--json title,labels,milestone"*)
      case "$3" in
        100) printf '%s\t%s\t%s\n' "Audit parent" "P1,docs-impact:none,feature" "wrong milestone" ;;
        101) printf '%s\t%s\t%s\n' "Audit child"  "P1,docs-impact:none,feature" "wrong milestone" ;;
        102) printf '%s\t%s\t%s\n' "Audit second child" "P1,docs-impact:none,feature" "wrong milestone" ;;
      esac
      exit 0 ;;
  esac
  exit 1
fi
# No hierarchy, dependency or order data is exposed at all.
if [ "$1" = "api" ]; then
  case "$args" in
    *"/milestones?"*) exit 0 ;;
    *sub_issues*)     exit 0 ;;
    *blocked_by*)     exit 0 ;;
  esac
fi
exit 1
STUB2
chmod +x "$stub/gh"
r=0
o="$(cd "$work" && env PATH="$stub:$PATH" "$SPARK" plan verify "$art" --state "$st" 2>&1)" || r=$?
case "$o" in
  *"PASS — GitHub matches the artifact"*)
    bad "#517: verify certified a repository with the wrong milestone, wrong body, and no hierarchy, dependency or order" ;;
  *) ok ;;
esac
if [ "$r" -ne 0 ]; then ok; else bad "#517: verify exited 0 for that repository"; fi

finish
