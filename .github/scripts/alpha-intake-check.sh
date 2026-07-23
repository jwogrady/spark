#!/usr/bin/env bash
# Alpha intake canonical-route guard (#322). One privacy-safe public intake —
# the `alpha-feedback` GitHub issue form — and no participant-facing Alpha doc
# may route around it. Pure and offline: scans a docs dir + the form file and
# fails loudly on any non-canonical route or lost privacy control.
#
#   alpha-intake-check.sh <alpha-docs-dir> <issue-form.yml>
#
# Exit 0 clean, 1 on any violation (each printed), 2 on usage/missing inputs.
set -euo pipefail

docs="${1:-}" form="${2:-}"
[ -n "$docs" ] && [ -n "$form" ] || { echo "usage: alpha-intake-check.sh <alpha-docs-dir> <issue-form.yml>" >&2; exit 2; }
[ -d "$docs" ] || { echo "no such docs dir: $docs" >&2; exit 2; }

violations=0
flag() { echo "  ✗ $1"; violations=$((violations + 1)); }

# --- (1) the canonical form must exist and keep its privacy controls ---------
if [ ! -f "$form" ]; then
  flag "canonical intake form missing: $form"
else
  # Structural, not keyword-count: a repository-wide `required: true` count is
  # bypassable — the form carries 13+ required fields that have nothing to do
  # with privacy, so all four attestations could go optional while a global
  # count stayed green (#332). Instead, isolate the `id: privacy` checkbox
  # block (its lines up to the next `- type:` element) and demand that each of
  # the four attestations exists there AND carries its own `required: true` on
  # the line that follows its label.
  privacy_opts="$(awk '
    /^[[:space:]]*id:[[:space:]]*privacy[[:space:]]*$/ { inblk=1; next }
    inblk && /^[[:space:]]*-[[:space:]]*type:/ { inblk=0 }
    inblk' "$form" 2>/dev/null || true)"
  if [ -z "$privacy_opts" ]; then
    flag "form lost the 'id: privacy' checkbox block entirely"
  else
    check_attestation() { # <label-pattern> <human-name>
      local opt
      opt="$(printf '%s\n' "$privacy_opts" | grep -iE -A1 -- "-[[:space:]]*label:.*($1)" || true)"
      if [ -z "$opt" ]; then
        flag "form lost the '$2' attestation from the privacy block"
      elif ! printf '%s\n' "$opt" | grep -q 'required: true'; then
        flag "privacy attestation '$2' is present but no longer required"
      fi
    }
    check_attestation 'no secrets'                        "no secrets/credentials"
    check_attestation 'proprietary'                       "no proprietary/customer source"
    check_attestation 'customer data|personal information' "no customer data / PII"
    check_attestation 'recording'                         "no sensitive recordings"
  fi
  grep -qiE 'pseudonym|P3|assigned' "$form" || flag "form lost the pseudonym-only identity instruction"
  grep -qi 'alpha-feedback' "$form"        || flag "form lost its alpha-feedback label"
fi

# --- (2) no participant-facing doc may route around the form -----------------
# Forbidden anti-patterns, each the exact hazard #322 named.
# scan_strict: always a violation. scan_directive: only when it is an actual
# instruction, not a warning — a line saying "do NOT copy into an issue" is safe
# guidance, so negated lines are skipped.
scan_strict() { # <pattern> <message>
  local hits; hits="$(grep -rniE "$1" "$docs" 2>/dev/null || true)"
  [ -z "$hits" ] || while IFS= read -r l; do flag "$2 -> $l"; done <<< "$hits"
}
scan_directive() { # <pattern> <message>
  local hits; hits="$(grep -rniE "$1" "$docs" 2>/dev/null | grep -viE "do not|don't|never|must not|not to" || true)"
  [ -z "$hits" ] || while IFS= read -r l; do flag "$2 -> $l"; done <<< "$hits"
}
scan_directive 'copy (this|it) into'                 "instructs copying a template into an issue"
scan_directive 'copy [^)]*into (a|an|the)[^)]*issue' "instructs copying content into an issue"
scan_directive '(file|submit)[^`]*feedback-template' "routes submission through the markdown template, not the form"
scan_directive 'feedback-template[^)]*\) (entry|report) per' "treats the markdown template as the submission unit"
scan_strict 'Participant \(handle\)'                 "uses the ambiguous 'Participant (handle)' identity prompt"
scan_strict 'wherever the [a-z ]*coordinator directs' "routes intake to a non-canonical destination"

# --- (3) where a doc DESCRIBES intake, it must name the pseudonym rule --------
# Any participant-facing doc that mentions filing to the alpha-feedback form
# must also carry the pseudonym-only instruction (privacy floor).
for f in "$docs"/testing-guide.md "$docs"/feedback-template.md; do
  [ -f "$f" ] || continue
  if grep -qiE 'alpha-feedback|issue form|New Issue' "$f"; then
    grep -qiE 'pseudonym|\bP1\b' "$f" || flag "describes intake but omits the pseudonym-only instruction: $f"
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "alpha-intake: $violations violation(s) — one canonical, privacy-safe intake (the alpha-feedback form) is required (#322)" >&2
  exit 1
fi
echo "alpha-intake: canonical, privacy-safe intake enforced across participant-facing Alpha docs"
exit 0
