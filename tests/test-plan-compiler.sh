#!/usr/bin/env bash
# Behavioral suite for the plan compiler (#472): the record types that let a
# manifest carry a milestone, an update, a preferred order and an unresolved
# decision; the structural rules that refuse a cycle or a disguised
# prerequisite; and the schema layer that refuses metadata the model does not
# declare.
#
# Structure is issue-manifest.sh's; meaning is the schema's. Both are driven
# from fixtures with no GitHub.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
IM="$WORK/plugin/skills/plan/scripts/issue-manifest.sh"
. "$IM"      # im_validate / im_pending / im_plan (main is source-guarded)
. "$SPARK"   # resolve_governance / plan_schema_rows

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

work="$WORK/plan"
mkdir -p "$work/bodies"
echo "body" > "$work/bodies/a.md"
T=$'\t'
A="$work/bodies/a.md"

# man <record>... -> writes the artifact, echoes its path
man() { local m="$work/m.tsv"; printf '%s\n' "$@" > "$m"; printf '%s' "$m"; }

refuse() { # <desc> <needle> <record>...
  local desc="$1" needle="$2"; shift 2
  local m rc=0 out
  m="$(man "$@")"
  out="$(im_validate "$m")" || rc=$?
  if [ "$rc" -ne 1 ]; then bad "$desc — want rc 1, got $rc ($out)"; return 0; fi
  assert_contains "$desc" "$needle" "$out"
}
allow() { # <desc> <record>...
  local desc="$1"; shift
  local m rc=0 out
  m="$(man "$@")"
  out="$(im_validate "$m")" || rc=$?
  if [ "$rc" -eq 0 ]; then ok; else bad "$desc — want rc 0, got $rc ($out)"; fi
}

# ======================== a manifest brings its own milestone ==============
allow "a milestone record is valid" \
  "milestone${T}MS${T}v9.9 — Probe${T}A scratch milestone" \
  "issue${T}A${T}One${T}feature${T}MS${T}$A"
refuse "a milestone needs 4 fields" "milestone record needs 4" \
  "milestone${T}MS${T}v9.9"
refuse "a milestone KEY cannot repeat" "duplicate milestone KEY" \
  "milestone${T}MS${T}One${T}x" \
  "milestone${T}MS${T}Two${T}y"
refuse "a milestone needs a title" "milestone title is empty" \
  "milestone${T}MS${T}${T}x"

# More than one milestone per manifest is now representable: the old rule
# existed only because milestones were lookup-only.
allow "two milestones in one manifest" \
  "milestone${T}M1${T}v1.0${T}a" \
  "milestone${T}M2${T}v2.0${T}b" \
  "issue${T}A${T}One${T}feature${T}M1${T}$A" \
  "issue${T}B${T}Two${T}feature${T}M2${T}$A"

# A milestone the manifest CREATES must not also be looked up — the lookup
# hard-fails for "not found on GitHub", which is exactly what the create fixes.
m="$(man "milestone${T}MS${T}v9.9 — Probe${T}x" "issue${T}A${T}One${T}feature${T}MS${T}$A")"
pending="$(im_pending "$m" "")"
assert_eq "a self-created milestone triggers no lookup" "" \
  "$(printf '%s\n' "$pending" | grep '^lookup-ms' || true)"
assert_contains "and is created instead" "create-ms" "$pending"
# A milestone it does NOT create still needs resolving.
m="$(man "issue${T}A${T}One${T}feature${T}v0.15${T}$A")"
assert_contains "an external milestone is still looked up" "lookup-ms" "$(im_pending "$m" "")"

# ======================== preferred order has its own home =================
allow "an order record is valid" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "order${T}A${T}1"
refuse "an order position must be a number" "order position 'first' is not a number" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "order${T}A${T}first"
refuse "two issues cannot share a position" "duplicate order position" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "order${T}A${T}1" \
  "order${T}B${T}1"
refuse "an issue cannot be ordered twice" "already has an order position" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "order${T}A${T}1" \
  "order${T}A${T}2"

# The refusal list is STEMS, and every entry must behave like one. `priorit` was
# a stem while `sequence` was a whole word, so "for sequencing" — as natural a
# phrasing as any here — wired a real prerequisite while "ordering" was caught.
# Found by the #472 re-audit.
for w in order ordering reorder sequence sequencing resequence \
         priority prioritise prioritisation preference preferential; do
  refuse "a reason naming '$w' is refused" "preferred order is not a prerequisite" \
    "issue${T}A${T}One${T}feature${T}${T}$A" \
    "issue${T}B${T}Two${T}feature${T}${T}$A" \
    "blockedby${T}A${T}B${T}Because of $w"
