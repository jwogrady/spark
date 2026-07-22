#!/usr/bin/env bash
# Release-notes completeness check (#232). Pure decision logic: given the
# commits in a pending release range and the release notes Release Please
# generated for that range, it flags two silent-omission failure modes and
# nothing else. It is a VERIFICATION surface — it reads text, never mutates a
# changelog, a tag, or a release (Release Please owns those; ADR-0006/0009).
#
# It is deliberately I/O-free so the whole thing is offline-testable: both
# inputs are files. A caller assembles them at release time — the commits from
# `git log <lasttag>..HEAD` joined with each commit's PR labels, the notes from
# the Release Please PR body — and runs this against them before a human
# approves the PR (see docs/reference/release-docs-checklist.md).
#
# Two failure modes, both drawn from #232 (v0.10.1 shipped a feature and several
# governance changes that never reached the generated notes):
#
#   1. omission  — a changelog-visible commit (feat/fix/perf/revert) whose
#                  subject text does not appear anywhere in the notes.
#   2. mislabel  — a commit merged under a changelog-EXCLUDED type (chore, docs,
#                  refactor, test, style, build, ci) whose PR carried the
#                  user-facing `feature` category label. The user-facing change
#                  is real but hidden from the changelog by its commit type —
#                  exactly how #226's feature vanished behind `chore:`.
#
# Exit 0 when the notes are complete; 1 when any omission/mislabel is found
# (each printed); 2 on a usage error.
set -euo pipefail

# Changelog-visible conventional types under Release Please's "simple" default
# (see docs/explanation/release-ownership.md). Keep this list and that doc in
# lockstep — they are the one definition of "user-facing in the changelog".
VISIBLE_TYPES="feat fix perf revert"

usage() {
  echo "usage: release-notes-check.sh --commits <file> --notes <file>" >&2
  echo "  --commits  TSV, one commit per line: type<TAB>subject<TAB>labels" >&2
  echo "             (labels: comma-separated PR labels, may be empty)" >&2
  echo "  --notes    the generated release-notes text to check against" >&2
  exit 2
}

commits="" notes=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --commits) shift; commits="${1:-}" ;;
    --notes) shift; notes="${1:-}" ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
  shift || true
done
[ -n "$commits" ] && [ -n "$notes" ] || usage
[ -f "$commits" ] || { echo "no such commits file: $commits" >&2; exit 2; }
[ -f "$notes" ] || { echo "no such notes file: $notes" >&2; exit 2; }

is_visible() { # is_visible <type>
  case " $VISIBLE_TYPES " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

has_feature_label() { # has_feature_label <comma-separated-labels>
  case ",$1," in *,feature,*) return 0 ;; *) return 1 ;; esac
}

# Case-insensitive substring test: is the commit subject present in the notes?
# Release Please writes the bare subject (type prefix stripped) as the changelog
# line, so a substring match on the subject is the honest "did it survive".
notes_lc="$(tr '[:upper:]' '[:lower:]' < "$notes")"
subject_in_notes() { # subject_in_notes <subject>
  local needle; needle="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$notes_lc" in *"$needle"*) return 0 ;; *) return 1 ;; esac
}

findings=0
while IFS=$'\t' read -r type subject labels || [ -n "$type" ]; do
  # Skip blank lines and comments so fixtures can annotate themselves.
  [ -n "${type:-}" ] || continue
  case "$type" in \#*) continue ;; esac
  labels="${labels:-}"

  if is_visible "$type"; then
    if ! subject_in_notes "$subject"; then
      echo "omission: ${type}: ${subject} — visible in the changelog but absent from the notes"
      findings=$((findings + 1))
    fi
  elif has_feature_label "$labels"; then
    echo "mislabel: ${subject} — merged as '${type}:' but its PR is labeled 'feature'; the user-facing change is hidden from the changelog"
    findings=$((findings + 1))
  fi
done < "$commits"

if [ "$findings" -eq 0 ]; then
  echo "release-notes: complete — every visible commit is represented and no feature is hidden behind an excluded type"
  exit 0
fi
echo "release-notes: ${findings} omission/mislabel finding(s) — reconcile before approving the release PR" >&2
exit 1
