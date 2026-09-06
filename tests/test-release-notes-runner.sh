#!/usr/bin/env bash
# Offline suite for the release-notes runner's pure helpers (#291): manifest
# PR-body splitting, conventional-subject parsing, per-component commit
# collection, and verdict aggregation — plus the end-to-end fixture the issue
# demands: one core release and two companion releases, with a hidden feature
# in core and a companion-only omission whose text appears in CORE's section
# (proving another component's notes never satisfy a commit). No network, no
# gh: the runner is SOURCED (its source-guard keeps main from running) and the
# per-commit label lookup is overridden with a fixture map.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
runner="$root/.github/scripts/release-notes-runner.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

bash -n "$runner" && ok || bad "bash -n release-notes-runner.sh"

# Sourcing must be side-effect free: the guard keeps main() from running.
# shellcheck disable=SC1090
. "$runner"

# --- summary → component mapping. Companions title their <details> block
# "name: X.Y.Z"; core (include-component-in-tag:false) uses the bare version.
[ "$(notes_component_for_summary 'spark-audit: 0.2.0')" = "spark-audit" ] \
  && ok || bad "summary 'spark-audit: 0.2.0' → spark-audit"
[ "$(notes_component_for_summary 'spark-connect: 0.3.1')" = "spark-connect" ] \
  && ok || bad "summary 'spark-connect: 0.3.1' → spark-connect"
[ "$(notes_component_for_summary '0.15.0')" = "core" ] \
  && ok || bad "bare-version summary → core"
[ "$(notes_component_for_summary ' v0.15.0 ')" = "core" ] \
  && ok || bad "v-prefixed, padded summary → core"
[ -z "$(notes_component_for_summary 'mystery-plugin: 1.0.0')" ] \
  && ok || bad "unknown component summary → empty"

# --- subject parsing: the `!` marker must survive a scope (`feat(cli)!:`),
# and non-conventional subjects yield nothing.
[ "$(notes_parse_subject 'feat(cli)!: add the exporter')" = "$(printf 'feat\tadd the exporter\tbreaking')" ] \
  && ok || bad "scoped breaking feat parses with its marker"
[ "$(notes_parse_subject 'chore!: drop the knob')" = "$(printf 'chore\tdrop the knob\tbreaking')" ] \
  && ok || bad "breaking chore parses with its marker"
[ "$(notes_parse_subject 'fix: stop the crash (#42)')" = "$(printf 'fix\tstop the crash (#42)\t')" ] \
  && ok || bad "plain fix parses without a marker"
[ -z "$(notes_parse_subject 'merge trunk into the branch')" ] \
  && ok || bad "non-conventional subject yields nothing"

# --- body splitting: one file per known component, each holding ONLY its own
# section. The core section deliberately contains the companion commit's text
# ("add the audit report exporter") — the split must keep it out of
# spark-audit.md so the integration run below can prove AC-5.
cat > "$work/body.md" <<'EOF'
:robot: I have created a release *beep* *boop*
---


<details><summary>0.15.0</summary>

## [0.15.0](https://github.com/jwogrady/spark/compare/v0.14.0...v0.15.0) (2026-07-22)

### Features

