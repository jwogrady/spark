#!/usr/bin/env bash
# footprint.sh [worktree] — physical repository footprint of a worktree (run against the frozen detached worktree).
# Method: `git ls-files` (tracked files only), bytes via wc -c, LOC via wc -l (physical newlines, no blank/comment filtering).
# Fail-closed: every required number is captured into a variable BEFORE it is printed, so a failing git, cat, wc,
# find or awk aborts the run (set -e on the assignment) instead of being masked by a successful echo/printf.
# The only masked statuses are measurements: grep status 1 (no match → zero count) via gc(); nothing else.
set -euo pipefail
cd "${1:-/home/john/code/spark/.claude/worktrees/baseline-921c982}"
gc() { local rc=0; grep "$@" || rc=$?; [ "$rc" -le 1 ] || { echo "grep failed with status $rc: grep $*" >&2; exit "$rc"; }; }
count() { gc -cE "$1" "${@:2}"; }
emit() { printf '%s=%s\n' "$1" "$2"; }

sha="$(git rev-parse HEAD)";                        emit sha "$sha"
n="$(git ls-files | wc -l)";                        emit tracked_files "$n"
b="$(git ls-files -z | xargs -0 cat | wc -c)";      emit tracked_bytes "$b"
l="$(git ls-files -z | xargs -0 cat | wc -l)";      emit tracked_loc "$l"
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
# Coverage integrity: every tracked file must be in exactly one bucket. The inventories are materialized with
# status-checked commands (no process substitution, whose failures comm cannot see), and a non-empty uncovered
# or multiply-bucketed list is a FAILURE of the measurement, not a note — the run exits 3.
ALL="$(mktemp)"; UNIQ="$(mktemp)"; trap 'rm -f "$COVER" "$ALL" "$UNIQ"' EXIT
git ls-files | sort > "$ALL"
sort -u "$COVER" > "$UNIQ"
uncovered="$(comm -23 "$ALL" "$UNIQ")"
dups="$(sort "$COVER" | uniq -d)"
echo "=== bucket coverage check: tracked files in no bucket ==="
[ -z "$uncovered" ] || printf '%s\n' "$uncovered"
echo "=== bucket coverage check: tracked files in more than one bucket ==="
[ -z "$dups" ] || printf '%s\n' "$dups"
s="$(wc -l < "$COVER")";                            emit bucket_file_sum "$s"
if [ -n "$uncovered" ] || [ -n "$dups" ]; then echo "COVERAGE FAILURE: every tracked file must be in exactly one bucket" >&2; exit 3; fi
echo
echo "=== by extension (tracked) ==="
git ls-files | sed -E 's/.*\.([A-Za-z0-9]+)$/\1/; t; s/.*/(noext)/' | sort | uniq -c | sort -rn
echo
echo "=== dispatcher ==="
f=plugins/spark/bin/spark
dl="$(wc -l < $f)"; db="$(wc -c < $f)";             printf 'dispatcher_lines=%s  dispatcher_bytes=%s\n' "$dl" "$db"
v="$(count '^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{' $f)"; emit dispatcher_functions "$v"
v="$(awk '/^VERBS=/{f=1;next} f&&/^[A-Z]*"?$|^"$/{f=0} f' $f | count '^[a-z][a-z-]*\|' -)"; emit dispatcher_verbs_in_VERBS_table "$v"
v="$(count '^cmd_[a-z_]+\(\)' $f)";                emit dispatcher_cmd_functions "$v"
v="$(cat plugins/spark/lib/*.sh | count '^cmd_[a-z_]+\(\)' -)"; emit lib_cmd_functions "$v"
echo "lib_modules:"
for m in plugins/spark/lib/*.sh; do ml="$(wc -l < "$m")"; mf="$(count '^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{' "$m")"; printf '  %s\tlines=%s\tfunctions=%s\n' "$m" "$ml" "$mf"; done
echo
echo "=== counts ==="
v="$(git ls-files docs/adr | wc -l)";               emit adr_files "$v"
v="$(gc -liE '^\*?\*?status\*?\*?:?.*(superseded|deprecated)' docs/adr/*.md | wc -l)"; emit adr_superseded_or_deprecated "$v"
v="$(git ls-files docs/releases | wc -l)";          emit release_records "$v"
v="$(ls -d plugins/spark/skills/*/ | wc -l)";       emit skills_core "$v"
v="$(ls -d plugins/spark-*/skills/*/ | wc -l)";     emit skills_companion "$v"
v="$(ls tests/test-*.sh | wc -l)";                  emit test_suites "$v"
v="$(git ls-files .github/workflows | wc -l)";      emit workflows "$v"
v="$(cat plugins/spark/preferences/*.tsv | gc -vc '^#')"; emit preferences_rows "$v"
v="$(count '^## `spark ' plugins/spark/docs/reference/cli.md)"; emit cli_verbs_documented "$v"
v="$(gc -vcE '^#|^\s*$|^verb\b' plugins/spark/preferences/cli-stability.tsv)"; emit cli_stability_rows "$v"
v="$(git ls-files plugins/spark/preferences/governance-models | wc -l)"; emit governance_models "$v"
v="$(count '^[a-z_]+\(\)' tests/lib.sh)";           emit test_lib_helpers "$v"
echo
echo "=== runtime dependency surface (external binaries referenced by runtime, textual) ==="
cat plugins/spark/bin/spark plugins/spark/lib/*.sh plugins/spark/scripts/hooks/* plugins/spark/hooks/*.sh | gc -oE '\b(gh|jq|python3|awk|sed|grep|curl|git|date|mktemp|sort|tr|cut|wc|find|xargs|flock|stat|strace)\b' | sort | uniq -c | sort -rn
