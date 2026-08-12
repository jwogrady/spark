#!/usr/bin/env bash
# CI glue for the release-notes completeness guard (#261, #232, #291). Finds
# the open Release Please PR, splits its combined manifest body into
# per-component notes (core plus the spark-audit / spark-connect / spark-docs
# companions), builds each component's commit list from its OWN previous tag
# and its OWN path scope, joins in each commit's authoritative PR labels and
# breaking markers, and asks release-notes-check.sh — once per component —
# whether anything changelog-visible went missing. Posts one advisory
# `release-notes` commit status and one summary comment carrying a
# per-component evidence table. Mirrors gate-runner.sh and
# retired platform-compat-runner.sh; like it, this reads and writes only a status + a
# comment — never merges, tags, or releases.
#
# Advisory by design: the status is not a required check; the human merge is
# the release act. But the status is honest (#280): `failure` when any
# component check found a real finding, `error` (and a failed step) when a
# check could not run correctly, `success` only when everything that was
# assessed came back clean.
#
# The pure helpers below are factored out so the body parsing, subject
# parsing, per-component commit collection, and verdict aggregation are
# offline-testable (tests/test-release-notes-runner.sh); main runs only when
# the script is executed, not sourced.

# The components one combined Release Please manifest PR can release
# (release-please-config.json). Core has include-component-in-tag:false, so
# its tags are bare vX.Y.Z and its notes <summary> is the bare version; each
# companion tags <name>-vX.Y.Z and titles its notes section "<name>: X.Y.Z".
NOTES_COMPONENTS="core spark-audit spark-connect spark-docs"

# Map one <details><summary>…</summary> title from the manifest PR body to a
# component. Companions render "name: X.Y.Z"; core (no component name)
# renders the bare version, with or without a leading v. Anything else maps
# to no known component and its block is ignored.
notes_component_for_summary() { # <summary text> -> component name, or empty
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"
  case "$s" in
    spark-audit:*)   echo "spark-audit" ;;
    spark-connect:*) echo "spark-connect" ;;
    spark-docs:*)    echo "spark-docs" ;;
    v[0-9]*|[0-9]*)  echo "core" ;;
    *) : ;;
  esac
}

# Split a Release Please PR body into one notes file per component under
# <outdir> (core.md, spark-audit.md, …). Only <details> blocks whose summary
# maps to a known component are kept, and each component's text lands in its
# OWN file — matching text in another component's section must never satisfy
# a commit (#291 AC-5). A body with no <details> blocks at all is the
# single-release shape (only core changed), so the whole body becomes
# core.md. A component with no block gets NO file — the caller reports it
# not-assessed rather than inventing a pass.
notes_split_body() { # <body-file> <outdir>
  local body="$1" outdir="$2" comp="" summary="" saw_details=0 line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'<summary>'*'</summary>'*)
        saw_details=1
        summary="${line#*<summary>}"; summary="${summary%%</summary>*}"
        comp="$(notes_component_for_summary "$summary")"
        [ -z "$comp" ] || : > "$outdir/$comp.md"
        continue ;;
      *'</details>'*) comp=""; continue ;;
    esac
    [ -z "$comp" ] || printf '%s\n' "$line" >> "$outdir/$comp.md"
  done < "$body"
  [ "$saw_details" -eq 1 ] || cp "$body" "$outdir/core.md"
}

# Parse a conventional commit subject into "type<TAB>rest<TAB>breaking".
# The `!` breaking marker is stripped BEFORE the scope so `feat(cli)!:` keeps
# its marker (stripping the scope first would eat the `!`). Non-conventional
# subjects yield no output — they are invisible to Release Please too.
notes_parse_subject() { # <subject> -> one TSV line, or nothing
  local subj="$1" head type rest breaking=""
  case "$subj" in *': '*) ;; *) return 0 ;; esac
  head="${subj%%: *}"
  rest="${subj#*: }"
  case "$head" in *!) breaking="breaking"; head="${head%!}" ;; esac
  type="${head%%(*}"
  [ -n "$type" ] || return 0
  printf '%s\t%s\t%s\n' "$type" "$rest" "$breaking"
}

