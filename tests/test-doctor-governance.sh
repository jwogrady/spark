#!/usr/bin/env bash
# Behavioral suite for the governance guards doctor adds: reference laziness
# (#294 — progressive disclosure stays lazy), release-component parity (#291),
# and the skill-taxonomy mirrors (README.md/CLAUDE.md restatements stay in
# parity with the shipped skills). Sources bin/spark (dispatch is
# source-guarded) and drives the factored checks against throwaway fixtures.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # load check_reference_laziness and friends

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

# tightened regex: bare "read the references" is legitimate lazy prose and must
# NOT trip an ERROR (only clearly-eager phrasings do).
mk_skill 'When stuck, read the [detail](references/r.md) reference for edge cases.'
rc=0; out="$(check_reference_laziness "$root")" || rc=$?
assert_rc "bare 'read the ... reference' does not false-positive" 0 "$rc"

# but an eager "read all references first" still trips.
mk_skill 'Read all references first. [detail](references/r.md)'
rc=0; out="$(check_reference_laziness "$root")" || rc=$?
assert_rc "'read all references first' trips" 1 "$rc"
assert_contains "names the eager offender" "eager reference loading" "$out"

# ===================== #291 release-component parity =====================
# The runner verifies one component per Release Please package; a package with
# no matching component ships UNVERIFIED notes. Only meaningful when a JSON tool
# is present — skip the value assertions otherwise (the check returns 2 = skip).
croot="$WORK/rcpmkt"
mkdir -p "$croot/.github/scripts"
mk_config() { # <json packages object body>
  printf '{ "packages": %s }\n' "$1" > "$croot/release-please-config.json"
}
mk_runner() { # <space-separated component list>
  printf 'NOTES_COMPONENTS="%s"\n' "$1" > "$croot/.github/scripts/release-notes-runner.sh"
}

if command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
  # aligned: `.`->core, plugins/x->x, matching the runner list -> passes.
  mk_config '{ ".": {}, "plugins/spark-audit": {}, "plugins/spark-connect": {} }'
  mk_runner 'core spark-audit spark-connect'
  rc=0; out="$(check_release_component_parity "$croot")" || rc=$?
  assert_rc "aligned components pass" 0 "$rc"
  assert_contains "reports the matched set" "release components match" "$out"

  # a package with no runner component -> drift, fails, names both sets.
  mk_config '{ ".": {}, "plugins/spark-audit": {}, "plugins/spark-ghost": {} }'
  mk_runner 'core spark-audit'
  rc=0; out="$(check_release_component_parity "$croot")" || rc=$?
  assert_rc "extra package fails" 1 "$rc"
  assert_contains "names the drift" "release-component drift" "$out"
  assert_contains "warns notes go unverified" "UNVERIFIED" "$out"
  assert_contains "names the missing component" "spark-ghost" "$out"

  # a runner component with no package -> also drift (unexpected component).
  mk_config '{ ".": {}, "plugins/spark-audit": {} }'
  mk_runner 'core spark-audit spark-stale'
  rc=0; out="$(check_release_component_parity "$croot")" || rc=$?
  assert_rc "unexpected component fails" 1 "$rc"
  assert_contains "names the unexpected component" "spark-stale" "$out"
else
  echo "  (jq/python3 absent — release-component parity value checks skipped)"
fi

# not this repo (no config/runner) -> returns 3, silent.
rc=0; out="$(check_release_component_parity "$WORK/emptyrepo")" || rc=$?
assert_rc "absent files skip cleanly" 3 "$rc"

# ======================= skill-taxonomy mirrors (D-6) =======================
mroot="$WORK/mirrorrepo"
mkdir -p "$mroot/plugins/spark/skills/ideate" "$mroot/plugins/spark/skills/onboard"

# both mirrors name every shipped skill -> passes.
printf '# readme\nSkills: `ideate`, `onboard`.\n' > "$mroot/README.md"
printf '# claude\nSkills: `ideate`, `onboard`.\n' > "$mroot/CLAUDE.md"
rc=0; out="$(check_taxonomy_mirrors "$mroot" "$mroot/plugins/spark")" || rc=$?
assert_rc "complete mirrors pass" 0 "$rc"

# a mirror that drops a skill -> fails, names the doc and the skill.
printf '# claude\nSkills: `ideate`.\n' > "$mroot/CLAUDE.md"
rc=0; out="$(check_taxonomy_mirrors "$mroot" "$mroot/plugins/spark")" || rc=$?
assert_rc "omitted skill fails" 1 "$rc"
assert_contains "names the omitting mirror and skill" 'CLAUDE.md mirrors the skill taxonomy but omits `onboard`' "$out"

# an unbackticked mention does not count — the mirrors list skills as code.
printf '# claude\nSkills: `ideate`, onboard.\n' > "$mroot/CLAUDE.md"
rc=0; out="$(check_taxonomy_mirrors "$mroot" "$mroot/plugins/spark")" || rc=$?
assert_rc "bare-word mention is not a mirror entry" 1 "$rc"

# not this repo (a mirror absent) -> returns 3, silent.
rm "$mroot/CLAUDE.md"
rc=0; out="$(check_taxonomy_mirrors "$mroot" "$mroot/plugins/spark")" || rc=$?
assert_rc "absent mirror skips cleanly" 3 "$rc"

finish
