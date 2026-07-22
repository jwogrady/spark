#!/usr/bin/env bash
# Release-notes completeness check (#232, #291). Pure decision logic: given the
# commits in one pending release component's range and the release notes
# Release Please generated for THAT component, it flags the silent-omission
# failure modes and nothing else. It is a VERIFICATION surface — it reads text,
# never mutates a changelog, a tag, or a release (Release Please owns those;
# ADR-0006/0009).
#
# It is deliberately I/O-free so the whole thing is offline-testable: both
# inputs are files. A caller assembles them per component at release time — the
# commits from `git log <component-last-tag>.. -- <component-paths>` joined
# with each commit's PR labels and breaking markers, the notes from that
# component's own section of the Release Please PR body — and runs this before
# a human approves the PR (release-notes-runner.sh automates it per component;
# see docs/reference/release-docs-checklist.md).
#
# Three failure modes, drawn from #232 (v0.10.1 shipped a feature and several
# governance changes that never reached the generated notes) and #291:
#
#   1. omission  — a changelog-visible commit (feat/fix/docs) whose subject
#                  text does not appear anywhere in the notes.
#   2. breaking  — a commit marked breaking (`!` on the conventional type, or
#                  a `BREAKING CHANGE:` footer the caller represents in the
#                  breaking column) is changelog-visible REGARDLESS of type;
#                  its subject absent from the notes is an omission even when
#                  the bare type is normally hidden (chore!/refactor!).
#   3. mislabel  — a non-breaking commit merged under a changelog-EXCLUDED
#                  type (chore, refactor, test, …) whose PR carried the
#                  user-facing `feature` category label. The user-facing
#                  change is real but hidden from the changelog by its commit
#                  type — exactly how #226's feature vanished behind `chore:`.
#
# Exit 0 when no finding is present; 1 when any finding is found (each
# printed); 2 on a usage error. The success message states only what actually
# ran (#297): the subject-omission half always runs; the breaking half is
# claimed only when a breaking commit was present in the range; the
# hidden-feature (mislabel) half only when the caller supplied labels.
set -euo pipefail

# Changelog-visible conventional types, matching the changelog-sections in
# release-please-config.json (see docs/explanation/release-ownership.md). Spark's
# committed vocabulary is six types (feat fix docs chore refactor test); of those
# feat/fix/docs are visible (docs is part of the product) and chore/refactor/test
# are hidden as build-process noise. Keep this list, the config, and that doc in
# lockstep — doctor enforces it (#270).
VISIBLE_TYPES="feat fix docs"

usage() {
  echo "usage: release-notes-check.sh --commits <file> --notes <file> [--component <name>]" >&2
  echo "  --commits    TSV, one commit per line: type<TAB>subject<TAB>labels<TAB>breaking" >&2
  echo "               labels: comma-separated PR labels, may be empty" >&2
  echo "               breaking: any non-empty value marks a breaking change (the" >&2
  echo "               caller's representation of a BREAKING CHANGE footer); a" >&2
  echo "               trailing '!' on the type column (feat!, chore!) marks it too" >&2
  echo "  --notes      the generated release-notes text to check against" >&2
  echo "  --component  component name used in messages (default: core)" >&2
  exit 2
}

commits="" notes="" component="core"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --commits) shift; commits="${1:-}" ;;
    --notes) shift; notes="${1:-}" ;;
    --component) shift; component="${1:-}" ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
  shift || true
done
[ -n "$commits" ] && [ -n "$notes" ] && [ -n "$component" ] || usage
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
  case "$notes_lc" in *"$needle"*) return 0 ;; esac
  # A squash-merge subject often ends in " (#NNN)", which Release Please
  # linkifies to "([#NNN](url))" in the notes — so the literal subject won't
  # substring-match. Retry with that trailing PR reference stripped.
  needle="$(printf '%s' "$needle" | sed -E 's/ *\(#[0-9]+\)$//')"
  case "$notes_lc" in *"$needle"*) return 0 ;; *) return 1 ;; esac
}

findings=0 labels_available=0 breaking_seen=0
# `read` treats a tab IFS as whitespace and collapses runs of tabs, which
# would eat an EMPTY middle column — an empty labels field would swallow the
# breaking flag into `labels`. Translate tabs to the unit separator, a hard
# (non-whitespace) delimiter that preserves empty fields.
while IFS=$'\037' read -r type subject labels breaking || [ -n "$type" ]; do
  # Skip blank lines and comments so fixtures can annotate themselves.
  [ -n "${type:-}" ] || continue
  case "$type" in \#*) continue ;; esac
  labels="${labels:-}" breaking="${breaking:-}"
  # A `!` on the type is the in-subject breaking marker (conventional
  # commits); normalize it into the breaking flag so both spellings verify
  # the same property.
  case "$type" in *!) breaking="breaking"; type="${type%!}" ;; esac
  # Track whether the mislabel half had any evidence to work with. When the
  # caller supplies no labels, the hidden-feature check is vacuous for that
  # commit, and the success message must not claim it (#297).
  [ -n "$labels" ] && labels_available=1

  if [ -n "$breaking" ]; then
    # Release Please promotes breaking changes into the notes even when the
    # type itself is hidden, so the subject must survive regardless of type.
    breaking_seen=1
    if ! subject_in_notes "$subject"; then
      echo "omission: ${type}!: ${subject} — breaking change (changelog-visible regardless of type) but absent from the notes"
      findings=$((findings + 1))
    fi
  elif is_visible "$type"; then
    if ! subject_in_notes "$subject"; then
      echo "omission: ${type}: ${subject} — visible in the changelog but absent from the notes"
      findings=$((findings + 1))
    fi
  elif has_feature_label "$labels"; then
    echo "mislabel: ${subject} — merged as '${type}:' but its PR is labeled 'feature'; the user-facing change is hidden from the changelog"
    findings=$((findings + 1))
  fi
done < <(tr '\t' '\037' < "$commits")

if [ "$findings" -eq 0 ]; then
  # State only what the evidence supports (#297). The omission half always ran;
  # the breaking half only had evidence if a breaking commit was in the range;
  # the hidden-feature (mislabel) half only ran if labels were supplied. Never
  # claim another component's completeness — this check sees ONE component's
  # commit range and ONE component's notes (#291).
  msg="release-notes: ${component} subject-omission check passed — every changelog-visible commit's subject appears in the notes"
  if [ "$breaking_seen" -eq 1 ]; then
    msg="$msg; every breaking change appears in the notes"
  fi
  if [ "$labels_available" -eq 1 ]; then
    msg="$msg; no labeled commit is hidden behind an excluded type"
  fi
  echo "$msg"
  exit 0
fi
echo "release-notes: ${findings} omission/mislabel finding(s) in ${component} — reconcile before approving the release PR" >&2
exit 1