# A component's git path scope. Core is the whole repo minus the companion
# directories; each companion is exactly its plugin directory. A commit that
# touches both core and a companion appears in BOTH components on purpose:
# each release carries its own changelog line for it, so each must be
# verified against its own notes.
notes_component_paths() { # <component> -> one pathspec per line
  case "$1" in
    core)
      printf '%s\n' '.' \
        ':(exclude)plugins/spark-audit' \
        ':(exclude)plugins/spark-connect' \
        ':(exclude)plugins/spark-docs' ;;
    *) printf 'plugins/%s\n' "$1" ;;
  esac
}

# A component's previous release tag: the highest bare vX.Y.Z for core (never
# a companion tag), the highest <name>-vX.Y.Z for a companion. Empty when the
# component has never been released — the range then starts from the root.
notes_last_tag() { # <component> -> tag name, or empty
  case "$1" in
    core) git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -n1 ;;
    *)    git tag --list "$1-v[0-9]*" --sort=-v:refname 2>/dev/null | head -n1 ;;
  esac
}

# Authoritative labels for the PR(s) that merged a commit, comma-joined. Empty
# when the commit genuinely has no PR/labels; the SENTINEL __labels_unavailable__
# when the gh call FAILS — hostile review proved the two must be
# distinguishable, or a transient API outage on exactly the mislabeled commit
# silently disappears the hidden-type check while the pass message still claims
# it ran. The guard keeps a failed gh call from aborting under pipefail (#310);
# the sentinel keeps the failure honest.
notes_pr_labels() { # <repo> <sha> -> "label1,label2", empty, or the sentinel
  gh api "repos/$1/commits/$2/pulls" \
    --jq '[.[].labels[].name] | unique | join(",")' 2>/dev/null \
    || printf '__labels_unavailable__'
}

# Does a commit's body declare a breaking change? Per conventional commits, a
# BREAKING CHANGE / BREAKING-CHANGE footer makes the commit changelog-visible
# regardless of its type. grep exits 1 on no match — the `|| true` keeps that
# legitimate empty answer from aborting under pipefail (#310).
notes_body_breaking() { # <sha> -> "breaking" or empty
  # Footer separator per conventional commits is ": " OR " #" (spec §8/§12), and
  # Release Please's parser additionally tolerates leading whitespace — match
  # what THAT parser treats as breaking, or we under-detect what RP will render.
  git log -1 --format='%b' "$1" 2>/dev/null \
    | grep -qE '^[[:space:]]*BREAKING[ -]CHANGE(:| #)' && echo "breaking" || true
}

# Build one component's commits TSV (type, subject, labels, breaking) for the
# check: every non-merge conventional commit in the component's tag range that
# touches the component's paths. Label lookup is one gh call per commit —
# release ranges are small, and per-commit PR labels are the only
# authoritative source for the hidden-type feature check (#291 AC-1).
notes_component_commits_tsv() { # <repo> <component> <range> -> TSV; rc 1 = range failed
  local repo="$1" comp="$2" range="$3" p sha subj parsed type rest breaking labels shas
  local paths=()
  while IFS= read -r p; do paths+=("$p"); done < <(notes_component_paths "$comp")
  # Capture git's exit status: a bad/deleted tag or unfetched ref must surface
  # as an INFRA FAILURE, not an empty file — hostile review proved an empty TSV
  # is byte-identical to a legitimately empty range and folded to a clean pass.
  shas="$(git log --no-merges --format='%H' "$range" -- "${paths[@]}" 2>/dev/null)" || return 1
  [ -n "$shas" ] || return 0
  while IFS= read -r sha; do
    # Sanitize: a hostile tab in a verbatim commit subject would inject TSV
    # columns (shifting the labels/breaking fields).
    subj="$(git log -1 --format='%s' "$sha" | tr '\t' ' ')" || return 1
    parsed="$(notes_parse_subject "$subj")"
    [ -n "$parsed" ] || continue
    IFS=$'\t' read -r type rest breaking <<< "$parsed"
    [ -n "$breaking" ] || breaking="$(notes_body_breaking "$sha")"
    labels="$(notes_pr_labels "$repo" "$sha")"
    printf '%s\t%s\t%s\t%s\n' "$type" "$rest" "$labels" "$breaking"
  done <<< "$shas"
}