* add the exporter ([#301](https://x/301))
* add the audit report exporter ([#303](https://x/303))
</details>

<details><summary>spark-audit: 0.2.0</summary>

## [0.2.0](https://x) (2026-07-22)

### Features

* an unrelated audit line ([#999](https://x/999))
</details>

<details><summary>spark-connect: 0.2.0</summary>

## [0.2.0](https://x) (2026-07-22)

### ⚠ BREAKING CHANGES

* drop the legacy connect config ([#304](https://x/304))
</details>

---
This PR was generated with Release Please.
EOF
split="$work/split"
mkdir -p "$split"
notes_split_body "$work/body.md" "$split"
grep -q 'add the exporter' "$split/core.md" \
  && ok || bad "core.md carries the core section"
grep -q 'an unrelated audit line' "$split/spark-audit.md" \
  && ok || bad "spark-audit.md carries the audit section"
! grep -q 'add the audit report exporter' "$split/spark-audit.md" \
  && ok || bad "spark-audit.md must not absorb core's text"
grep -q 'drop the legacy connect config' "$split/spark-connect.md" \
  && ok || bad "spark-connect.md carries the connect section"
[ ! -f "$split/spark-docs.md" ] \
  && ok || bad "spark-docs has no section → no file"
! grep -q 'generated with Release Please' "$split/core.md" \
  && ok || bad "text outside <details> blocks is dropped"

# --- single-release fallback: a body with no <details> blocks is core-only.
printf '## 0.15.1\n\n### Bug Fixes\n\n* stop the crash\n' > "$work/plain.md"
mkdir -p "$work/plain-split"
notes_split_body "$work/plain.md" "$work/plain-split"
grep -q 'stop the crash' "$work/plain-split/core.md" \
  && ok || bad "no-details body becomes core.md whole"

# --- verdict aggregation: findings → failure, a broken check → error (which
# dominates), not-assessed rows never count as passes or errors.
results="$(printf 'core\tyes\t0\tall clean\nspark-audit\tyes\t1\t2 findings\nspark-docs\tno\t-\tno notes section\n')"
[ "$(printf '%s\n' "$results" | notes_status_for_results)" = "failure" ] \
  && ok || bad "a component finding folds to failure"
[ "$(printf 'core\tyes\t0\tok\nspark-docs\tno\t-\tno section\n' | notes_status_for_results)" = "success" ] \
  && ok || bad "pass + not-assessed folds to success"
[ "$(printf 'core\tyes\t0\tok\nspark-audit\tyes\t2\tusage error\n' | notes_status_for_results)" = "error" ] \
  && ok || bad "a check that could not run folds to error"
table="$(printf '%s\n' "$results" | notes_render_table)"
case "$table" in
  *'| spark-audit | assessed | fail | 2 findings |'*) ok ;;
  *) bad "table row for an assessed failure" ;;
esac
case "$table" in
  *'| spark-docs | not-assessed | — | no notes section |'*) ok ;;
  *) bad "table row for a not-assessed component" ;;
esac
desc="$(printf '%s\n' "$results" | notes_status_desc)"
[ "$desc" = "core: pass; spark-audit: fail; spark-docs: not-assessed" ] \
  && ok || bad "status description line ($desc)"

# --- #487: exit 3 is duplicate-only — the notes are COMPLETE, one logical
# change merely rendered twice. It must fold to success, and the description
# must disclose the count rather than pass silently.
dupes="$(printf 'core\tyes\t3\tcomplete with 13 accepted duplicate finding(s)\t13\nspark-docs\tno\t-\tno section\t0\n')"
[ "$(printf '%s\n' "$dupes" | notes_status_for_results)" = "success" ] \
  && ok || bad "duplicate-only folds to success"
case "$(printf '%s\n' "$dupes" | notes_status_desc)" in
  *'core: pass with 13 accepted duplicates'*) ok ;;
  *) bad "duplicate-only description must disclose the count" ;;
esac
case "$(printf '%s\n' "$dupes" | notes_render_table)" in
  *'| core | assessed | pass (13 accepted duplicate(s)) |'*) ok ;;
  *) bad "table row discloses accepted duplicates" ;;
esac

# --- the blocking class must win the fold. A duplicate-only component beside
# a blocking one is still a failure, or an omission hides behind an accepted
# duplicate and ships under a green status.
[ "$(printf 'core\tyes\t3\tdupes\t4\nspark-audit\tyes\t1\tomission\t0\n' | notes_status_for_results)" = "failure" ] \
  && ok || bad "blocking finding beside duplicate-only folds to failure"
# --- and a broken check still dominates everything.
[ "$(printf 'core\tyes\t3\tdupes\t4\nspark-audit\tyes\t2\tbroken\t0\n' | notes_status_for_results)" = "error" ] \
  && ok || bad "a broken check dominates a duplicate-only pass"

