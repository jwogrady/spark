#!/usr/bin/env bash
# Behavioral suite for the release-gate role (#605): WHICH issue is the gate.
#
# The model declares two separate authoritative facts — a parent is a container
# that closes last, and the release gate's sub-issue order is the delivery-order
# authority — and used to declare nothing that said which container the gate
# was. The only signal left was parenthood, so "the first open issue carrying
# sub-issues" became the gate: an ordinary parent was reported as the release
# boundary, and reversing the order GitHub returned issues in changed which one
# won.
#
# So every assertion below is about ONE question — is gate identity read from
# the governed role, or inferred from shape and luck?
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}
assert_lacks() {
  local desc="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) bad "$desc — output still contains '$needle'" ;;
    *) ok ;;
  esac
}

tools="git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm"

# --- the capture, as GitHub actually answers it ----------------------------
#
# The fixtures below build the GraphQL RESPONSE and let the binary's own --jq
# shape it. Handing gov_gate_rows pre-shaped records would leave the shaping —
# where a label name or a parent link is either preserved or lost — untested,
# and a replica passes while the original is wrong.

# iss <number> <milestone> <parent|-> <sub-count> <label>... — one open issue.
iss() {
  local n="$1" ms="$2" par="$3" subs="$4"; shift 4
  local labs="" l
  for l in "$@"; do labs="${labs:+$labs,}$(printf '{"name":%s}' "$(printf '%s' "$l" | jq -R .)")"; done
  printf '{"number":%s,"milestone":%s,"parent":%s,"subIssues":{"totalCount":%s},"labels":{"pageInfo":{"hasNextPage":%s},"nodes":[%s]}}' \
    "$n" \
    "$([ "$ms" = "-" ] && echo null || printf '{"title":%s}' "$(printf '%s' "$ms" | jq -R .)")" \
    "$([ "$par" = "-" ] && echo null || printf '{"number":%s}' "$par")" \
    "$subs" "${LABELS_TRUNCATED:-false}" "$labs"
}

# cap <issue-nodes> — the whole response.
cap() {
  printf '{"data":{"repository":{"issues":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[%s]}}}}' "$1"
}

# gh_stub <dir> <response-json> — a PATH whose gh answers `repo view` and the
# hierarchy query, applying the --jq the BINARY passes.
gh_stub() {
  local d="$1" json="$2" t src
  mkdir -p "$d"
  for t in $tools; do
    src="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$src" ] && ln -sf "$src" "$d/$t" 2>/dev/null || true
  done
  printf '%s' "$json" > "$d/cap.json"
  cat > "$d/gh" <<'GHEOF'
#!/usr/bin/env bash
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
  if [ -n "$jqexpr" ]; then jq -r "$jqexpr" "$(dirname "$0")/cap.json"
  else cat "$(dirname "$0")/cap.json"; fi
  exit 0
fi
exit 0
GHEOF
  chmod +x "$d/gh"
}

# rows <response-json> — the gate rows, through the real capture and the real
# locator, exactly as gov_collect reaches them.
rows() {
  local d="$WORK/s$RANDOM" c marker
  gh_stub "$d" "$1"
  marker="$(release_gate_label "$MODEL")"
  c="$(PATH="$d:$PATH" gov_gate_capture)"
  gov_gate_rows "$marker" "$c"
}

MODEL="$(resolve_governance 2>/dev/null)"

# ============ 0. the locator is read from the model, not spelled ===========
assert_eq "the locator resolves to the declared member" "release-gate" \
  "$(release_gate_label "$MODEL")"

# A model that binds the aspect to a different member is FOLLOWED. This is the
# whole point of declaring the fact as data: a consumer that hard-coded the
# label would pass every other test in this file and fail this one.
alt="$(printf '%s\n' "$MODEL" \
  | sed 's/^structure\trelease-gate\trole:release-gate\t/structure\trelease-gate\trole:ship-gate\t/
         s/^member\trole\trelease-gate\t/member\trole\tship-gate\t/')"
