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
# The stub answers with the JSON GitHub returns and applies the CALLER's --jq
# (gh_stub_prelude), so the binary's own jq programs — the milestone list, the
# sub-issue list, the shared blocked-by reader, the identity read — are
# exercised rather than assumed; pre-shaped rows would agree with any jq. Each
# answer exits with jq's own status, as gh does: a rejected program is a failed
# call, never a silent success.
stub_gh "$stub/gh" <<\'STUB\'
sc="${SC:-ok}"
args="$*"
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view") [ "$sc" = "unread:identity" ] && exit 1; answer_json '{"nameWithOwner":"acme/widgets"}'; exit $? ;;
esac
# gh_issue_json <title> <label-csv> <milestone> — emit the JSON `gh issue view`
# returns, then apply the --jq the CALLER passed. A stub that returns
# pre-shaped rows leaves the binary's own shaping untested, which is exactly how
# a label-set collision survives: both sides join, so both sides agree.
gh_issue_json() {
  local t="$1" labs="$2" ms="$3" json
  json="$(jq -n --arg t "$t" --arg m "$ms" --arg l "$labs" \
    '{title: $t,
      milestone: (if $m == "" then null else {title: $m} end),
      labels: ($l | split(",") | map(select(. != "") | {name: .}))}')"
  if [ -n "$GH_JQ" ]; then printf '%s' "$json" | jq -r "$GH_JQ"; else printf '%s' "$json"; fi
}

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
    *"--json labels"*|*"--json title,labels,milestone"*)
      [ "$sc" = "unread:issue" ] && exit 1
      ms="v9.9 — audit probe"
      [ "$sc" = "bad-milestone" ] && ms="some other milestone"
      [ "$sc" = "no-milestone" ] && ms=""
      case "$n" in
        100) gh_issue_json "Audit parent"       "P1,docs-impact:none,feature" "$ms" ;;
        101) gh_issue_json "Audit child"        "P1,docs-impact:none,feature" "$ms" ;;
        102) gh_issue_json "Audit second child" "P1,docs-impact:none,feature" "$ms" ;;
      esac
      exit 0 ;;
  esac
  exit 1
fi
if [ "$1" = "api" ]; then
  case "$args" in
    *"/milestones?"*)
      [ "$sc" = "unread:milestones" ] && exit 1
      [ "$sc" = "no-ms-record" ] && { answer_json '[{"title":"something else","description":"desc"}]'; exit $?; }
      [ "$sc" = "bad-ms-desc" ] && { answer_json '[{"title":"v9.9 — audit probe","description":"wrong description"}]'; exit $?; }
      answer_json '[{"title":"v9.9 — audit probe","description":"Audit milestone"}]'; exit $? ;;
    *"/issues/100/sub_issues"*)
      [ "$sc" = "unread:subissues" ] && exit 1
      [ "$sc" = "no-hierarchy" ] && { answer_json '[]'; exit $?; }
      # 999 is a sub-issue the artifact never mentions: order is RELATIVE, so
      # its presence must not be read as drift. The two ordered children are
      # what the order check compares, and bad-order swaps exactly them.
      if [ "$sc" = "bad-order" ]; then answer_json '[{"number":102},{"number":999},{"number":101}]'
      else answer_json '[{"number":101},{"number":999},{"number":102}]'; fi
      exit $? ;;
    *"/issues/101/dependencies/blocked_by"*)
      [ "$sc" = "unread:blockedby" ] && exit 1
      [ "$sc" = "no-dependency" ] && { answer_json '[]'; exit $?; }
      # The JSON GitHub returns for a blocker: number, state, owning repository.
      # A foreign repository's #100 must never satisfy an edge declared between
      # two local issues, and a blocker whose repository is unknown is `?`.
      [ "$sc" = "foreign-number" ] && { answer_json '[{"number":100,"state":"open","repository":{"full_name":"other/elsewhere"}}]'; exit $?; }
      [ "$sc" = "unknown-repo" ] && { answer_json '[{"number":100,"state":"open"}]'; exit $?; }
      answer_json '[{"number":100,"state":"open","repository":{"full_name":"acme/widgets"}}]'; exit $? ;;
  esac
  exit 1
fi
exit 1
STUB