done
# The negative control: a genuine prerequisite reason must still be accepted, or
# the loop above would pass by refusing everything.
allow "a genuine prerequisite reason is accepted" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "blockedby${T}A${T}B${T}A consumes the schema B defines"

# THE rule this record type exists for: an edge that only expresses sequence is
# refused, because as a prerequisite it becomes a permanent false blocker.
for reason in order preferred-order sequence preference; do
  refuse "a blockedby declared as '$reason' is refused" "preferred order is not a prerequisite" \
    "issue${T}A${T}One${T}feature${T}${T}$A" \
    "issue${T}B${T}Two${T}feature${T}${T}$A" \
    "blockedby${T}B${T}A${T}$reason"
done
# A genuine reason is fine.
allow "a blockedby may state a real reason" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "blockedby${T}B${T}A${T}B consumes A's apply path"
# An order record and a real dependency between the same pair are different
# facts and may coexist.
allow "order and a real dependency can coexist" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "blockedby${T}B${T}A" \
  "order${T}A${T}1" \
  "order${T}B${T}2"

# ======================== cycles are structural ===========================
refuse "a two-issue cycle is refused" "dependency cycle" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "blockedby${T}A${T}B" \
  "blockedby${T}B${T}A"
refuse "a three-issue cycle is refused" "dependency cycle" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "issue${T}C${T}Three${T}feature${T}${T}$A" \
  "blockedby${T}A${T}B" \
  "blockedby${T}B${T}C" \
  "blockedby${T}C${T}A"
allow "a chain is not a cycle" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "issue${T}C${T}Three${T}feature${T}${T}$A" \
  "blockedby${T}B${T}A" \
  "blockedby${T}C${T}B"
allow "a diamond is not a cycle" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "issue${T}C${T}Three${T}feature${T}${T}$A" \
  "issue${T}D${T}Four${T}feature${T}${T}$A" \
  "blockedby${T}B${T}A" \
  "blockedby${T}C${T}A" \
  "blockedby${T}D${T}B" \
  "blockedby${T}D${T}C"

# ======================== existing issues can be updated ==================
allow "an update record is valid" "update${T}#12${T}labels${T}feature,P1"
refuse "only an existing #N can be updated" "only an existing #N can be updated" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "update${T}A${T}labels${T}feature"
refuse "an unknown update field is refused" "is not title|labels|milestone|body-file" \
  "update${T}#12${T}assignee${T}someone"
refuse "an empty update value is refused" "use an explicit value, never a blank" \
  "update${T}#12${T}title${T}"
refuse "the same field cannot be updated twice" "is updated twice" \
  "update${T}#12${T}title${T}One" \
  "update${T}#12${T}title${T}Two"
refuse "a missing update body file is refused" "update body file not found" \
  "update${T}#12${T}body-file${T}nope.md"

# The dry-run plan names the exact call, and the tally counts it.
m="$(man "update${T}#12${T}labels${T}feature,P1")"
plan="$(im_plan "$m" "")"
assert_contains "the plan names the update call" "PATCH repos/{owner}/{repo}/issues/12" "$plan"
assert_contains "and counts it" "1 update(s)" "$plan"

# A manifest with no updates keeps its exact original tally line, which is a
# documented contract other callers read.
m="$(man "issue${T}A${T}One${T}feature${T}${T}$A")"
assert_contains "an update-free tally is unchanged" \
  "dry-run: 1 create(s), 0 wire(s); 0 skip(s); no calls made" "$(im_plan "$m" "")"

# ======================== idempotence, via the state file =================
m="$(man "update${T}#12${T}labels${T}feature,P1" "issue${T}A${T}One${T}feature${T}${T}$A")"
st="$work/state"
: > "$st"
assert_contains "a first run would create" "create" "$(im_pending "$m" "$st")"
# Record what a run landed, exactly as im_execute does.
printf 'created\tA\t99\tID99\n' >> "$st"
printf 'wired\tupdate\t#12\tlabels\n' >> "$st"
pending="$(im_pending "$m" "$st")"
assert_contains "a second run skips the create" "skip-create" "$pending"
assert_contains "and skips the update" "skip-update" "$pending"
assert_eq "so nothing is re-created" "" \
  "$(printf '%s\n' "$pending" | awk -F'\037' '$1 == "create"')"
assert_eq "and nothing is re-updated" "" \
  "$(printf '%s\n' "$pending" | awk -F'\037' '$1 == "update"')"

