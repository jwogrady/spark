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
# the governed role, or inferred from shape and luck? — and about the two
# things that identity is worth nothing without: that the gate actually carries
# the milestone, and that it is still visible once it closes.
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
# where a label name, a parent link or an issue's state is either preserved or
# lost — untested, and a replica passes while the original is wrong.

# The capture builders (gate_iss / gate_mil / gate_cap) live in lib.sh: the
# same response now feeds `governance` and `next` in this file and in two other
# suites, and a second copy of the shape is how they would drift apart again.

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
  c="$(PATH="$d:$PATH" gov_gate_capture "$marker")"
  gov_gate_rows "$marker" "$c"
}
bangs() { printf '%s\n' "$1" | awk -F'\t' '$2 == "!" { print }'; }
kind()  { printf '%s\n' "$1" | awk -F'\t' '$1 == "gate" { print $2; exit }'; }

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
ORDINARY="$(gate_cap "$(gate_mil 'v1.0 — ordinary' \
  "$(gate_iss 700 'v1.0 — ordinary' - OPEN feature P1),$(gate_iss 701 'v1.0 — ordinary' 700 CLOSED feature P1)")")"
out="$(rows "$ORDINARY")"
assert_contains "an ordinary parent leaves the milestone with no gate" \
  "this milestone has no release gate" "$out"
assert_lacks "and #700 is never named as one" "#700 is the release gate" "$out"
# Not a failure either: an ordinary parent is a legitimate shape, not a defect.
assert_eq "and nothing is reported as mechanically wrong" "" "$(bangs "$out")"

# ============ 2-3. the marked gate wins, whatever the enumeration order ====
#
# The gate carries the milestone THROUGH a container of its own: #900 is the
# gate, #800 an ordinary parent beneath it, #801 the leaf beneath that. Nesting
# is legitimate, so ancestry — not direct parenthood — is what scope means.
# The two fixtures differ ONLY in the order the issues arrive, and the marked
# gate also arrives a second time in the marker half, as GitHub answers it.
G="$(gate_iss 900 'v1.0 — two' - OPEN chore P1 release-gate)"
P="$(gate_iss 800 'v1.0 — two' 900 OPEN feature P1)"
L="$(gate_iss 801 'v1.0 — two' 800 OPEN feature P1)"

fwd="$(rows "$(gate_cap "$(gate_mil 'v1.0 — two' "$P,$L,$G")" "$G")")"
assert_contains "the marked gate is the gate, listed last" \
  "#900 is the release gate" "$fwd"
assert_lacks "and the ordinary parent is not" "#800 is the release gate" "$fwd"
assert_eq "a leaf under a nested container is inside the gate scope" "" "$(bangs "$fwd")"

rev="$(rows "$(gate_cap "$(gate_mil 'v1.0 — two' "$G,$L,$P")" "$G")")"
assert_contains "and still the gate, listed first" \
  "#900 is the release gate" "$rev"
assert_lacks "the ordinary parent is still not" "#800 is the release gate" "$rev"

# The PROPERTY, not two spellings of it: enumeration order cannot change the
# answer. Comparing the whole row sets is what makes that a claim about the
# rule rather than about these two lines.
assert_eq "enumeration order changes nothing at all" \
  "$(printf '%s\n' "$fwd" | LC_ALL=C sort)" "$(printf '%s\n' "$rev" | LC_ALL=C sort)"

# The gate arrived twice — once in its milestone, once as a marked issue — and
# is ONE issue. Counted twice it would report itself as two rival gates.
assert_eq "an issue that arrives twice is still one issue" "1" \
  "$(printf '%s\n' "$fwd" | awk -F'\t' '$1 == "gate"' | awk 'NF' | wc -l | tr -d ' ')"

# ============ 4. the gate carries the milestone, not merely a child =======
#
# Identity is not enough. #900 is the gate and does hold #901, so every "does
# the gate have children" test passes — while #902 sits in the same milestone
# outside its hierarchy. That is milestone work the delivery order cannot see,
# and closing the gate would declare a release over it.
GO="$(gate_iss 900 'v1.0 — orphan' - OPEN chore P1 release-gate)"
KID="$(gate_iss 901 'v1.0 — orphan' 900 OPEN feature P1)"
ORP="$(gate_iss 902 'v1.0 — orphan' - OPEN feature P1)"