V() { # <SC> -> V_RC / V_OUT (tsv)
  V_RC=0
  V_OUT="$(cd "$work" && env PATH="$stub:$PATH" SC="$1" BODY_P="$work/parent.md" \
    BODY_C="$work/child.md" BODY_D="$work/child2.md" \
    "$SPARK" plan verify "$art" --state "$st" --tsv 2>&1)" || V_RC=$?
}
verdict() { printf '%s\n' "$V_OUT" | awk -F'\t' '$1 == "verdict" { print $2 }'; }
kinds()   { printf '%s\n' "$V_OUT" | awk -F'\t' 'NF > 2 { print $1 }' | LC_ALL=C sort -u | paste -sd, -; }

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
drift foreign-number "a foreign repository's issue with the same number as the declared blocker" "NOT blocked by"
drift bad-order      "sub-issues in the wrong declared order"  "order"

# ============ unreadable is NOT ASSESSED, never PASS =======================
na unread:milestones "the milestone list unreadable"
na unread:subissues  "sub-issues unreadable"
na unread:blockedby  "blocked-by unreadable"
na unread:identity   "the repository identity unreadable (no blocker can be matched)"
na unknown-repo      "a same-numbered blocker whose repository is unknown"
na unread:body       "an issue body unreadable"
na unread:issue      "an issue itself unreadable"
for sc in unread:milestones unread:subissues unread:blockedby unread:body unread:issue unread:identity unknown-repo; do
  V "$sc"
  case "$(verdict)" in
    PASS) bad "$sc reported PASS for state it could not read" ;;
    *) ok ;;
  esac
done

# ============ an EMPTY milestone field, with adjacent tabs ================
# Tab is an IFS *whitespace* character, so `IFS=$'\t' read` collapses runs of it.
# An issue record that legitimately omits its milestone —
# `A<TAB>One<TAB>labels<TAB><TAB>body.md` — lost the empty field, `body.md` was
# read as the milestone, and verification reported `milestone is "(none)"; the
# artifact says "body.md"` while never comparing the body at all (#540).
#
# This is the shape the fields are read in, so it is checked here rather than
# left to the happy path: the artifact above always supplies a milestone.
printf 'Unmilestoned body\n' > "$work/nom.md"
art2="$work/plan-nom.tsv"
printf 'issue\tU\tUnmilestoned\tfeature,P1,docs-impact:none\t\tnom.md\n' > "$art2"
st2="$work/plan-nom.state"
printf 'created\tU\t300\t9300\n' > "$st2"

cat > "$stub/gh" <<'STUB3'
#!/usr/bin/env bash
args="$*"
case "$1 $2" in "auth status") exit 0 ;; esac
GH_JQ=""; __prev=""
for __a in "$@"; do [ "$__prev" = "--jq" ] && GH_JQ="$__a"; __prev="$__a"; done
# gh_issue_json <title> <label-csv> <milestone> — emit the JSON `gh issue view`
# returns, then apply the --jq the CALLER passed. A stub that returns
# pre-shaped rows leaves the binary's own shaping untested, which is exactly how
# a label-set collision survives: both sides join, so both sides agree.
gh_issue_json() {
  local t="$1" labs="$2" ms="$3" json
  json="$(jq -n --arg t "$t" --arg m "$ms" --arg l "$labs" \
    '{title: $t,
      milestone: (if $m == "" then null else {title: $m} end),
      labels: ($l | split(",") | map(select(. != "") | {name: .}))}')"
  if [ -n "$GH_JQ" ]; then printf '%s' "$json" | jq -r "$GH_JQ"; else printf '%s' "$json"; fi
}

if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  case "$args" in
    *"--json body"*)                  cat "$BODY_U"; exit 0 ;;
    *"--json labels"*|*"--json title,labels,milestone"*)
      # No milestone, exactly as the artifact asks.
      gh_issue_json "Unmilestoned" "P1,docs-impact:none,feature" ""
      exit 0 ;;
  esac
  exit 1
fi
[ "$1" = "api" ] && exit 0
exit 1
STUB3

n_rc=0
n_out="$(cd "$work" && env PATH="$stub:$PATH" BODY_U="$work/nom.md" \
  "$SPARK" plan verify "$art2" --state "$st2" --tsv 2>&1)" || n_rc=$?
assert_eq "an empty milestone with a matching live issue verifies" 0 "$n_rc"
assert_eq "with a PASS verdict" "PASS" \
  "$(printf '%s\n' "$n_out" | awk -F'\t' '$1=="verdict"{print $2}')"
# The specific corruption: the body path must never be read as the milestone.
case "$n_out" in
  *'the artifact says "nom.md"'*)
    bad "#540: the body path was reported as the expected milestone" ;;
  *) ok ;;
