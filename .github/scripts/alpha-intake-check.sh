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
  # exactly the four required privacy attestations (checkboxes with required:true)
  req_opts="$(grep -c 'required: true' "$form" 2>/dev/null || true)"
  [ "${req_opts:-0}" -ge 5 ] || flag "form has fewer required fields than expected (privacy checkboxes may have been weakened): $form"
  grep -qi 'no secrets' "$form"            || flag "form lost the 'no secrets/credentials' attestation"
  grep -qi 'proprietary'  "$form"          || flag "form lost the 'no proprietary/customer source' attestation"
  grep -qiE 'customer data|personal information' "$form" || flag "form lost the 'no customer data / PII' attestation"
  grep -qi 'recording'    "$form"          || flag "form lost the 'no sensitive recordings' attestation"
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