# --- integration fixture (#291 AC-6): a real (local) git history releasing
# core + spark-audit + spark-connect. Expected verdicts:
#   core          — FAIL: a `feature`-labeled PR merged as `chore:` (hidden
#                   feature, AC-1) is absent from the notes.
#   spark-audit   — FAIL: its feat commit's text sits in CORE's section only;
#                   its own section lacks it (companion-only omission, AC-5).
#   spark-connect — PASS: a breaking `chore!:` present in its own notes (AC-2).
#   spark-docs    — NOT-ASSESSED: no commits, no section.
fixture="$work/repo"
mkdir -p "$fixture"
git -c init.defaultBranch=trunk init -q "$fixture"
gitc() { git -C "$fixture" -c user.name=spark-test -c user.email=test@example.invalid "$@"; }
seed() { mkdir -p "$fixture/$(dirname "$1")"; date +%s%N > "$fixture/$1"; gitc add -A; gitc commit -q -m "$2"; }

seed core.txt 'chore: scaffold the fixture'
seed plugins/spark-audit/a.txt 'chore: scaffold audit'
seed plugins/spark-connect/c.txt 'chore: scaffold connect'
seed plugins/spark-docs/d.txt 'chore: scaffold docs'
gitc tag v0.14.0
gitc tag spark-audit-v0.1.0
gitc tag spark-connect-v0.1.0
gitc tag spark-docs-v0.1.0
seed core.txt 'feat: add the exporter (#301)'
seed .github/guard.txt 'chore: tidy the gate runner (#302)'
seed plugins/spark-audit/a.txt 'feat: add the audit report exporter (#303)'
seed plugins/spark-connect/c.txt 'chore!: drop the legacy connect config (#304)'
head_sha="$(gitc rev-parse HEAD)"

# Offline stand-in for the gh label lookup: the authoritative PR labels, keyed
# by the fixture subjects. The hidden feature carries the `feature` label.
notes_pr_labels() { # <repo> <sha>
  local subj
  subj="$(git log -1 --format='%s' "$2" 2>/dev/null || true)"
  case "$subj" in
    'feat: add the exporter (#301)') echo "feature" ;;
    'chore: tidy the gate runner (#302)') echo "feature,chore" ;;
    'feat: add the audit report exporter (#303)') echo "feature" ;;
    *) echo "" ;;
  esac
}

(cd "$fixture" && notes_run_components "jwogrady/spark" "$head_sha" "$split")

row() { awk -F'\t' -v c="$1" '$1 == c { print $2 "|" $3 }' "$split/results.tsv"; }
[ "$(row core)" = "yes|1" ]          && ok || bad "core assessed and failed ($(row core))"
[ "$(row spark-audit)" = "yes|1" ]   && ok || bad "spark-audit assessed and failed ($(row spark-audit))"
[ "$(row spark-connect)" = "yes|0" ] && ok || bad "spark-connect assessed and passed ($(row spark-connect))"
[ "$(row spark-docs)" = "no|-" ]     && ok || bad "spark-docs honestly not-assessed ($(row spark-docs))"

report="$(cat "$split/report.txt")"
case "$report" in
  *"mislabel: tidy the gate runner (#302)"*) ok ;;
  *) bad "hidden feature (feature-labeled chore) caught in core (AC-1)" ;;
esac
case "$report" in
  *"omission: feat: add the audit report exporter (#303)"*) ok ;;
  *) bad "companion-only omission caught despite the text in core's section (AC-5)" ;;
esac
case "$report" in
  *"every breaking change appears in the notes"*) ok ;;
  *) bad "spark-connect's breaking chore! verified visible (AC-2)" ;;
esac
case "$report" in
  *"spark-connect subject-omission check passed"*) ok ;;
  *) bad "the passing claim names its component" ;;
esac