# Partial failure recovery: a state file recording only SOME landings resumes
# from exactly what it records, never from a guess.
: > "$st"
printf 'created\tA\t99\tID99\n' >> "$st"
m="$(man "issue${T}A${T}One${T}feature${T}${T}$A" "issue${T}B${T}Two${T}feature${T}${T}$A")"
pending="$(im_pending "$m" "$st")"
# The separator matters: a bare "skip-create" needle also matches
# "skip-create-ms", so the assertion would have passed on the wrong record.
assert_contains "the landed issue is skipped" "skip-create$(printf '\037')A" "$pending"
assert_eq "and the unlanded one is still created" "B" \
  "$(printf '%s\n' "$pending" | awk -F'\037' '$1 == "create" { print $2 }')"

# A created milestone is resumable the same way.
: > "$st"
m="$(man "milestone${T}MS${T}v9.9${T}x" "issue${T}A${T}One${T}feature${T}MS${T}$A")"
assert_contains "a first run creates the milestone" "create-ms" "$(im_pending "$m" "$st")"
printf 'created\tms:MS\t7\t\n' >> "$st"
assert_contains "a second run skips it" "skip-create-ms" "$(im_pending "$m" "$st")"

# A resumed run must still resolve a milestone referenced by TITLE. The skip
# record used to carry only the KEY, while the lookup for the title was
# suppressed because this manifest owns it — so every rerun died on a milestone
# it had already created. The opposite of the resume contract.
: > "$st"
printf 'created\tms:MS1\t42\t\n' >> "$st"
m="$(man "milestone${T}MS1${T}v9.9 — probe${T}d" \
        "issue${T}A${T}One${T}feature${T}v9.9 — probe${T}$A" \
        "issue${T}B${T}Two${T}feature${T}MS1${T}$A")"
pending="$(im_pending "$m" "$st")"
assert_contains "the skip carries the milestone title" \
  "skip-create-ms$(printf '\037')MS1$(printf '\037')42$(printf '\037')v9.9 — probe" "$pending"
assert_eq "and a rerun needs no lookup for a title it owns" "" \
  "$(printf '%s\n' "$pending" | grep '^lookup-ms' || true)"

# One action for every external title, so a single listing resolves them all.
m="$(man "issue${T}A${T}One${T}feature${T}v1.0${T}$A" \
        "issue${T}B${T}Two${T}feature${T}v2.0${T}$A")"
assert_eq "every external milestone resolves from one listing" "1" \
  "$(im_pending "$m" "" | grep -c '^lookup-ms')"

# ======================== order is applied, not discarded =================
# Preferred order lives on GitHub as sub-issue order under a parent — the
# authority `spark next` reads. An order record that produced no action was
# validated and then thrown away, while the skill told the agent to use it.
m="$(man "issue${T}P${T}Parent${T}feature${T}${T}$A" \
        "issue${T}A${T}One${T}feature${T}${T}$A" \
        "issue${T}B${T}Two${T}feature${T}${T}$A" \
        "subissue${T}P${T}A" \
        "subissue${T}P${T}B" \
        "order${T}A${T}1" \
        "order${T}B${T}2")"
plan="$(im_plan "$m" "")"
assert_contains "an order under a parent is planned" "sub_issues/priority" "$plan"
assert_contains "and counted" "2 order placement(s)" "$plan"
assert_contains "naming the position" "at position 1 under P" "$plan"
# Ordered by position, so the placements come out in the declared sequence.
assert_eq "placements are emitted in position order" "A B" \
  "$(im_pending "$m" "" | awk -F'\037' '$1 == "order" { printf "%s%s", s, $3; s = " " }')"
# An order record for an issue attached to nothing has nowhere to go, and must
# say so rather than reporting success with the data dropped.
m="$(man "issue${T}A${T}One${T}feature${T}${T}$A" "order${T}A${T}1")"
assert_contains "an unattached order says it cannot be applied" \
  "CANNOT be applied" "$(im_plan "$m" "")"

# ======================== a disguised prerequisite, loosely ===============
# The refusal was exact-match and case-sensitive, so ORDER, Order, "preferred
# order" and "ordering" all slipped through and wired a real prerequisite.
for reason in ORDER Order "preferred order" ordering SEQUENCE "by priority"; do
  refuse "a blockedby declared '$reason' is refused" "preferred order is not a prerequisite" \
    "issue${T}A${T}One${T}feature${T}${T}$A" \
    "issue${T}B${T}Two${T}feature${T}${T}$A" \
    "blockedby${T}B${T}A${T}$reason"
done