assert_eq "a model that renames the member is followed" "ship-gate" \
  "$(release_gate_label "$alt")"

# A locator naming no declared member is a defect in the model, not a repo with
# no gate — the two must not collapse, or every milestone would report clean.
broken="$(printf '%s\n' "$MODEL" \
  | sed 's/^structure\trelease-gate\trole:release-gate\t/structure\trelease-gate\trole:nonesuch\t/')"
brc=0; release_gate_label "$broken" >/dev/null || brc=$?
assert_eq "a locator naming no declared member is a defect" "2" "$brc"

# An aspect the model does not govern at all is a THIRD state: there is simply
# no invariant to report, which is not the same as a broken locator.
ungoverned="$(printf '%s\n' "$MODEL" | grep -v '^structure	release-gate	')"
urc=0; release_gate_label "$ungoverned" >/dev/null || urc=$?
assert_eq "an ungoverned aspect is neither resolved nor a defect" "1" "$urc"

# ============ 1. an ordinary parent is NOT a gate ==========================
#
# THE FIXTURE THE OLD RULE COULD NOT FAIL: milestone open, one ordinary parent
# whose only child has closed (so no child appears in an open-issues read), and
# no marked gate anywhere. Under "first container is the gate" this milestone
# reported that only its release gate remained.
ORDINARY="$(cap "$(iss 700 'v1.0 — ordinary' - 1 feature P1)")"
out="$(rows "$ORDINARY")"
assert_contains "an ordinary parent leaves the milestone with no gate" \
  "this milestone has no release gate" "$out"
assert_lacks "and #700 is never named as one" "#700 is the release gate" "$out"
# Not a failure either: an ordinary parent is a legitimate shape, not a defect.
assert_eq "and nothing is reported as mechanically wrong" "" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "!" { print }')"

# ============ 2-3. the marked gate wins, whatever the enumeration order ====
#
# Two containers in one milestone: #800 is ordinary, #900 carries the role.
# The two fixtures differ ONLY in the order the issues arrive.
A="$(iss 800 'v1.0 — two' - 1 feature P1)"
B="$(iss 900 'v1.0 — two' - 2 chore P1 release-gate)"
C="$(iss 801 'v1.0 — two' 900 0 feature P1)"

fwd="$(rows "$(cap "$A,$C,$B")")"
assert_contains "the marked gate is the gate, listed last" \
  "#900 is the release gate" "$fwd"
assert_lacks "and the ordinary parent is not" "#800 is the release gate" "$fwd"

rev="$(rows "$(cap "$B,$A,$C")")"
assert_contains "and still the gate, listed first" \
  "#900 is the release gate" "$rev"
assert_lacks "the ordinary parent is still not" "#800 is the release gate" "$rev"

# The PROPERTY, not two spellings of it: enumeration order cannot change the
# answer. Comparing the whole row sets is what makes that a claim about the
# rule rather than about these two lines.
assert_eq "enumeration order changes nothing at all" \
  "$(printf '%s\n' "$fwd" | LC_ALL=C sort)" "$(printf '%s\n' "$rev" | LC_ALL=C sort)"

# ============ 4. two marked gates are a mechanical failure =================
TWO="$(cap "$(iss 900 'v1.0 — two gates' - 1 chore P1 release-gate),$(iss 910 'v1.0 — two gates' - 1 chore P1 release-gate)")"
out="$(rows "$TWO")"
assert_contains "two marked gates fail" "a milestone has at most one release gate" "$out"
assert_contains "naming both" "#900, #910" "$out"
assert_eq "as a mechanical row, not a decision to hand a human" "!" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "gate" { print $2; exit }')"
# The partition is the authority on that, so ask it rather than restating it.
assert_eq "and the verdict layer agrees it is mechanical" "1" \
  "$(gov_mechanical_rows "$out" | awk 'NF' | wc -l | tr -d ' ')"
