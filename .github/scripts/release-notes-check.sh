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
# Four failure modes, drawn from #232 (v0.10.1 shipped a feature and several
# governance changes that never reached the generated notes), #291, and #372
# (v0.16.0/v0.16.1 each listed one logical change twice):
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
#   4. duplicate — two or more note bullets normalize to the identical text.
#                  #372's mechanism: this repo's merge commits carry the PR's
#                  conventional title as their message BODY (GitHub's
#                  merge_commit_message=PR_TITLE), so Release Please classifies
#                  both the branch commit and its own merge commit as the same
#                  logical change. The completeness checks above (1-3) cannot
#                  see this — the caller's commit list is built with
#                  `git log --no-merges` (release-notes-runner.sh), so from
#                  their view exactly one commit exists and it is satisfied by
#                  ONE of the two duplicate bullets, leaving the second
#                  invisible to an omission-only check. Detecting a duplicate
#                  is therefore a property of the NOTES alone, checked before
#                  any commit is matched against them, independent of what the
#                  caller's commit list happens to include.
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

# Bullet-anchored, consume-once subject matching. Whole-file substring matching
# was defeated by hostile review: a subject that is a PREFIX of another commit's
# note line ("add widget" vs "* add widget tests"), one short note satisfying
# two commits, and prose/URL text all false-passed. Release Please renders one
# bullet per commit whose text IS the commit subject (type stripped, scope
# bolded, refs linkified), so the honest test is: each changelog-visible commit
# must consume exactly one note BULLET whose normalized text EQUALS its
# normalized subject.
#
# notes_normalize: lowercase; drop linkified refs `([x](url))`; linkified
# `[#12](url)` -> `#12`; drop trailing `, closes …` metadata; drop bare `(#N)`
# refs (anywhere — conventional-changelog linkifies mid-subject refs too);
# strip a leading `**scope:** `; squeeze whitespace.
notes_normalize() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E \
    -e 's/\(\[[^]]*\]\([^)]*\)\)//g' \
    -e 's/\[(#[0-9]+)\]\([^)]*\)/\1/g' \
    -e 's/,? *closes .*$//' \
    -e 's/\(#[0-9]+\)//g' \
    -e 's/^\*\*[^*]+\*\* *//' \
    -e 's/[[:space:]]+/ /g' -e 's/^ //' -e 's/ $//'
}

# Collect the notes bullets (lines starting `* ` or `- `), normalized, into a
# consumable pool. Non-bullet lines (headings, prose, URLs) are never matched.
note_bullets=()
while IFS= read -r _line || [ -n "$_line" ]; do   # || catches a final line with no newline
  case "$_line" in
    [*-]\ *|" "[*-]\ *|"  "[*-]\ *)
      _b="${_line#"${_line%%[*-]*}"}"     # strip leading indent
      _b="${_b#? }"                        # strip the bullet marker + space
      note_bullets+=("$(notes_normalize "$_b")") ;;
  esac
done < "$notes"

subject_in_notes() { # subject_in_notes <subject> — consumes the matched bullet
  local needle i
  needle="$(notes_normalize "$1")"
  [ -n "$needle" ] || return 1
  for i in "${!note_bullets[@]}"; do
    if [ "${note_bullets[$i]}" = "$needle" ]; then
      note_bullets[$i]="__consumed__"
      return 0
    fi
  done
  return 1
}

findings=0 labels_available=0 breaking_seen=0 labels_unassessable=0

# Failure mode 4: duplicate bullets, checked against the notes alone before
# any commit is matched — a bullet seen once already is only reported once
# even if it repeats three or more times.
dup_seen=""
for _b in "${note_bullets[@]}"; do
  [ -n "$_b" ] || continue
  case " $dup_seen " in
    *" $(printf '%s' "$_b" | tr ' ' '\001') "*) continue ;;
  esac
  _n=0
  for _c in "${note_bullets[@]}"; do [ "$_c" = "$_b" ] && _n=$((_n + 1)); done
  if [ "$_n" -gt 1 ]; then
    echo "duplicate: ${_b} — appears ${_n} times in the notes; one logical change should render one bullet"
    findings=$((findings + 1))
  fi
  dup_seen="$dup_seen $(printf '%s' "$_b" | tr ' ' '\001')"
done
# `read` treats a tab IFS as whitespace and collapses runs of tabs, which
# would eat an EMPTY middle column — an empty labels field would swallow the
# breaking flag into `labels`. Translate tabs to the unit separator, a hard
# (non-whitespace) delimiter that preserves empty fields.
while IFS=$'\037' read -r type subject labels breaking || [ -n "$type" ]; do
  # Skip blank lines and comments so fixtures can annotate themselves.
  [ -n "${type:-}" ] || continue
  case "$type" in \#*) continue ;; esac
  labels="${labels:-}" breaking="${breaking:-}"
  # The runner emits this sentinel when the label FETCH failed — distinct from
  # "the commit genuinely has no labels". The mislabel half is unassessable for
  # this commit and the verdict must say so, never claim it ran (hostile F4).
  if [ "$labels" = "__labels_unavailable__" ]; then
    labels=""; labels_unassessable=$((labels_unassessable + 1))
  fi
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
  msg="release-notes: ${component} subject-omission check passed — every changelog-visible commit's subject appears in the notes exactly once"
  if [ "$breaking_seen" -eq 1 ]; then
    msg="$msg; every breaking change appears in the notes"
  fi
  if [ "$labels_available" -eq 1 ] && [ "$labels_unassessable" -eq 0 ]; then
    msg="$msg; no labeled commit is hidden behind an excluded type"
  fi
  if [ "$labels_unassessable" -gt 0 ]; then
    msg="$msg; labels unretrievable for $labels_unassessable commit(s) — the hidden-type check did not run for them"
  fi
  echo "$msg"
  exit 0
fi
echo "release-notes: ${findings} omission/mislabel finding(s) in ${component} — reconcile before approving the release PR" >&2
exit 1
