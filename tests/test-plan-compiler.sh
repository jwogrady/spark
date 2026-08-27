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

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

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
assert_contains "the landed issue is skipped" "skip-create${sep:-}" "$pending"
assert_eq "and the unlanded one is still created" "B" \
  "$(printf '%s\n' "$pending" | awk -F'\037' '$1 == "create" { print $2 }')"

# A created milestone is resumable the same way.
: > "$st"
m="$(man "milestone${T}MS${T}v9.9${T}x" "issue${T}A${T}One${T}feature${T}MS${T}$A")"
assert_contains "a first run creates the milestone" "create-ms" "$(im_pending "$m" "$st")"
printf 'created\tms:MS\t7\t\n' >> "$st"
assert_contains "a second run skips it" "skip-create-ms" "$(im_pending "$m" "$st")"

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
# A live run must refuse BEFORE the first call, not part-way through.
rc=0; out="$(bash "$IM" --state "$work/st2" "$m" 2>&1)" || rc=$?
assert_rc "a live run refuses on an unresolved decision" 2 "$rc"
assert_contains "and says nothing was written" "nothing was created, updated, or wired" "$out"
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

# verify cannot claim a match it could not read.
rc=0; out="$("$SPARK" plan verify "$good" 2>&1)" || rc=$?
assert_rc "verify is not assessed without gh" 3 "$rc"
assert_contains "and says so" "NOT ASSESSED" "$out"
case "$out" in *PASS*) bad "verify must never PASS without reading GitHub" ;; *) ok ;; esac

# diff is read-only.
before="$(git -C "$repo" status --porcelain)"
"$SPARK" plan diff "$good" >/dev/null 2>&1 || true
assert_eq "diff writes nothing" "$before" "$(git -C "$repo" status --porcelain)"

finish