ofwd="$(rows "$(gate_cap "$(gate_mil 'v1.0 — orphan' "$GO,$KID,$ORP")" "$GO")")"
assert_eq "an open issue outside the gate hierarchy fails" "!" "$(kind "$ofwd")"
assert_contains "naming the work the gate does not govern" "#902" "$ofwd"
assert_contains "and saying what the gate is for" "outside its hierarchy" "$ofwd"
assert_lacks "the governed child is not called an orphan" "(#901" "$ofwd"

orev="$(rows "$(gate_cap "$(gate_mil 'v1.0 — orphan' "$ORP,$KID,$GO")" "$GO")")"
assert_eq "and the enumeration order changes neither result" \
  "$(printf '%s\n' "$ofwd" | LC_ALL=C sort)" "$(printf '%s\n' "$orev" | LC_ALL=C sort)"

# Closed issues are not the milestone's remaining scope: a milestone delivered
# around its gate in the past is history, not a live contradiction.
DONE="$(rows "$(gate_cap "$(gate_mil 'v1.0 — settled' \
  "$GO,$KID,$(gate_iss 902 'v1.0 — settled' - CLOSED feature P1)")" "$GO")")"
assert_eq "a closed issue outside the hierarchy is not open work" "" "$(bangs "$DONE")"

# ============ 5. two marked gates are a mechanical failure =================
g900="$(gate_iss 900 'v1.0 — two gates' - OPEN chore P1 release-gate)"
g910="$(gate_iss 910 'v1.0 — two gates' - OPEN chore P1 release-gate)"
out="$(rows "$(gate_cap "$(gate_mil 'v1.0 — two gates' "$g900,$g910")" "$g900,$g910")")"
assert_contains "two marked gates fail" "a milestone has at most one release gate" "$out"
assert_contains "naming both" "#900, #910" "$out"
assert_eq "as a mechanical row, not a decision to hand a human" "!" "$(kind "$out")"
# The partition is the authority on that, so ask it rather than restating it.
assert_eq "and the verdict layer agrees it is mechanical" "1" \
  "$(gov_mechanical_rows "$out" | awk 'NF' | wc -l | tr -d ' ')"
assert_eq "and owes no human decision" "0" \
  "$(gov_judgment_rows "$out" | awk 'NF' | wc -l | tr -d ' ')"

# ============ 6. absence is KNOWN, never "not assessed" ====================
#
# The distinction this whole surface turns on: a milestone with no release gate
# is a complete answer. Reporting it as unknown would make every ordinary
# milestone look unassessed and teach a reader to ignore the mark that matters.
NONE="$(gate_cap "$(gate_mil 'v1.0 — flat' \
  "$(gate_iss 700 'v1.0 — flat' - OPEN feature P1),$(gate_iss 701 'v1.0 — flat' - OPEN feature P2)")")"
out="$(rows "$NONE")"
assert_eq "zero markers is a KNOWN state" "=" "$(kind "$out")"
assert_contains "and says so plainly" "this milestone has no release gate" "$out"
assert_eq "and is never reported as unread" "0" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "?"' | awk 'NF' | wc -l | tr -d ' ')"

# An OPEN MILESTONE WITH NO ISSUES AT ALL is judged too. Discovering milestones
# from the issues that mention them made this one silent — no row, no gate
# question asked, nothing for a reader to notice.
EMPTYMS="$(rows "$(gate_cap "$(gate_mil 'v1.0 — planned' '')")")"
assert_eq "an empty open milestone still produces exactly one row" "1" \
  "$(printf '%s\n' "$EMPTYMS" | awk 'NF' | wc -l | tr -d ' ')"
assert_eq "and it is a known answer, not silence" "=" "$(kind "$EMPTYMS")"
assert_contains "stating the absence" "this milestone has no release gate" "$EMPTYMS"

# ============ 7. a closed gate does not vanish ============================
#
# The role is structural issue metadata, not open-issue metadata. Reading only
# open issues let a gate disappear the moment it closed — and an open milestone
# with a closed gate and open work left then read as a perfectly valid no-gate
# milestone, which is the most dangerous shape on this surface.
CG="$(gate_iss 900 'v1.0 — closing' - CLOSED chore P1 release-gate)"
CLOSING="$(rows "$(gate_cap "$(gate_mil 'v1.0 — closing' \
  "$CG,$(gate_iss 901 'v1.0 — closing' 900 OPEN feature P1)")" "$CG")")"
assert_eq "a closed gate over open work is a contradiction" "!" "$(kind "$CLOSING")"
assert_contains "and names the rule it breaks" "the release gate closes last" "$CLOSING"
assert_contains "counting the work still open behind it" "1 open issue" "$CLOSING"
assert_lacks "never reported as a milestone with no gate" \
  "this milestone has no release gate" "$CLOSING"