# The optional reason belongs to blockedby only: relaxing subissue too meant a
# record with a stray trailing field passed with it discarded.
refuse "a subissue takes no fourth field" "subissue record needs 3" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "issue${T}B${T}Two${T}feature${T}${T}$A" \
  "subissue${T}A${T}B${T}junk"

# ======================== unresolved decisions refuse =====================
allow "a decision record is valid" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "decision${T}A${T}One issue or two?"
refuse "a decision needs a question" "decision question is empty" \
  "issue${T}A${T}One${T}feature${T}${T}$A" \
  "decision${T}A${T}"
m="$(man "issue${T}A${T}One${T}feature${T}${T}$A" "decision${T}A${T}One issue or two?")"
assert_contains "the dry-run surfaces the decision" "needs a human answer" "$(im_plan "$m" "")"
assert_contains "and warns that apply refuses" "apply refuses until" "$(im_plan "$m" "")"
# A live run must refuse BEFORE the first call, not part-way through — and
# WITHOUT needing gh, because detecting an unresolved decision is local. This
# assertion used to depend on the host: with gh absent the run failed with
# "gh was not found" instead, so the artifact's blocking human decision was never
# surfaced and the documented all-suite validation did not pass in a supported
# zero-gh environment (#516). CI has gh, which is why it stayed hidden.
#
# Both hosts are now driven explicitly rather than inherited.
nogh_bin="$work/nogh"; mkdir -p "$nogh_bin"
for t in bash sh env awk sed grep cat cut tr sort head tail wc printf mktemp rm \
         mkdir cp mv ln chmod touch find dirname basename date ls readlink uname \
         paste comm uniq git jq python3 timeout; do
  ts="$(command -v "$t" 2>/dev/null || true)"; [ -n "$ts" ] && ln -sf "$ts" "$nogh_bin/$t"
done
withgh="$work/withgh"; mkdir -p "$withgh"
cp -a "$nogh_bin/." "$withgh/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$withgh/gh"; chmod +x "$withgh/gh"

for host in nogh withgh; do
  case "$host" in
    nogh)   hbin="$nogh_bin"; hdesc="with no gh on PATH" ;;
    withgh) hbin="$withgh";   hdesc="with a gh on PATH" ;;
  esac
  st="$work/st2-$host"
  rc=0; out="$(env PATH="$hbin" bash "$IM" --state "$st" "$m" 2>&1)" || rc=$?
  assert_rc "a live run refuses on an unresolved decision, $hdesc" 2 "$rc"
  assert_contains "and says nothing was written, $hdesc" \
    "nothing was created, updated, or wired" "$out"
  assert_contains "naming the decision, $hdesc" "needs a human answer" "$out"
  # The refusal must NOT report the wrong problem.
  case "$out" in
    *"gh (GitHub CLI) is required"*)
      bad "the decision refusal reported a missing gh instead, $hdesc" ;;
    *) ok ;;
  esac
  # No state file: a run that contacted nothing has nothing to resume.
  if [ -e "$st" ]; then bad "a refused run wrote a state file, $hdesc"; else ok; fi
done

# --fresh truncates the state file, so it must also wait for every refusal. A
# refused --fresh run had already forgotten prior landings — a write on a path
# that promises none.
st="$work/st2-fresh"
printf 'created\tOLD\t42\t9042\n' > "$st"
before="$(cat "$st")"
rc=0; out="$(env PATH="$nogh_bin" bash "$IM" --fresh --state "$st" "$m" 2>&1)" || rc=$?
assert_rc "a refused --fresh run still exits 2" 2 "$rc"
assert_eq "and leaves prior landings intact" "$before" "$(cat "$st")"
assert_eq "and no state file was written" "0" \
  "$([ -s "$work/st2" ] && echo 1 || echo 0)"

# ======================== the schema layer refuses meaning ================
model="$(resolve_governance)"
sch() { plan_schema_rows "$model" "$(man "$@")"; }

assert_eq "a fully-declared issue passes the schema" "" \
  "$(sch "issue${T}A${T}One${T}feature,P1,docs-impact:none${T}${T}$A")"
assert_contains "an undeclared label is refused" "is not declared by any governed family" \
  "$(sch "issue${T}A${T}One${T}nonsense-category,P1${T}${T}$A")"
assert_contains "two categories are refused" "category allows exactly-one but the plan sets 2" \
  "$(sch "issue${T}A${T}One${T}feature,bug,docs-impact:none${T}${T}$A")"
assert_contains "a missing required family is refused" "docs-impact is required" \
  "$(sch "issue${T}A${T}One${T}feature,P1${T}${T}$A")"
