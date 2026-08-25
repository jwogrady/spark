#!/usr/bin/env bash
# Naming guard (issue #394): the organization name is written `Status26` — one
# word, capital S, no space, no hyphen. The spaced form is what gets inferred
# from the status26.com domain at the moment someone has to name a copyright
# holder, so this is the mechanical check that keeps the inference from
# landing in the repo.
#
# Genuine identifiers are not variants and must not be flagged: status26.com,
# email addresses, and anything legitimately lowercase by spec.
#
# The offending patterns are assembled from fragments rather than written
# literally, so this file can scan the whole repository without matching
# itself.

set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"

# Space- and punctuation-separated variants: "Status 26", "status-26", etc.
sep_pattern="[Ss][Tt][Aa][Tt][Uu][Ss][ _-]+26"

hits="$(grep -rInE "$sep_pattern" "$root" \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.claude \
  --exclude="$(basename "$0")" 2>/dev/null || true)"

if [ -z "$hits" ]; then
  ok
else
  printf '%s\n' "$hits" | while IFS= read -r line; do
    [ -n "$line" ] && echo "    $line"
  done
  bad "#394: a separated variant of the organization name is present (canonical: one word, capital S)"
fi

# The canonical form itself must survive the sweep — a guard that passes
# because the name is absent everywhere is not a guard.
if grep -rIlE 'Status26' "$root" \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.claude \
  --exclude="$(basename "$0")" >/dev/null 2>&1; then
  ok
else
  bad "#394: the canonical form is not present anywhere — the guard is vacuous"
fi

# The contract states the decision, so it cannot be re-litigated from memory.
if grep -q 'Status26' "$root/AGENTS.md"; then
  ok
else
  bad "#394: AGENTS.md does not record the canonical organization name"
fi

# And the org name must stay out of every shipped plugin: Spark ships a
# reusable discipline, not Status26 architecture.
if grep -rniE 'status[ _-]?26' "$root"/plugins/*/ >/dev/null 2>&1; then
  bad "#394: a shipped plugin names the organization — plugins must stay org-neutral"
else
  ok
fi

finish