assert_eq "and owes no human decision" "0" \
  "$(gov_judgment_rows "$out" | awk 'NF' | wc -l | tr -d ' ')"

# ============ 5. absence is KNOWN, never "not assessed" ====================
#
# The distinction this whole surface turns on: a milestone with no release gate
# is a complete answer. Reporting it as unknown would make every ordinary
# milestone look unassessed and teach a reader to ignore the mark that matters.
NONE="$(cap "$(iss 700 'v1.0 — flat' - 0 feature P1),$(iss 701 'v1.0 — flat' - 0 feature P2)")"
out="$(rows "$NONE")"
assert_eq "zero markers is a KNOWN state" "=" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1 == "gate" { print $2; exit }')"
assert_contains "and says so plainly" "this milestone has no release gate" "$out"
assert_eq "and is never reported as unread" "0" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "?"' | awk 'NF' | wc -l | tr -d ' ')"

# ============ 6. unread hierarchy is NOT ASSESSED ==========================
#
# A truncated page and an empty one are different answers, and reading the
# second from the first is exactly how an unread hierarchy becomes "no gate".
d="$WORK/unread"
LABELS_TRUNCATED=true gh_stub "$d" \
  "$(LABELS_TRUNCATED=true cap "$(LABELS_TRUNCATED=true iss 900 'v1.0 — cut' - 1 chore P1 release-gate)")"
capture="$(PATH="$d:$PATH" gov_gate_capture)"
assert_contains "a truncated label page is reported as unread" \
  "were truncated" "$(printf '%s\n' "$capture" | awk -F'\t' '$1 == "unread" { print $2 }')"
# And gov_collect turns that into `?`, never into a gate verdict: proven
# through the real verb rather than by restating the branch here.
r="$WORK/repo"; mkdir -p "$r/.spark"
git -C "$r" init -q
git -C "$r" commit -q --allow-empty -m "chore: seed"
grows="$(cd "$r" && PATH="$d:$PATH" gov_collect "$MODEL" "$r" 2>/dev/null | awk -F'\t' '$1 == "gate"')"
assert_eq "and gov_collect marks the surface unread" "?" \
  "$(printf '%s\n' "$grows" | awk -F'\t' '{ print $2; exit }')"
assert_lacks "never claiming a gate from a partial read" "is the release gate" "$grows"

# ============ 7. the marked gate must not contradict the hierarchy =========
#
# A gate is a container that closes last. An issue carrying the role while
# being somebody's child contradicts the fact the model states next door.
CHILD="$(cap "$(iss 900 'v1.0 — nested' 479 1 chore P1 release-gate)")"
out="$(rows "$CHILD")"
assert_contains "a marked gate that is itself a sub-issue fails" \
  "is itself a sub-issue of #479" "$out"

# A marked gate governing nothing while the milestone holds other open work.
EMPTY="$(cap "$(iss 900 'v1.0 — empty' - 0 chore P1 release-gate),$(iss 901 'v1.0 — empty' - 0 feature P1)")"
out="$(rows "$EMPTY")"
assert_contains "a gate that governs nothing fails" "no sub-issues" "$out"
assert_contains "and counts the work it does not govern" "1 other open issue" "$out"

# ...but NOT when there is nothing to govern yet, or nothing left. Both are
# ordinary points in a milestone's life, and failing them would report a freshly
# planned release and a finished one as broken.
ALONE="$(cap "$(iss 900 'v1.0 — alone' - 0 chore P1 release-gate)")"
assert_eq "a gate alone in its milestone is not a failure" "" \
  "$(rows "$ALONE" | awk -F'\t' '$2 == "!" { print }')"

# A marker outside any milestone gates no release at all.
LOOSE="$(cap "$(iss 900 - - 1 chore P1 release-gate)")"
assert_contains "a marker on an unmilestoned issue fails" \
  "is in no milestone" "$(rows "$LOOSE")"