assert_contains "an invalid priority is refused" "is not declared by any governed family" \
  "$(sch "issue${T}A${T}One${T}feature,P9,docs-impact:none${T}${T}$A")"
assert_contains "two priorities are refused" "priority allows exactly-one but the plan sets 2" \
  "$(sch "issue${T}A${T}One${T}feature,P1,P2,docs-impact:none${T}${T}$A")"
# An update that sets labels is held to the same rules.
assert_contains "an update's labels are validated too" "is not declared by any governed family" \
  "$(sch "update${T}#12${T}labels${T}nonsense-category")"
# The exclusive member must be refused HERE too. Without it a plan declaring
# `docs-impact:none` beside another value validated cleanly and was then
# hard-FAILed as INVALID at validate time — the exact drift between plan and
# enforcement this surface exists to stop.
assert_contains "an exclusive value combined with another is refused" \
  "is exclusive but the plan combines it" \
  "$(sch "issue${T}A${T}One${T}feature,docs-impact:none,docs-impact:reference${T}${T}$A")"
# And the enforcement layer agrees, which is the point.
rc=0; out="$(di_grade "docs-impact:none docs-impact:reference" "" "docs-impact:none")" || rc=$?
assert_eq "the enforcement layer refuses the same combination" 1 "$rc"
assert_contains "for the same reason" "INVALID" "$out"

# ======================== the verb's own contract =========================
good="$(man "issue${T}A${T}One${T}feature,P1,docs-impact:none${T}${T}$A")"
rc=0; out="$("$SPARK" plan validate "$good" 2>&1)" || rc=$?
assert_rc "validate passes a good artifact" 0 "$rc"
assert_contains "and says it wrote nothing" "nothing was contacted or written" "$out"

bad="$(man "issue${T}A${T}One${T}feature,bug${T}${T}$A")"
rc=0; out="$("$SPARK" plan validate "$bad" 2>&1)" || rc=$?
assert_rc "validate fails an artifact the schema refuses" 1 "$rc"

# apply is a remote mutation and must refuse without explicit approval.
rc=0; out="$("$SPARK" plan apply "$good" 2>&1)" || rc=$?
assert_rc "apply refuses without --yes" 1 "$rc"
assert_contains "and points at diff first" "spark plan diff" "$out"

# A missing artifact is an error, not an empty success.
rc=0; out="$("$SPARK" plan validate "$work/nope.tsv" 2>&1)" || rc=$?
assert_rc "a missing artifact fails" 1 "$rc"
rc=0; out="$("$SPARK" plan 2>&1)" || rc=$?
assert_contains "bare plan prints usage" "validate|diff|apply|verify" "$out"

# verify cannot claim a match it could not read, and — the case that matters —
# must not report PASS for an artifact it checked NOTHING about. A slate of
# creates and wiring produced no rows at all, so the empty set read as
# confirmation.
#
# Pinned with a stub gh that authenticates: relying on the sandbox to
# de-authenticate made these assertions invert whenever GH_TOKEN was set in the
# environment, which is the same vacuous-pass hazard one level up.
mkdir -p "$WORK/stub"
cat > "$WORK/stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  auth) exit 0 ;;
  issue) echo ""; exit 1 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$WORK/stub/gh"
rc=0; out="$(PATH="$WORK/stub:$PATH" "$SPARK" plan verify "$good" --state "$work/absent.state" 2>&1)" || rc=$?
assert_rc "verify with nothing verifiable is not assessed" 3 "$rc"
case "$out" in *PASS*) bad "verify must never PASS for an artifact it checked nothing about" ;; *) ok ;; esac
assert_contains "and says why" "NOT ASSESSED" "$out"

# Without gh at all it is also not assessed, never a pass.
rc=0; out="$("$SPARK" plan verify "$good" 2>&1)" || rc=$?
assert_rc "verify is not assessed without gh" 3 "$rc"
assert_contains "and says so" "NOT ASSESSED" "$out"
case "$out" in *PASS*) bad "verify must never PASS without reading GitHub" ;; *) ok ;; esac

# An option that takes a value must say so rather than aborting with no output.
rc=0; out="$("$SPARK" plan diff "$good" --state 2>&1)" || rc=$?
assert_rc "--state with no value fails" 1 "$rc"
assert_contains "and names the problem" "needs a file argument" "$out"

# diff is read-only.
before="$(git -C "$repo" status --porcelain)"
"$SPARK" plan diff "$good" >/dev/null 2>&1 || true
assert_eq "diff writes nothing" "$before" "$(git -C "$repo" status --porcelain)"

finish