# Run the check for every component and record the evidence. Reads the
# per-component notes files notes_split_body left in <workdir>; writes
# <workdir>/results.tsv (component, assessed yes/no, check exit code, one-line
# detail) and <workdir>/report.txt (full per-component check output). It never
# talks to GitHub itself — main owns the status/comment I/O — so the whole
# verdict pipeline runs offline in the tests.
notes_run_components() { # <repo> <head-sha> <workdir>
  local repo="$1" head_sha="$2" work="$3" here comp notes_file last_tag range rc out detail
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  : > "$work/results.tsv"
  : > "$work/report.txt"
  for comp in $NOTES_COMPONENTS; do
    notes_file="$work/$comp.md"
    last_tag="$(notes_last_tag "$comp")"
    range="${last_tag:+$last_tag..}$head_sha"
    if ! notes_component_commits_tsv "$repo" "$comp" "$range" > "$work/$comp.tsv"; then
      # Range resolution failed (deleted/unfetched tag, bad ref). An empty TSV
      # is byte-identical to "nothing to release", so a git failure must be an
      # ERROR the fold refuses — never a clean pass (hostile-review F1).
      printf '%s\tyes\t2\t%s\n' "$comp" "git range resolution failed ($range) — component not verifiable" >> "$work/results.tsv"
      printf '== %s (%s) ==\nERROR: git range resolution failed; nothing was verified\n\n' "$comp" "$range" >> "$work/report.txt"
      continue
    fi
    if [ ! -f "$notes_file" ]; then
      # No notes section for this component. Benign ONLY if the range also has
      # no releasable commits; a component WITH releasable commits but no
      # section is precisely the dropped-release failure this guard exists for
      # (hostile-review F2) — run the check against empty notes so the check
      # itself (the visibility authority) decides.
      if [ -s "$work/$comp.tsv" ] && \
         ! out="$(bash "$here/release-notes-check.sh" --component "$comp" \
             --commits "$work/$comp.tsv" --notes /dev/null 2>&1)"; then
        detail="component has releasable commit(s) but NO notes section in the release PR body"
        printf '%s\tyes\t1\t%s\n' "$comp" "$detail" >> "$work/results.tsv"
        printf '== %s (%s) ==\n%s\n%s\n\n' "$comp" "$range" "$detail:" "$out" >> "$work/report.txt"
      else
        printf '%s\tno\t-\t%s\n' "$comp" "no notes section and no releasable commits" >> "$work/results.tsv"
        printf '== %s ==\nnot assessed — no notes section for this component and no releasable commits in %s; nothing to verify\n\n' "$comp" "$range" >> "$work/report.txt"
      fi
      continue
    fi
    rc=0
    out="$(bash "$here/release-notes-check.sh" --component "$comp" \
      --commits "$work/$comp.tsv" --notes "$notes_file" 2>&1)" || rc=$?
    # The detail lands in a TSV row and a markdown table cell: flatten tabs
    # and pipes so it cannot break either container.
    detail="$(printf '%s\n' "$out" | tail -n1 | tr '\t|' ' /' | head -c 200)"
    printf '%s\tyes\t%s\t%s\n' "$comp" "$rc" "$detail" >> "$work/results.tsv"
    printf '== %s (%s) ==\n%s\n\n' "$comp" "$range" "$out" >> "$work/report.txt"
  done
}

# Fold the per-component exit codes into the one advisory commit-status state,
# honesty rule: real findings → failure, any
# check that could not run correctly (exit 2 or unexpected) → error (and main
# fails the step), otherwise success. A not-assessed component is honest —
# never an error, never a pass.
notes_status_for_results() { # results.tsv on stdin -> success|failure|error
  awk -F'\t' '
    $2 == "yes" && $3 == 1 { found = 1 }
    $2 == "yes" && $3 != 0 && $3 != 1 { err = 1 }
    END { print err ? "error" : found ? "failure" : "success" }'
}

# Render the per-component evidence table for the advisory comment (#291 AC-4).
notes_render_table() { # results.tsv on stdin -> markdown table
  echo '| component | assessed | result | detail |'
  echo '| --- | --- | --- | --- |'
  awk -F'\t' '{
    result = "error"
    if ($2 != "yes")  { result = "—" }
    else if ($3 == 0) { result = "pass" }
    else if ($3 == 1) { result = "fail" }
    printf "| %s | %s | %s | %s |\n", $1, ($2 == "yes" ? "assessed" : "not-assessed"), result, $4
  }'
}

# One short line for the commit-status description (GitHub truncates at 140).
notes_status_desc() { # results.tsv on stdin -> "core: pass; spark-audit: …"
  awk -F'\t' '{
    r = "error"
    if ($2 != "yes")  { r = "not-assessed" }
    else if ($3 == 0) { r = "pass" }
    else if ($3 == 1) { r = "fail" }
    printf "%s%s: %s", (NR > 1 ? "; " : ""), $1, r
  }
  END { printf "\n" }'
}