esac
# And the body must actually be compared, not silently skipped.
assert_contains "the body is compared" "body matches nom.md" "$n_out"

# The body still fails when it genuinely differs, so the PASS above is not
# vacuous.
printf 'something else\n' > "$work/other.md"
n_rc=0
n_out="$(cd "$work" && env PATH="$stub:$PATH" BODY_U="$work/other.md" \
  "$SPARK" plan verify "$art2" --state "$st2" --tsv 2>&1)" || n_rc=$?
assert_eq "and a genuinely different body still fails" 1 "$n_rc"
assert_contains "naming the body" "body does not match" "$n_out"

# An empty milestone field asserts NOTHING, and the documentation says so: a
# create leaves the milestone unset rather than setting it to none, so `verify`
# makes no claim about it either. `apply` and `verify` must read one field the
# same way, or the verb reports drift against a state `apply` never intended.
cat > "$stub/gh" <<'STUB4'
#!/usr/bin/env bash
args="$*"
case "$1 $2" in "auth status") exit 0 ;; esac
GH_JQ=""; __prev=""
for __a in "$@"; do [ "$__prev" = "--jq" ] && GH_JQ="$__a"; __prev="$__a"; done
# gh_issue_json <title> <label-csv> <milestone> — emit the JSON `gh issue view`
# returns, then apply the --jq the CALLER passed. A stub that returns
# pre-shaped rows leaves the binary's own shaping untested, which is exactly how
# a label-set collision survives: both sides join, so both sides agree.
gh_issue_json() {
  local t="$1" labs="$2" ms="$3" json
  json="$(jq -n --arg t "$t" --arg m "$ms" --arg l "$labs" \
    '{title: $t,
      milestone: (if $m == "" then null else {title: $m} end),
      labels: ($l | split(",") | map(select(. != "") | {name: .}))}')"
  if [ -n "$GH_JQ" ]; then printf '%s' "$json" | jq -r "$GH_JQ"; else printf '%s' "$json"; fi
}

if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  case "$args" in
    *"--json body"*)                  cat "$BODY_U"; exit 0 ;;
    *"--json labels"*|*"--json title,labels,milestone"*)
      # GitHub carries a milestone the artifact never asked for.
      gh_issue_json "Unmilestoned" "P1,docs-impact:none,feature" "v9.9 — added later"
      exit 0 ;;
  esac
  exit 1
fi
[ "$1" = "api" ] && exit 0
exit 1
STUB4
n_rc=0
n_out="$(cd "$work" && env PATH="$stub:$PATH" BODY_U="$work/nom.md" \
  "$SPARK" plan verify "$art2" --state "$st2" --tsv 2>&1)" || n_rc=$?
assert_eq "a milestone added on GitHub is not drift against an empty field" 0 "$n_rc"
case "$n_out" in
  *"milestone is"*) bad "an empty milestone field was treated as an assertion" ;;
  *) ok ;;
esac

# ============ the #517 scenario, verbatim ==================================
# "returns the expected titles and labels; would return a deliberately wrong
# milestone and body if asked; exposes no matching hierarchy/dependency/order
# data." One stub, everything but title and labels wrong at once.
cat > "$stub/gh" <<'STUB2'
#!/usr/bin/env bash
args="$*"
case "$1 $2" in "auth status") exit 0 ;; esac
GH_JQ=""; __prev=""
for __a in "$@"; do [ "$__prev" = "--jq" ] && GH_JQ="$__a"; __prev="$__a"; done
# gh_issue_json <title> <label-csv> <milestone> — emit the JSON `gh issue view`
# returns, then apply the --jq the CALLER passed. A stub that returns
# pre-shaped rows leaves the binary's own shaping untested, which is exactly how
# a label-set collision survives: both sides join, so both sides agree.
gh_issue_json() {
  local t="$1" labs="$2" ms="$3" json
  json="$(jq -n --arg t "$t" --arg m "$ms" --arg l "$labs" \
    '{title: $t,
      milestone: (if $m == "" then null else {title: $m} end),
      labels: ($l | split(",") | map(select(. != "") | {name: .}))}')"
  if [ -n "$GH_JQ" ]; then printf '%s' "$json" | jq -r "$GH_JQ"; else printf '%s' "$json"; fi
}