# Path scoping: the audit commit must not leak into core's commit list (its
# text in core's notes would then mask nothing — the exclusion is what makes
# the AC-5 assertion meaningful) and core's commits must not leak into the
# companion's.
! grep -q 'audit report exporter' "$split/core.tsv" \
  && ok || bad "companion-only commit excluded from core's range"
! grep -q 'add the exporter' "$split/spark-audit.tsv" \
  && ok || bad "core commit excluded from the companion's range"
grep -q "$(printf 'chore\ttidy the gate runner (#302)\tfeature,chore\t')" "$split/core.tsv" \
  && ok || bad "core TSV carries the authoritative PR labels"
grep -q "$(printf 'chore\tdrop the legacy connect config (#304)\t\tbreaking')" "$split/spark-connect.tsv" \
  && ok || bad "connect TSV carries the breaking marker from chore!"

[ "$(notes_status_for_results < "$split/results.tsv")" = "failure" ] \
  && ok || bad "integration verdict folds to failure"

# --- EXECUTED-main regression (the CI-only bug class the sourced tests miss):
# main registers an EXIT trap over a local; after main returns, the trap fires
# out of scope and under set -u an unbound expansion turns a successful run
# into exit 1 at the finish line. Execute the real script with a stub gh whose
# `pr list` returns nothing — main early-returns — AND with a stub returning a
# minimal release PR so the full path (mktemp + trap + split + post) runs to
# completion. Both must exit 0 all the way through process exit.
stub="$work/stubbin"; mkdir -p "$stub"
cat > "$stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "pr list")
    if [ -n "${STUB_PR_JSON:-}" ]; then printf '%s' "$STUB_PR_JSON"; fi ;;
  "api "*|api*) exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$stub/gh"
rc=0; ( cd "$work" && PATH="$stub:$PATH" GITHUB_REPOSITORY=o/r bash "$runner" >/dev/null 2>&1 ) || rc=$?
[ "$rc" -eq 0 ] && ok || bad "executed main (no open release PR) must exit 0 through process exit (got $rc)"
e2e_repo="$work/e2erepo"; mkdir -p "$e2e_repo"
git -C "$e2e_repo" init -q 2>/dev/null
( cd "$e2e_repo" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "chore: seed" )
sha="$(git -C "$e2e_repo" rev-parse HEAD)"
export STUB_PR_JSON="{\"number\":1,\"headRefOid\":\"$sha\",\"body\":\"release me\"}"
rc=0; ( cd "$e2e_repo" && PATH="$stub:$PATH" GITHUB_REPOSITORY=o/r bash "$runner" >/dev/null 2>&1 ) || rc=$?
[ "$rc" -eq 0 ] && ok || bad "executed main (full path incl. EXIT trap) must exit 0 — trap must not die on an out-of-scope local under set -u (got $rc)"
unset STUB_PR_JSON

# ============================================================================
# Hostile-review regressions (F1/F2/F5/F7).
# ============================================================================
# F1: a bad range (deleted/unfetched tag) must be an rc-1 INFRA failure, not an
# empty TSV that later folds to a clean pass.
rc=0; (cd "$fixture" && notes_component_commits_tsv "jwogrady/spark" "core" "vNOSUCH..$head_sha" > /dev/null 2>&1) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "F1: bad range must return nonzero, got $rc"
# ...and run_components records it as an error row (exit-2 class) the fold turns
# into error.
split2="$work/split2"; mkdir -p "$split2"
( cd "$fixture" && notes_last_tag() { case "$1" in core) echo "vNOSUCH";; *) command git tag --list "$1-v[0-9]*" --sort=-v:refname | head -n1;; esac; }
  notes_run_components "jwogrady/spark" "$head_sha" "$split2" )
[ "$(awk -F'\t' '$1=="core"{print $2"|"$3}' "$split2/results.tsv")" = "yes|2" ] \
  && ok || bad "F1: range failure recorded as error row ($(cat "$split2/results.tsv"))"
