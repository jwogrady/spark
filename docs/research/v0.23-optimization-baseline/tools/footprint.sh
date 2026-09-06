#!/usr/bin/env bash
# footprint.sh [worktree] — physical repository footprint of a worktree (run against the frozen detached worktree).
# Method: `git ls-files` (tracked files only), bytes via wc -c, LOC via wc -l (physical newlines, no blank/comment filtering).
# Fail-closed: any failing git/wc/find/grep that produces a required number aborts the run with a non-zero status.
# Probes that may legitimately match nothing (a grep -c count, the "not covered" listing) are guarded explicitly.
set -euo pipefail
cd "${1:-/home/john/code/spark/.claude/worktrees/baseline-921c982}"
# gc <grep args…>: grep whose exit status 1 (no match) is a valid zero measurement, while any status greater than 1
# (missing file, bad expression, I/O error) aborts the run. `grep -c` already prints 0 on status 1; `grep -l`/`-o`
# print nothing, which downstream `wc -l` counts as 0.
gc() { local rc=0; grep "$@" || rc=$?; [ "$rc" -le 1 ] || { echo "grep failed with status $rc: grep $*" >&2; exit "$rc"; }; }
count() { gc -cE "$1" "${@:2}"; }
echo "sha=$(git rev-parse HEAD)"
echo "tracked_files=$(git ls-files | wc -l)"
echo "tracked_bytes=$(git ls-files -z | xargs -0 cat | wc -c)"
echo "tracked_loc=$(git ls-files -z | xargs -0 cat | wc -l)"
echo
COVER="$(mktemp)"; trap 'rm -f "$COVER"' EXIT
bucket() { # <name> <pathspec...>
  local name="$1"; shift
  local files bytes loc
  git ls-files -- "$@" >> "$COVER"
  files="$(git ls-files -- "$@" | wc -l)"
  if [ "$files" -gt 0 ]; then
    bytes="$(git ls-files -z -- "$@" | xargs -0 cat | wc -c)"
    loc="$(git ls-files -z -- "$@" | xargs -0 cat | wc -l)"
  else bytes=0; loc=0; fi
  printf '%s\t%s\t%s\t%s\n' "$name" "$files" "$bytes" "$loc"
}
printf 'bucket\tfiles\tbytes\tloc\n'
bucket runtime.dispatcher plugins/spark/bin
bucket runtime.lib plugins/spark/lib
bucket runtime.scripts plugins/spark/scripts
bucket runtime.hooks plugins/spark/hooks
bucket runtime.settings plugins/spark/settings
bucket runtime.manifests .claude-plugin plugins/spark/.claude-plugin plugins/spark-audit/.claude-plugin plugins/spark-connect/.claude-plugin plugins/spark-docs/.claude-plugin
bucket skills.core.SKILL 'plugins/spark/skills/*/SKILL.md'
bucket skills.core.references 'plugins/spark/skills/*/references/*'
bucket skills.core.agents plugins/spark/agents
bucket skills.core.scripts 'plugins/spark/skills/*/scripts/*'
bucket preferences plugins/spark/preferences
bucket shipped.docs.spark plugins/spark/docs
bucket companions.audit plugins/spark-audit ':(exclude)plugins/spark-audit/.claude-plugin'
bucket companions.connect plugins/spark-connect ':(exclude)plugins/spark-connect/.claude-plugin'
bucket companions.docs plugins/spark-docs ':(exclude)plugins/spark-docs/.claude-plugin'
bucket tests.suites 'tests/test-*.sh'
bucket tests.harness tests/lib.sh tests/run.sh tests/bench.sh tests/bench-memo.sh tests/structure.sh tests/e2e-marketplace-install.sh
bucket tests.other tests ':(exclude,glob)tests/test-*.sh' ':(exclude)tests/lib.sh' ':(exclude)tests/run.sh' ':(exclude)tests/bench.sh' ':(exclude)tests/bench-memo.sh' ':(exclude)tests/structure.sh' ':(exclude)tests/e2e-marketplace-install.sh'
bucket devdocs.adr docs/adr
bucket devdocs.ops docs/ops
bucket devdocs.architecture docs/architecture
bucket devdocs.releases docs/releases
bucket devdocs.governance docs/governance
bucket devdocs.research docs/research
bucket devdocs.alpha docs/alpha
bucket devdocs.root docs ':(exclude)docs/adr' ':(exclude)docs/ops' ':(exclude)docs/architecture' ':(exclude)docs/releases' ':(exclude)docs/governance' ':(exclude)docs/research' ':(exclude)docs/alpha'
bucket root.contract AGENTS.md CLAUDE.md
bucket root.readme_roadmap README.md ROADMAP.md
bucket root.changelog CHANGELOG.md
bucket github.workflows .github/workflows
bucket github.scripts .github/scripts
bucket github.templates .github ':(exclude).github/workflows' ':(exclude).github/scripts'
bucket release.config .release-please-manifest.json release-please-config.json
bucket dot.other ':(glob).*' ':(exclude).github/**' ':(exclude).claude-plugin/**' ':(exclude).release-please-manifest.json'
bucket root.community CODE_OF_CONDUCT.md CONTRIBUTING.md LICENSE SECURITY.md
bucket project.state .spark
bucket editor.config .vscode
bucket assets.logo assets
bucket evaluations.harness evaluations/lib evaluations/orchestration/run.sh evaluations/skill-routing/run.sh evaluations/evidence-index.tsv evaluations/orchestration/rates.tsv evaluations/skill-routing/rates.tsv
bucket evaluations.fixtures ':(glob)evaluations/*/fixtures/**'
bucket evaluations.runs_evidence ':(glob)evaluations/*/runs/**'
bucket evaluations.prose ':(glob)evaluations/*/*.md'
echo
echo "=== bucket coverage check: tracked files in no bucket ==="
comm -23 <(git ls-files | sort) <(sort -u "$COVER")
echo "=== bucket coverage check: tracked files in more than one bucket ==="
sort "$COVER" | uniq -d
echo "bucket_file_sum=$(wc -l < "$COVER")"
echo
echo "=== by extension (tracked) ==="
git ls-files | sed -E 's/.*\.([A-Za-z0-9]+)$/\1/; t; s/.*/(noext)/' | sort | uniq -c | sort -rn
echo
echo "=== dispatcher ==="
f=plugins/spark/bin/spark
echo "dispatcher_lines=$(wc -l < $f)  dispatcher_bytes=$(wc -c < $f)"
echo "dispatcher_functions=$(count '^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{' $f)"
echo "dispatcher_verbs_in_VERBS_table=$(awk '/^VERBS=/{f=1;next} f&&/^[A-Z]*"?$|^"$/{f=0} f' $f | count '^[a-z][a-z-]*\|' -)"
echo "dispatcher_cmd_functions=$(count '^cmd_[a-z_]+\(\)' $f)"
echo "lib_cmd_functions=$(cat plugins/spark/lib/*.sh | count '^cmd_[a-z_]+\(\)' -)"
echo "lib_modules:"; for m in plugins/spark/lib/*.sh; do printf '  %s\tlines=%s\tfunctions=%s\n' "$m" "$(wc -l < "$m")" "$(count '^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{' "$m")"; done
echo
echo "=== counts ==="
echo "adr_files=$(git ls-files docs/adr | wc -l)"
echo "adr_superseded_or_deprecated=$(gc -liE '^\*?\*?status\*?\*?:?.*(superseded|deprecated)' docs/adr/*.md | wc -l)"
echo "release_records=$(git ls-files docs/releases | wc -l)"
echo "skills_core=$(ls -d plugins/spark/skills/*/ | wc -l)"
echo "skills_companion=$(ls -d plugins/spark-*/skills/*/ | wc -l)"
echo "test_suites=$(ls tests/test-*.sh | wc -l)"
echo "workflows=$(git ls-files .github/workflows | wc -l)"
echo "preferences_rows=$(cat plugins/spark/preferences/*.tsv | gc -vc '^#')"
echo "cli_verbs_documented=$(count '^## `spark ' plugins/spark/docs/reference/cli.md)"
echo "cli_stability_rows=$(gc -vcE '^#|^\s*$|^verb\b' plugins/spark/preferences/cli-stability.tsv)"
echo "governance_models=$(git ls-files plugins/spark/preferences/governance-models | wc -l)"
echo "test_lib_helpers=$(count '^[a-z_]+\(\)' tests/lib.sh)"
echo
echo "=== runtime dependency surface (external binaries referenced by runtime, textual) ==="
cat plugins/spark/bin/spark plugins/spark/lib/*.sh plugins/spark/scripts/hooks/* plugins/spark/hooks/*.sh | gc -oE '\b(gh|jq|python3|awk|sed|grep|curl|git|date|mktemp|sort|tr|cut|wc|find|xargs|flock|stat|strace)\b' | sort | uniq -c | sort -rn