if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  case "$args" in
    *"--json body"*) printf 'deliberately wrong body\n'; exit 0 ;;
    *"--json labels"*|*"--json title,labels,milestone"*)
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
r=0
o="$(cd "$work" && env PATH="$stub:$PATH" "$SPARK" plan verify "$art" --state "$st" 2>&1)" || r=$?
case "$o" in
  *"PASS — GitHub matches the artifact"*)
    bad "#517: verify certified a repository with the wrong milestone, wrong body, and no hierarchy, dependency or order" ;;
  *) ok ;;
esac
if [ "$r" -ne 0 ]; then ok; else bad "#517: verify exited 0 for that repository"; fi

# ============ label SETS, compared as sets (#599) =========================
# `[.labels[].name] | sort | join(",")` on the live side against a joined
# artifact list collapsed two distinct GitHub states into one string: the two
# labels `a` and `b`, and the single label named `a,b`, both became `a,b`. The
# comparison was symmetric, so it agreed with itself and `verify` reported that
# labels matched the artifact when GitHub did not match it.
#
# Both verification paths are exercised through the production `--jq`, and the
# stub is handed JSON rather than pre-shaped rows — a pre-shaped stub is how a
# flattening defect survives, because the shaping under test never runs.

lsrepo="$WORK/ls"; mkdir -p "$lsrepo"
lsbin="$WORK/lsbin"; mkdir -p "$lsbin"
for t in git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 paste; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$lsbin/$t" 2>/dev/null || true
done
cat > "$lsbin/gh" <<'LSEOF'
#!/usr/bin/env bash
case "$1 $2" in "auth status") exit 0 ;; esac
GH_JQ=""; prev=""
for a in "$@"; do [ "$prev" = "--jq" ] && GH_JQ="$a"; prev="$a"; done
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  # LIVE_LABELS is a JSON array of names — the real shape, applied through the
  # --jq the binary passes.
  json="$(jq -n --argjson l "$LIVE_LABELS" \
    '{title: "T", milestone: null, labels: ($l | map({name: .}))}')"
  if [ -n "$GH_JQ" ]; then printf '%s' "$json" | jq -r "$GH_JQ"; else printf '%s' "$json"; fi
  exit 0
fi
exit 0
LSEOF
chmod +x "$lsbin/gh"

# --- existing-issue verification (plan_live_rows)
lsart="$WORK/ls.tsv"
printf 'update\t#100\tlabels\ta,b\n' > "$lsart"
lslive() { ( cd "$lsrepo" && env PATH="$lsbin" LIVE_LABELS="$1" \
  bash -c '. '"$SPARK"'; plan_live_rows "'"$lsart"'"' 2>&1 ); }

case "$(lslive '["a","b"]')" in
  *$'live\t=\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ live [a,b] as two labels must match desired a,b" ;;
esac
case "$(lslive '["b","a"]')" in
  *$'live\t=\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ label set equality must be order-insensitive" ;;
esac
# THE COLLISION: one label literally named `a,b` is NOT the two labels a and b.
case "$(lslive '["a,b"]')" in
  *$'live\t~\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ a single label named 'a,b' must NOT match desired a,b" ;;
esac
# An extra live label belonging to no family this plan declares is PRESERVED,
# not drift (#637). Whole-set comparison called it drift, which is the same
# mistake as deleting it: `a,b` govern nothing, so `c` is not this plan's to
# have an opinion about.
case "$(lslive '["a","b","c"]')" in
  *$'live\t=\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ a live label outside the plan's families must be preserved, not drift" ;;
esac
# A stale member of a family the plan DOES declare is still drift — the family
# is Spark's, and applying would replace it.
lsart3="$WORK/ls3.tsv"
printf 'update\t#100\tlabels\tfeature\n' > "$lsart3"
lslive3() { ( cd "$lsrepo" && env PATH="$lsbin" LIVE_LABELS="$1" \
  bash -c '. '"$SPARK"'; plan_live_rows "'"$lsart3"'"' 2>&1 ); }
case "$(lslive3 '["feature","bug"]')" in
  *$'live\t~\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ a stale member of a governed family the plan declares must be drift" ;;
esac
case "$(lslive3 '["feature","feedback"]')" in
  *$'live\t=\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ an unmanaged label beside a satisfied family must verify clean" ;;
esac
case "$(lslive '["a"]')" in
  *$'live\t~\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ a missing live label must be drift" ;;
esac