# ============ 8. next reads the same fact ==================================
#
# The two verbs must not be able to disagree about which issue is the gate, and
# the way to prove that is to run the real selector over the same shape.
nrepo="$WORK/nrepo"; mkdir -p "$nrepo/.spark"
git -C "$nrepo" init -q
git -C "$nrepo" commit -q --allow-empty -m "chore: seed"

# ISSUES is what `gh issue list --json number,title,labels` returns; the stub
# applies the --jq the binary passes, so the read's own shaping runs.
nx_stub() {
  local d="$1" t src
  mkdir -p "$d"
  for t in $tools; do
    src="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$src" ] && ln -sf "$src" "$d/$t" 2>/dev/null || true
  done
  cat > "$d/gh" <<'GHEOF'
#!/usr/bin/env bash
case "${1:-}" in
  auth) exit 0 ;;
  issue)
    jqx=""; prev=""
    for a in "$@"; do [ "$prev" = "--jq" ] && jqx="$a"; prev="$a"; done
    if [ -n "$jqx" ]; then printf '%s' "$ISSUES" | jq -r "$jqx"; else printf '%s' "$ISSUES"; fi
    exit 0 ;;
esac
for a in "$@"; do
  case "$a" in
    */issues/900/sub_issues*) printf '801\n802\n'; exit 0 ;;
    */issues/800/sub_issues*) printf '810\n'; exit 0 ;;
    */issues/80[12]/sub_issues*) exit 0 ;;
    *dependencies*) printf '0\n'; exit 0 ;;
  esac
done
exit 0
GHEOF
  chmod +x "$d/gh"
}
nxb="$WORK/nxb"; nx_stub "$nxb"
nx() { ( cd "$nrepo" && env PATH="$nxb" ISSUES="$1" "$SPARK" next --milestone "v1.0" 2>&1 ); }

# #800 is an ordinary parent, #900 the marked gate, #802 the work.
J_GATE_LAST='[{"number":800,"title":"Ordinary parent","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":900,"title":"Gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]}]'
J_GATE_FIRST='[{"number":900,"title":"Gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]},
 {"number":800,"title":"Ordinary parent","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]}]'

o1="$(nx "$J_GATE_LAST")"
assert_contains "next selects the leaf, not a container" "selected  #802" "$o1"
assert_contains "and follows the marked gate's own sub-issue order" \
  "in the gate sub-issue order" "$o1"
# The ordinary parent is a container too: it has no branch and no PR of its own,
# so it is never offered as work either.
assert_lacks "the ordinary parent is never selected" "selected  #800" "$o1"

o2="$(nx "$J_GATE_FIRST")"
assert_contains "and the same issue whatever the order" "selected  #802" "$o2"
assert_eq "next's answer does not depend on enumeration order" "$o1" "$o2"

# Two marked gates: the order authority is ambiguous, so selection stops rather
# than picking one. Selection is never made on an authority that does not
# resolve.
J_TWO='[{"number":900,"title":"Gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]},
 {"number":901,"title":"Other gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]}]'
rc=0; o3="$(nx "$J_TWO")" || rc=$?
assert_rc "two marked gates stop selection" 3 "$rc"
assert_contains "naming the ambiguity" "both carry the release-gate role" "$o3"
assert_lacks "and selecting nothing" "selected  #" "$o3"

# No marked gate at all: a KNOWN state. Selection proceeds by priority and says
# why there is no order to follow — it does not refuse.
J_NOGATE='[{"number":800,"title":"Ordinary parent","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]}]'
rc=0; o4="$(nx "$J_NOGATE")" || rc=$?
assert_rc "a milestone with no gate still selects" 0 "$rc"
assert_contains "choosing the leaf" "selected  #802" "$o4"
assert_contains "and stating the known absence" "declares no release gate" "$o4"
assert_lacks "never calling it unassessed" "not assessed" "$o4"

finish
