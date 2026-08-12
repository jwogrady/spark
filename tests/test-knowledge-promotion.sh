#!/usr/bin/env bash
# Static contract guard for the knowledge skill's cross-project promotion lane
# (issue #376, ADR-0028). Skills are prose, so the load-bearing pieces of the
# promotion contract are pinned the way test-skill-descriptions.sh pins routing
# discriminators: token presence, never whole sentences, so the prose stays
# free to improve. Graded end-to-end proof (positive + negative fixtures,
# Cosmos dogfood) is #377's evidence, not this file's.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/plugins/spark/skills/knowledge"
agents="$root/plugins/spark/agents/knowledge"
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

# has <file> <desc> <ere>... — every ERE must appear (case-insensitive) in the
# file, matched against whitespace-flattened prose so hard-wrapped lines can't
# split a phrase the guard pins.
has() {
  local f="$1" desc="$2" m flat; shift 2
  [ -f "$f" ] || { bad "$desc: $(basename "$f") missing"; return; }
  flat="$(tr '\n' ' ' < "$f")"
  for m in "$@"; do
    printf '%s' "$flat" | grep -qiE -- "$m" \
      || { bad "$desc: missing /$m/ in $(basename "$f")"; return; }
  done
  ok
}

ref="$skill/references/hub-promotion.md"

# The classifier: the deletion test with its three outcomes, stated as ADR-0028's.
has "$ref" "classification test" \
  'still be useful and true' 'disappeared' 'needs.ruling|needs ruling' 'ADR-0028'

# The negative boundary names the routine-engineering cases that stay local.
has "$ref" "negative boundary" \
  'refactor' 'dependency bump' 'bug fix' 'release work' 'remain local|stays? local'

# Destination resolution: spark hub is the only source; never guessed.
has "$ref" "destination resolution" \
  'spark hub' 'never (be )?guess|never guess' 'none' 'malformed'

# Evidence: source-repo GitHub links, cited not copied; memory is not authority.
has "$ref" "evidence bundle" \
  'issue, PR, merge commit' 'release' 'cited, not transcribed|cite.*never.*transcrib' 'agent memory'

# The hub's own rules govern: inspect first, update over duplicate, supersession,
# journal routing, no bulk copy.
has "$ref" "hub rules govern" \
  'inspect' 'update over duplicate|amending the hub' 'supersession|superseded' \
  'journal' 'bulk copy'

# Human authority gates architectural rulings; facts record without inventing one.
has "$ref" "human authority" \
  'human' 'architectural ruling' 'without inventing a ruling'

# The no-op outcome is first-class and produces no ceremony.
has "$ref" "no-op outcome" \
  'no.op|nothing durable' 'ceremony'

# The skill routes the lane: step names spark hub + the reference, description
# carries the promotion trigger so the selector can find it.
has "$skill/SKILL.md" "skill wiring" \
  'hub-promotion\.md' 'spark hub' 'deletion test' 'no ceremony'
desc="$(awk '/^description:/{sub(/^description:[[:space:]]*/,"");print;exit}' "$skill/SKILL.md")"
printf '%s' "$desc" | grep -qiE 'memory hub' && ok || bad "skill description: missing memory-hub trigger"
[ "${#desc}" -le 1024 ] && ok || bad "skill description over the 1024-char budget (${#desc})"

# The librarian-editor owns the classification and the hub write path.
has "$agents/02-librarian-editor.md" "librarian duties" \
  'Hub candidates' 'deletion test' 'spark hub' "hub's own process" 'bulk copy'

# Intake records the GitHub evidence the candidates will cite.
has "$agents/00-intake.md" "intake evidence" \
  'issue' 'PR' 'merge commit' 'release' 'agent memory'

# Provider neutrality: the shipped plugin never names a constellation.
if grep -rniE 'cosmos|status26' "$root/plugins/spark" >/dev/null 2>&1; then
  bad "shipped plugin hard-codes a constellation name (cosmos/status26)"
else
  ok
fi

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