main() {
  set -euo pipefail
  local repo release_branch pr pr_number head_sha work
  local state table desc report marker existing comment

  repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
  release_branch="release-please--branches--master"

  pr="$(gh pr list --repo "$repo" --head "$release_branch" --state open \
        --json number,headRefOid,body --jq '.[0] // empty')"
  if [ -z "$pr" ]; then
    echo "no open Release Please PR; nothing to check"
    return 0
  fi
  pr_number="$(printf '%s' "$pr" | jq -r '.number')"
  head_sha="$(printf '%s' "$pr" | jq -r '.headRefOid')"

  # milestone-gate runs on many events, so the local checkout may be any ref
  # (#280); fetch and pin the PR head SHA rather than trusting HEAD.
  git fetch --quiet --tags origin "$head_sha" 2>/dev/null || true
  if ! git cat-file -e "$head_sha" 2>/dev/null; then
    # An unresolvable head is an INFRA failure: exiting green here would leave
    # any previous (possibly stale-success) release-notes status standing as if
    # current. Post an error status and fail the step (hostile-review F9).
    gh api -X POST "repos/$repo/statuses/$head_sha" \
      -f state="error" -f context="release-notes" \
      -f description="could not resolve the release PR head locally — notes not verified" >/dev/null 2>&1 || true
    echo "could not resolve the release PR head ($head_sha); release notes NOT verified" >&2
    return 1
  fi

  work="$(mktemp -d)"
  # The trap fires at process EXIT — after main has returned and its locals are
  # gone — so it must expand with a default or set -u kills an otherwise
  # successful run at the finish line (found live in CI; regression-tested).
  RELEASE_NOTES_WORK="$work"
  trap 'rm -rf "${RELEASE_NOTES_WORK:-}"' EXIT
  # GitHub bodies arrive CRLF; strip the CR so line-based parsing sees clean lines.
  printf '%s' "$pr" | jq -r '.body' | tr -d '\r' > "$work/body.md"

  notes_split_body "$work/body.md" "$work"
  notes_run_components "$repo" "$head_sha" "$work"

  state="$(notes_status_for_results < "$work/results.tsv")"
  table="$(notes_render_table < "$work/results.tsv")"
  desc="$(notes_status_desc < "$work/results.tsv" | head -c 130)"
  report="$(cat "$work/report.txt")"

  gh api -X POST "repos/$repo/statuses/$head_sha" \
    -f state="$state" -f context="release-notes" -f description="$desc" >/dev/null

  marker="<!-- release-notes-check -->"
  existing="$(gh api "repos/$repo/issues/$pr_number/comments" \
    --jq ".[] | select(.body|startswith(\"$marker\")) | .id" 2>/dev/null | head -n1)"
  comment="$(printf '%s\n**Release-notes: per-component completeness check (advisory)**\n\n%s\n\n```\n%s\n```\n\nScope: each component the combined Release Please PR releases (core `vX.Y.Z`; companions `spark-audit`/`spark-connect`/`spark-docs`) is verified against its OWN previous tag, its OWN path-scoped commits, and its OWN notes section — matching text in another component never satisfies a commit. Verified per component: subject omissions, duplicate bullets (one logical change rendered twice — checked against the notes alone, independent of the commit range), breaking-change visibility (`!` types and `BREAKING CHANGE` footers), and — where per-commit PR labels were retrievable — hidden-type features (a `feature`-labeled PR merged under an excluded type). A component with no notes section is reported not-assessed, never passed. Advisory: the human merge is the release act.\n' \
    "$marker" "$table" "$report")"
  if [ -n "$existing" ]; then
    gh api -X PATCH "repos/$repo/issues/comments/$existing" -f body="$comment" >/dev/null
  else
    gh api -X POST "repos/$repo/issues/$pr_number/comments" -f body="$comment" >/dev/null
  fi

  # Fail the step honestly when a component check could not run correctly
  # (state=error); never leave a misleading green advisory behind a broken check.
  if [ "$state" = "error" ]; then
    echo "release-notes: a component check errored; status posted as 'error'" >&2
    return 1
  fi
  echo "release-notes advisory posted for PR #$pr_number ($state)"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
