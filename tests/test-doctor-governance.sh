#!/usr/bin/env bash
# Behavioral suite for the two governance guards doctor adds: reference laziness
# (#294 — progressive disclosure stays lazy) and the capability-traceability
# template seam (#301 — the CEF's collection points can't silently vanish).
# Sources bin/spark (dispatch is source-guarded) and drives the factored checks
# against throwaway fixtures.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # load check_reference_laziness / check_traceability_templates

# ============================ #294 reference laziness ============================
root="$WORK/lazymkt"
mkdir -p "$root/plugins/p/skills/s/references"
mk_skill() { # <body-extra>
  { echo "---"; echo "name: s"; echo "description: A fixture. Use when testing; not for real work."
    echo "---"; echo "# s"; echo "$1"; } > "$root/plugins/p/skills/s/SKILL.md"
}
printf 'reference content\n' > "$root/plugins/p/skills/s/references/r.md"

# clean: the SKILL links its reference -> lazy, passes.
mk_skill 'See [the detail](references/r.md) when you need it.'
rc=0; out="$(check_reference_laziness "$root")" || rc=$?
assert_rc "linked reference passes" 0 "$rc"

# eager-load instruction -> fails, named.
mk_skill 'First, read all references before doing anything.'
rc=0; out="$(check_reference_laziness "$root")" || rc=$?
assert_rc "eager-load instruction fails" 1 "$rc"
assert_contains "names the eager-load offender" "eager reference loading" "$out"

# unlinked reference -> fails, named.
mk_skill 'No links here.'
rc=0; out="$(check_reference_laziness "$root")" || rc=$?
assert_rc "unlinked reference fails" 1 "$rc"
assert_contains "names the unlinked reference" "references/r.md is never linked" "$out"

# ======================= #301 capability-traceability templates =======================
troot="$WORK/ttrepo"
mkdir -p "$troot/.github/ISSUE_TEMPLATE"
seed_templates() {
  printf 'body:\n  - type: textarea\n    id: capability_traceability\n' > "$troot/.github/ISSUE_TEMPLATE/feature.yml"
  printf 'body:\n  - type: textarea\n    id: capability_traceability\n' > "$troot/.github/ISSUE_TEMPLATE/skill.yml"
  printf '## Capability traceability\n- Owned surface:\n' > "$troot/.github/PULL_REQUEST_TEMPLATE.md"
}

# all present -> passes.
seed_templates
rc=0; out="$(check_traceability_templates "$troot")" || rc=$?
assert_rc "complete templates pass" 0 "$rc"

# feature.yml lost the field -> fails, named.
seed_templates
printf 'body:\n  - type: textarea\n    id: problem\n' > "$troot/.github/ISSUE_TEMPLATE/feature.yml"
rc=0; out="$(check_traceability_templates "$troot")" || rc=$?
assert_rc "missing issue field fails" 1 "$rc"
assert_contains "names the issue template" "feature.yml" "$out"

# PR template lost the section -> fails.
seed_templates
printf '## Summary\n' > "$troot/.github/PULL_REQUEST_TEMPLATE.md"
rc=0; out="$(check_traceability_templates "$troot")" || rc=$?
assert_rc "missing PR section fails" 1 "$rc"
assert_contains "names the PR template" "PULL_REQUEST_TEMPLATE" "$out"

finish