[ "$(notes_status_for_results < "$split2/results.tsv")" = "error" ] \
  && ok || bad "F1: fold must be error on a range failure"

# F2: a component with releasable commits but NO notes section is a FAILURE
# (dropped release), while no-commits + no-section stays not-assessed.
split3="$work/split3"; mkdir -p "$split3"
cp "$split/core.md" "$split3/core.md" 2>/dev/null || true
seed plugins/spark-docs/d.txt 'feat: add the docs exporter (#305)'
head_sha2="$(gitc rev-parse HEAD)"
( cd "$fixture" && notes_run_components "jwogrady/spark" "$head_sha2" "$split3" )
[ "$(awk -F'\t' '$1=="spark-docs"{print $2"|"$3}' "$split3/results.tsv")" = "yes|1" ] \
  && ok || bad "F2: dropped component with releasable commits must fail ($(cat "$split3/results.tsv"))"
grep -q "NO notes section" "$split3/report.txt" && ok || bad "F2: report names the dropped release"
[ "$(awk -F'\t' '$1=="spark-connect"{print $2}' "$split3/results.tsv")" = "yes" ] \
  || [ "$(awk -F'\t' '$1=="spark-connect"{print $2"|"$3}' "$split3/results.tsv")" != "" ] \
  && ok || bad "F2: other components still recorded"

# F5: conventional-commits footer variants Release Please's parser treats as
# breaking must be detected — the " #" separator (spec §8) and an indented
# footer (RP parser tolerance).
gitc commit -q --allow-empty -m 'fix: sep form' -m 'BREAKING CHANGE #77 removed the knob'
sha_sep="$(gitc rev-parse HEAD)"
[ "$(cd "$fixture" && notes_body_breaking "$sha_sep")" = "breaking" ] \
  && ok || bad "F5: 'BREAKING CHANGE #77' footer must be detected"
gitc commit -q --allow-empty -m 'fix: indented form' -m '  BREAKING-CHANGE: moved the config'
sha_ind="$(gitc rev-parse HEAD)"
[ "$(cd "$fixture" && notes_body_breaking "$sha_ind")" = "breaking" ] \
  && ok || bad "F5: indented BREAKING-CHANGE footer must be detected"

# #710: governance trailers are metadata, never release-note content. They ride
# in the commit BODY (the subject parser only ever sees SUBJECT lines), they are
# not a rendered conventional type, and they are not a BREAKING footer — so the
# changelog generator and the completeness guard both ignore them. Proven here
# deterministically rather than trusted.
gov_type="$(notes_parse_subject 'Spark-Governed-By: v0.23.0' | cut -f1)"
case "$gov_type" in
  feat|fix|docs|chore|refactor|test) bad "#710: a Spark-Governed-By trailer must not be a rendered release-note type (got '$gov_type')" ;;
  *) ok ;;
esac
gitc commit -q --allow-empty -m 'feat: governed change' -m 'why it matters' \
  -m 'Spark-Governed-By: v0.23.0'
sha_gov="$(gitc rev-parse HEAD)"
[ -z "$(cd "$fixture" && notes_body_breaking "$sha_gov")" ] \
  && ok || bad "#710: a governance-trailer body must not be read as a BREAKING footer"

# F7: a hostile tab inside a verbatim commit subject must not inject TSV
# columns (labels/breaking field shift).
date +%s%N > "$fixture/core.txt"
( cd "$fixture" && git add -A && git -c user.name=t -c user.email=t@t commit -q --cleanup=verbatim -m "$(printf 'feat: tab\there feature (#9)')" )
sha_tab="$(gitc rev-parse HEAD)"
tsv_line="$(cd "$fixture" && notes_component_commits_tsv "jwogrady/spark" "core" "${sha_tab}~1..${sha_tab}")"
[ "$(printf '%s' "$tsv_line" | awk -F'\t' '{print NF}')" = "4" ] \
  && ok || bad "F7: tab-in-subject must yield exactly 4 TSV columns (got: $tsv_line)"

finish