# ...and when everything has closed, the gate is still observably the gate. The
# verdict may be benign; disappearing is not an option.
CG2="$(gate_iss 900 'v1.0 — done' - CLOSED chore P1 release-gate)"
SETTLED="$(rows "$(gate_cap "$(gate_mil 'v1.0 — done' \
  "$CG2,$(gate_iss 901 'v1.0 — done' 900 CLOSED feature P1)")" "$CG2")")"
assert_contains "a fully closed milestone still knows its gate" \
  "#900 is the release gate" "$SETTLED"
assert_eq "and reports it as a coherent state" "=" "$(kind "$SETTLED")"
assert_lacks "not as an absent one" "this milestone has no release gate" "$SETTLED"

# ============ 8. unread evidence is NOT ASSESSED ==========================
#
# A truncated page and an empty one are different answers, and reading the
# second from the first is exactly how an unread hierarchy becomes "no gate".
unread_of() {
  local d="$WORK/u$RANDOM"
  gh_stub "$d" "$1"
  PATH="$d:$PATH" gov_gate_capture "release-gate" | awk -F'\t' '$1 == "unread" { print $2 }'
}
LAB="$(LABELS_TRUNCATED=true gate_cap "$(LABELS_TRUNCATED=true gate_mil 'v1.0 — cut' \
  "$(LABELS_TRUNCATED=true gate_iss 900 'v1.0 — cut' - OPEN chore P1 release-gate)")")"
assert_contains "a truncated label page is reported as unread" \
  "the labels of #900 were truncated" "$(unread_of "$LAB")"

# The two surfaces the milestone-anchored capture adds, each of which could
# otherwise pass for "nothing there".
ISST="$(ISSUES_TRUNCATED=true gate_cap "$(ISSUES_TRUNCATED=true gate_mil 'v1.0 — cut' \
  "$(gate_iss 900 'v1.0 — cut' - OPEN chore P1)")")"
assert_contains "a truncated issue page is reported as unread" \
  "the issues of \"v1.0 — cut\" were truncated" "$(unread_of "$ISST")"
MST="$(MILESTONES_TRUNCATED=true gate_cap "$(MILESTONES_TRUNCATED=true gate_mil 'v1.0 — cut' '')")"
assert_contains "a truncated milestone page is reported as unread" \
  "the list of open milestones was truncated" "$(unread_of "$MST")"

# And gov_collect turns that into `?`, never into a gate verdict: proven
# through the real verb rather than by restating the branch here.
d="$WORK/unread"; gh_stub "$d" "$LAB"
r="$WORK/repo"; mkdir -p "$r/.spark"
git -C "$r" init -q
git -C "$r" commit -q --allow-empty -m "chore: seed"
grows="$(cd "$r" && PATH="$d:$PATH" gov_collect "$MODEL" "$r" 2>/dev/null | awk -F'\t' '$1 == "gate"')"
assert_eq "and gov_collect marks the surface unread" "?" \
  "$(printf '%s\n' "$grows" | awk -F'\t' '{ print $2; exit }')"
assert_lacks "never claiming a gate from a partial read" "is the release gate" "$grows"

# ============ 9. the marked gate must not contradict the hierarchy ========
#
# A gate is a container that closes last. An issue carrying the role while
# being somebody's child contradicts the fact the model states next door.
CHILD="$(gate_cap "$(gate_mil 'v1.0 — nested' "$(gate_iss 900 'v1.0 — nested' 479 OPEN chore P1 release-gate)")")"
out="$(rows "$CHILD")"
assert_contains "a marked gate that is itself a sub-issue fails" \
  "is itself a sub-issue of #479" "$out"

# A gate alone in its milestone is NOT a failure: a freshly planned release and
# a finished one both leave a gate with nothing open under it.
ALONE="$(gate_iss 900 'v1.0 — alone' - OPEN chore P1 release-gate)"
assert_eq "a gate alone in its milestone is not a failure" "" \
  "$(bangs "$(rows "$(gate_cap "$(gate_mil 'v1.0 — alone' "$ALONE")" "$ALONE")")")"

# A marker outside any milestone gates no release at all — and is reachable
# ONLY through the repository-wide marker half, because no milestone holds it.
LOOSE="$(gate_iss 900 - - OPEN chore P1 release-gate)"
assert_contains "a marker on an unmilestoned issue fails" \
  "is in no milestone" "$(rows "$(gate_cap "" "$LOOSE")")"

