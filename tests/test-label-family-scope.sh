#!/usr/bin/env bash
# Behavioural suite for #637 — Spark mutates only the governed label families
# the plan declares.
#
# The defect this pins: the compiler rejected an unmanaged label placed in an
# artifact AND replaced the whole GitHub label set on apply, so an issue
# carrying a legitimate project-local label had no safe update path at all —
# omit it and apply deleted it, include it and validation refused it.
#
# The fixture is the Business Solutions shape that found it: a `feedback` label
# belonging to no governed family, alongside a category replacement, a
# docs-impact replacement and a disposition addition in one approved plan.
#
# ONE PRODUCER. `plan_label_scope` is the only place the resulting set is
# calculated; validate, diff, apply and verify all consume it. The mutation
# control below restores whole-set replacement inside that one function and
# requires the fixture to go red — a second implementation living anywhere else
# would keep the fixture green and the control would say so.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
IM="$WORK/plugin/skills/plan/scripts/issue-manifest.sh"
. "$SPARK"   # resolve_governance / plan_label_scope / plan_live_rows

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

model="$(resolve_governance)"
T=$'\t'

# set_eq <desc> <want-csv> <got-lines> — order-insensitive set equality, so the
# assertion is about membership and never about the order a set happened to
# come out in.
set_eq() {
  local desc="$1" want got
  want="$(printf '%s' "$2" | tr ',' '\n' | awk 'NF' | LC_ALL=C sort | paste -sd, -)"
  got="$(printf '%s\n' "$3" | awk 'NF' | LC_ALL=C sort | paste -sd, -)"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# ---------------------------------------------------------------------------
# The Business Solutions regression fixture.
# ---------------------------------------------------------------------------
BS_LIVE=$'feedback\nbug\ndocs-impact:public'
BS_PLAN='feature,docs-impact:none,backlog'

set_eq "the regression fixture: unmanaged feedback survives a three-family update" \
  'feedback,feature,docs-impact:none,backlog' \
  "$(plan_label_scope "$model" "$BS_PLAN" "$BS_LIVE" target)"

# Positive preservation and real removal are separate claims. A producer that
# preserved everything would pass the line above and fail these.
case $'\n'"$(plan_label_scope "$model" "$BS_PLAN" "$BS_LIVE" target)"$'\n' in
  *$'\n'bug$'\n'*) bad "the old category must disappear" ;;
  *) ok ;;
esac
case $'\n'"$(plan_label_scope "$model" "$BS_PLAN" "$BS_LIVE" target)"$'\n' in
  *$'\n'docs-impact:public$'\n'*) bad "the old docs-impact member must disappear" ;;
  *) ok ;;
esac
case $'\n'"$(plan_label_scope "$model" "$BS_PLAN" "$BS_LIVE" target)"$'\n' in
  *$'\n'feedback$'\n'*) ok ;;
  *) bad "the unmanaged feedback label must remain" ;;
esac

# The families the plan touches come from the ARTIFACT, never from live state.
set_eq "three governed families are touched by this plan" \
  'category,docs-impact,disposition' \
  "$(plan_label_scope "$model" "$BS_PLAN" "$BS_LIVE" families)"

# `replaced` is what the update removes, and the set `verify` holds the artifact
# to. It must never include a label outside the touched families.
set_eq "only the touched families' live members are replaced" \
  'bug,docs-impact:public' \
  "$(plan_label_scope "$model" "$BS_PLAN" "$BS_LIVE" replaced)"

# ---------------------------------------------------------------------------
# A governed family the plan does not touch is not the plan's to change.
# ---------------------------------------------------------------------------
set_eq "an untouched governed family survives" \
  'feedback,P1,feature,docs-impact:none,backlog' \
  "$(plan_label_scope "$model" "$BS_PLAN" $'feedback\nP1\nbug\ndocs-impact:public' target)"

set_eq "a single-family plan touches nothing else" \
  'feedback,bug,docs-impact:public,backlog' \
  "$(plan_label_scope "$model" 'backlog' "$BS_LIVE" target)"

# An artifact label already live is not duplicated into the result.
set_eq "re-declaring the live member is idempotent" \
  'feedback,bug,docs-impact:public' \
  "$(plan_label_scope "$model" 'bug,docs-impact:public' "$BS_LIVE" target)"

# Applying the same plan twice must be a fixed point — otherwise `verify` after
# a correct apply would report drift forever.
set_eq "applying the resolved result again changes nothing" \
  'feedback,feature,docs-impact:none,backlog' \
  "$(plan_label_scope "$model" "$BS_PLAN" \
       "$(plan_label_scope "$model" "$BS_PLAN" "$BS_LIVE" target)" target)"

# ---------------------------------------------------------------------------
# Validation permits the family-scoped plan shape.
# ---------------------------------------------------------------------------
art="$WORK/plan.tsv"

# `docs-impact` is a REQUIRED family. On a create the artifact is the whole set,
# so silence there is still a violation. On an update the artifact is partial
# intent, and demanding every required family would force the plan to restate —
# and therefore claim authority over — families it is not changing.
printf 'update\t#7\tlabels\tbacklog\n' > "$art"
if [ -z "$(plan_schema_rows "$model" "$art")" ]; then ok
else bad "a single-family update must validate: $(plan_schema_rows "$model" "$art")"; fi

printf 'update\t#7\tlabels\tfeature,docs-impact:none,backlog\n' > "$art"
if [ -z "$(plan_schema_rows "$model" "$art")" ]; then ok
else bad "the regression plan must validate: $(plan_schema_rows "$model" "$art")"; fi