# --- created-issue verification (plan_created_rows), independently
lsart2="$WORK/ls2.tsv"; : > "$WORK/ls2body.md"; echo body > "$WORK/ls2body.md"
printf 'issue\tK\tT\ta,b\t\t%s\n' "$WORK/ls2body.md" > "$lsart2"
lsstate="$WORK/ls2.state"
printf 'created\tK\t200\n' > "$lsstate"
lscreated() { ( cd "$lsrepo" && env PATH="$lsbin" LIVE_LABELS="$1" \
  bash -c '. '"$SPARK"'; plan_created_rows "'"$lsart2"'" "'"$lsstate"'"' 2>&1 ); }

case "$(lscreated '["a","b"]')" in
  *"labels match the artifact"*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ created: two live labels must match desired a,b" ;;
esac
case "$(lscreated '["b","a"]')" in
  *"labels match the artifact"*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ created: equality must be order-insensitive" ;;
esac
case "$(lscreated '["a,b"]')" in
  *"labels match the artifact"*) fail=$((fail+1)); echo "  ✖ created: label 'a,b' must NOT match desired a,b" ;;
  *) pass=$((pass+1)) ;;
esac
case "$(lscreated '["a","b","c"]')" in
  *"labels match the artifact"*) fail=$((fail+1)); echo "  ✖ created: an extra label must be drift" ;;
  *) pass=$((pass+1)) ;;
esac

# --- a label name must survive the transport BYTE FOR BYTE ----------------
# @tsv is not transparent: it escapes backslash, tab, CR and LF. A label named
# `foo\bar` therefore arrived at the comparison as `foo\\bar` and compared
# unequal to the artifact's own `foo\bar` — while the live path, which reads the
# name raw, compared it equal. One legal value, two paths, two answers.
#
# Structural transport means the bytes survive, not merely that the records are
# separate.
bsart="$WORK/bs.tsv"; echo body > "$WORK/bsbody.md"
printf 'issue\tK\tT\tfoo\\bar\t\t%s\n' "$WORK/bsbody.md" > "$bsart"
bsstate="$WORK/bs.state"; printf 'created\tK\t300\n' > "$bsstate"
bscreated() { ( cd "$lsrepo" && env PATH="$lsbin" LIVE_LABELS="$1" \
  bash -c '. '"$SPARK"'; plan_created_rows "'"$bsart"'" "'"$bsstate"'"' 2>&1 ); }

case "$(bscreated '["foo\\bar"]')" in
  *"labels match the artifact"*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ created: a backslash-bearing label must survive the transport intact" ;;
esac
# ...and a DIFFERENT backslash-bearing name must still be drift, so the case
# above cannot be passing because both sides were mangled the same way.
case "$(bscreated '["foo\\baz"]')" in
  *"labels match the artifact"*) fail=$((fail+1)); echo "  ✖ created: a different backslash label must not match" ;;
  *) pass=$((pass+1)) ;;
esac
# The live path already read names raw; asserted here so the two paths are
# known to agree about the same legal value rather than assumed to.
bslive_art="$WORK/bslive.tsv"
printf 'update\t#300\tlabels\tfoo\\bar\n' > "$bslive_art"
bslive() { ( cd "$lsrepo" && env PATH="$lsbin" LIVE_LABELS="$1" \
  bash -c '. '"$SPARK"'; plan_live_rows "'"$bslive_art"'"' 2>&1 ); }
case "$(bslive '["foo\\bar"]')" in
  *$'live\t=\t#300'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ live: a backslash-bearing label must compare equal too" ;;
esac
case "$(bslive '["foo\\baz"]')" in
  *$'live\t~\t#300'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ live: a different backslash label must be drift" ;;
esac

# --- unread live labels are NOT ASSESSED, never equality
failbin="$WORK/lsfail"; mkdir -p "$failbin"
for t in git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 paste; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$failbin/$t" 2>/dev/null || true
done
printf '#!/usr/bin/env bash\ncase "$1 $2" in "auth status") exit 0 ;; esac\nexit 1\n' > "$failbin/gh"
chmod +x "$failbin/gh"
unread_out="$( cd "$lsrepo" && env PATH="$failbin" \
  bash -c '. '"$SPARK"'; plan_live_rows "'"$lsart"'"' 2>&1 )"
case "$unread_out" in
  *$'live\t?\t#100'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); echo "  ✖ unreadable live labels must be NOT ASSESSED, not equality" ;;
esac
case "$unread_out" in
  *$'live\t=\t#100'*) fail=$((fail+1)); echo "  ✖ unreadable labels must never report a match" ;;
  *) pass=$((pass+1)) ;;
esac

finish