# ============ 10. next consumes the SAME gate fact ========================
#
# Not "next agrees with governance" — next reads the projection governance
# renders. So each fixture below drives BOTH verbs from ONE capture, and the
# assertion is that the repository cannot hold two gate answers at once.
nrepo="$WORK/nrepo"; mkdir -p "$nrepo/.spark"
git -C "$nrepo" init -q
git -C "$nrepo" commit -q --allow-empty -m "chore: seed"

# ISSUES is what `gh issue list --json number,title,labels` returns — the OPEN
# issues, which is exactly why next cannot find gate identity there: a gate that
# has closed is absent from it. GATECAP is the gate capture, applied through the
# --jq the binary itself passes.
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
  repo) printf 'o/r\n'; exit 0 ;;
  issue)
    jqx=""; prev=""
    for a in "$@"; do [ "$prev" = "--jq" ] && jqx="$a"; prev="$a"; done
    if [ -n "$jqx" ]; then printf '%s' "$ISSUES" | jq -r "$jqx"; else printf '%s' "$ISSUES"; fi
    exit 0 ;;
esac
for a in "$@"; do
  if [ "$a" = "graphql" ]; then
    jqx=""; prev=""
    for b in "$@"; do [ "$prev" = "--jq" ] && jqx="$b"; prev="$b"; done
    if [ -n "${GATECAP:-}" ]; then
      if [ -n "$jqx" ]; then printf '%s' "$GATECAP" | jq -r "$jqx"; else printf '%s' "$GATECAP"; fi
    fi
    exit 0
  fi
done
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
# nx <issue-list-json> <capture-json>
nx() { ( cd "$nrepo" && env PATH="$nxb" ISSUES="$1" GATECAP="$2" \
         "$SPARK" next --milestone "v1.0" 2>&1 ); }