# The create path is unchanged: there is no live set to preserve, so the
# artifact IS the whole set and a required family must be declared.
printf 'issue\tA\tOne\tfeature\t\tb.md\n' > "$art"
case "$(plan_schema_rows "$model" "$art")" in
  *"docs-impact is required"*) ok ;;
  *) bad "a create must still declare every required family" ;;
esac

# An unmanaged label still has no place in the artifact — that is the point.
# It survives because Spark does not touch its family, not because the
# governance model was made to adopt it.
printf 'update\t#7\tlabels\tfeature,feedback\n' > "$art"
case "$(plan_schema_rows "$model" "$art")" in
  *'label "feedback" is not declared by any governed family'*) ok ;;
  *) bad "an unmanaged label in the artifact must still be refused" ;;
esac

# Cardinality and exclusivity still hold inside the declared families.
printf 'update\t#7\tlabels\tfeature,bug\n' > "$art"
case "$(plan_schema_rows "$model" "$art")" in
  *"category allows exactly-one but the plan sets 2"*) ok ;;
  *) bad "two categories in one update must still fail" ;;
esac
printf 'update\t#7\tlabels\tdocs-impact:none,docs-impact:public\n' > "$art"
case "$(plan_schema_rows "$model" "$art")" in
  *"is exclusive but the plan combines it"*) ok ;;
  *) bad "the exclusive docs-impact member must still be enforced" ;;
esac

# ---------------------------------------------------------------------------
# A stubbed GitHub, so diff/apply/verify are exercised as themselves.
# ---------------------------------------------------------------------------
mkdir -p "$WORK/bin" "$WORK/live"
export GH_LIVE_DIR="$WORK/live" GH_PATCH_LOG="$WORK/patch.log"
export PATH="$WORK/bin:$PATH"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Minimal GitHub stub: live labels per issue in $GH_LIVE_DIR/<n>.labels, and
# every label PATCH appended to $GH_PATCH_LOG as a csv.
set -uo pipefail
case "${1:-}" in
  auth) exit 0 ;;
  issue)
    n="${3:-}"
    [ -f "$GH_LIVE_DIR/$n.labels" ] && cat "$GH_LIVE_DIR/$n.labels"
    exit 0 ;;
  api)
    ep="${2:-}"
    case "$ep" in
      *labels\?per_page=100) cat "$GH_LIVE_DIR/all.labels"; exit 0 ;;
    esac
    csv=""
    for a in "$@"; do
      case "$a" in "labels[]="*) csv="${csv}${csv:+,}${a#labels[]=}" ;; esac
    done
    n="${ep##*/}"
    [ -n "$csv" ] && printf '%s\t%s\n' "$n" "$csv" >> "$GH_PATCH_LOG"
    exit 0 ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"

printf '%s\n' feedback bug feature documentation chore tech-debt research \
  infrastructure P0 P1 P2 P3 decision human-approval backlog release-gate \
  docs-impact:none docs-impact:public docs-impact:reference \
  docs-impact:operator docs-impact:architecture docs-impact:roadmap \
  docs-impact:release docs-impact:companion > "$WORK/live/all.labels"
printf '%s\n' feedback bug docs-impact:public > "$WORK/live/7.labels"

# --- diff previews the family-scoped mutation, not a whole-set replacement ---
printf 'update\t#7\tlabels\tfeature,docs-impact:none,backlog\n' > "$art"
rows="$(plan_live_rows "$art")"
case "$rows" in
  *'~'*) ok ;;
  *) bad "diff must report the pending governed change, got: $rows" ;;
esac
case "$rows" in
  *'preserved'*feedback*) ok ;;
  *) bad "diff must name the labels it preserves, got: $rows" ;;
esac
# The preserved label is not reported as something the plan will remove.
case "$rows" in
  *'governed labels are "bug, docs-impact:public"'*) ok ;;
  *) bad "diff must scope the delta to the touched families, got: $rows" ;;
esac

# --- apply performs it, through the real script and the real API call --------
: > "$GH_PATCH_LOG"
out="$(cd "$repo" && "$SPARK" plan apply "$art" --yes 2>&1)" || {
  bad "apply failed: $out"; }
applied="$(awk -F'\t' '$1 == "7" { print $2; exit }' "$GH_PATCH_LOG")"
set_eq "apply PATCHes the family-scoped result, feedback included" \
  'feedback,feature,docs-impact:none,backlog' "$(printf '%s' "$applied" | tr ',' '\n')"

# --- verify passes without the artifact owning the unmanaged label -----------
printf '%s\n' feedback feature docs-impact:none backlog > "$WORK/live/7.labels"
rows="$(plan_live_rows "$art")"
case "$rows" in
  *$'live\t=\t#7'*) ok ;;
  *) bad "verify must pass on the family-scoped result, got: $rows" ;;
esac

# --- MUTATION CONTROL --------------------------------------------------------
# Restore whole-set replacement inside the one producer: stop preserving the
# live labels the plan does not own. The regression fixture must go red.
# The mutant is a COMPLETE plugin copy: sourcing a lone binary from outside the
# plugin tree would resolve its runtime modules to the wrong root.
mutant_runtime 's|else if (!owned \&\& !(l in art)) print l|else if (0) print l|'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi
mtarget="$(bash -c '. "$1"; plan_label_scope "$2" "$3" "$4" target' _ "$MUT" "$model" "$BS_PLAN" "$BS_LIVE")"
case $'\n'"$mtarget"$'\n' in
  *$'\n'feedback$'\n'*) bad "MUTATION control — whole-set replacement still preserved feedback; the fixture does not discriminate" ;;
  *) ok ;;
esac

finish