# The open issue list, shared by every fixture below: an ordinary parent, the
# work, and the gate. What differs between fixtures is the gate's own state,
# which this list cannot express — that is the point.
J_GATE_LAST='[{"number":800,"title":"Ordinary parent","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":900,"title":"Gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]}]'
J_GATE_FIRST='[{"number":900,"title":"Gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]},
 {"number":800,"title":"Ordinary parent","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]}]'

# --- D. a valid marked gate: next follows its sub-issue order --------------
NG="$(gate_iss 900 'v1.0' - OPEN chore P1 release-gate)"
NP="$(gate_iss 800 'v1.0' 900 OPEN chore P1)"
NW="$(gate_iss 802 'v1.0' 800 OPEN feature P1)"
CAP_OK="$(gate_cap "$(gate_mil 'v1.0' "$NG,$NP,$NW")" "$NG")"
assert_eq "governance finds the gate valid" "=" "$(kind "$(rows "$CAP_OK")")"

o1="$(nx "$J_GATE_LAST" "$CAP_OK")"
assert_contains "next selects the leaf, not a container" "selected  #802" "$o1"
assert_contains "and follows the marked gate's own sub-issue order" \
  "in the gate sub-issue order" "$o1"
# The ordinary parent is a container too: it has no branch and no PR of its own,
# so it is never offered as work either.
assert_lacks "the ordinary parent is never selected" "selected  #800" "$o1"

o2="$(nx "$J_GATE_FIRST" "$CAP_OK")"
assert_contains "and the same issue whatever the order" "selected  #802" "$o2"
assert_eq "next's answer does not depend on enumeration order" "$o1" "$o2"

# --- A. a closed marked gate with open work still behind it ---------------
#
# THE SHAPE THAT PROVED THE TWO VERBS WERE STILL SEPARATE. The marker is on a
# CLOSED issue, so it is absent from every open-issue list — next used to
# conclude "this milestone declares no release gate" and rank by priority,
# while governance called the same repository mechanically invalid.
NGC="$(gate_iss 900 'v1.0' - CLOSED chore P1 release-gate)"
CAP_CLOSED="$(gate_cap "$(gate_mil 'v1.0' "$NGC,$NP,$NW")" "$NGC")"
grows_closed="$(rows "$CAP_CLOSED")"
assert_eq "governance rejects a gate that closed before its work" "!" "$(kind "$grows_closed")"

rc=0; oA="$(nx "$J_GATE_LAST" "$CAP_CLOSED")" || rc=$?
assert_rc "and next refuses the same state" 4 "$rc"
assert_contains "as mechanically invalid, not unassessed" \
  "mechanically invalid" "$oA"
assert_contains "naming the same rule governance named" \
  "the release gate closes last" "$oA"
assert_lacks "never as a milestone that declares no gate" "declares no release gate" "$oA"
assert_lacks "and never as NOT ASSESSED" "not assessed" "$oA"
assert_lacks "selecting nothing" "selected  #" "$oA"

# --- B. two marked gates: both verbs call it mechanically invalid ----------
NG2="$(gate_iss 901 'v1.0' - OPEN chore P1 release-gate)"
CAP_TWO="$(gate_cap "$(gate_mil 'v1.0' "$NG,$NG2,$NW")" "$NG,$NG2")"
assert_eq "governance rejects two gates" "!" "$(kind "$(rows "$CAP_TWO")")"

J_TWO='[{"number":900,"title":"Gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]},
 {"number":901,"title":"Other gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"release-gate"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]}]'
rc=0; oB="$(nx "$J_TWO" "$CAP_TWO")" || rc=$?
assert_rc "and next refuses it as mechanically invalid" 4 "$rc"
assert_contains "with governance's own words" \
  "a milestone has at most one release gate" "$oB"
assert_lacks "not as an unread surface" "not assessed" "$oB"
assert_lacks "and selecting nothing" "selected  #" "$oB"

# --- C. a valid no-gate milestone: selection proceeds by priority ---------
CAP_NONE="$(gate_cap "$(gate_mil 'v1.0' "$NP,$NW")")"
assert_eq "governance calls a no-gate milestone known" "=" "$(kind "$(rows "$CAP_NONE")")"
J_NOGATE='[{"number":800,"title":"Ordinary parent","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]}]'
rc=0; oC="$(nx "$J_NOGATE" "$CAP_NONE")" || rc=$?
assert_rc "a milestone with no gate still selects" 0 "$rc"
assert_contains "choosing the leaf" "selected  #802" "$oC"
assert_contains "and stating the known absence" "declares no release gate" "$oC"
assert_lacks "never calling it unassessed" "not assessed" "$oC"

# --- unread gate evidence stops selection ---------------------------------
# The other half of the same rule: absence is known, a truncated read is not.
CAP_CUT="$(LABELS_TRUNCATED=true gate_cap "$(LABELS_TRUNCATED=true gate_mil 'v1.0' \
  "$(LABELS_TRUNCATED=true gate_iss 900 'v1.0' - OPEN chore P1 release-gate)")")"
rc=0; oU="$(nx "$J_GATE_LAST" "$CAP_CUT")" || rc=$?
assert_rc "truncated gate evidence is NOT ASSESSED" 3 "$rc"
assert_lacks "and is never read as no gate" "declares no release gate" "$oU"

# --- the model is still the authority inside next -------------------------
# A model that renames the member is followed HERE too. next resolves the
# locator from the model rather than spelling the label, so a repository that
# calls the role something else still has its gate found — the assertion that a
# hard-coded label inside `next` would fail.
alt_repo="$WORK/altrepo"; mkdir -p "$alt_repo/.spark"
git -C "$alt_repo" init -q
git -C "$alt_repo" commit -q --allow-empty -m "chore: seed"
# Derived from the shipped model in its ON-DISK form, renaming the member and
# the locator that points at it — never the aspect, which is what binds them.
awk -F'\t' 'BEGIN { OFS = "\t" }
  $1 == "member" && $2 == "role" && $3 == "release-gate" { $3 = "ship-gate" }
  $1 == "structure" && $2 == "release-gate" { $3 = "role:ship-gate" }
  { print }' \
  "$(dirname "$SPARK")/../preferences/governance-models/spark-default.tsv" \
  > "$alt_repo/.spark/governance.tsv"

SG="$(gate_iss 900 'v1.0' - OPEN chore P1 ship-gate)"
CAP_ALT="$(gate_cap "$(gate_mil 'v1.0' "$SG,$NP,$NW")" "$SG")"
J_ALT='[{"number":800,"title":"Ordinary parent","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":802,"title":"The work","labels":[{"name":"feature"},{"name":"P1"},{"name":"docs-impact:none"}]},
 {"number":900,"title":"Gate","labels":[{"name":"chore"},{"name":"P1"},{"name":"docs-impact:none"},{"name":"ship-gate"}]}]'
rc=0
oR="$( cd "$alt_repo" && env PATH="$nxb" ISSUES="$J_ALT" GATECAP="$CAP_ALT" \
       "$SPARK" next --milestone "v1.0" 2>&1 )" || rc=$?
assert_rc "a renamed role still lets next select" 0 "$rc"
assert_contains "and next follows the renamed gate's sub-issue order" \
  "in the gate sub-issue order" "$oR"
assert_lacks "the renamed gate is not offered as work" "selected  #900" "$oR"

finish
