#!/usr/bin/env bash
# Static contract guard for the knowledge skill's cross-project promotion lane
# (issue #376, ADR-0028). Skills are prose, so the load-bearing pieces of the
# promotion contract are pinned the way test-skill-descriptions.sh pins routing
# discriminators: token presence, never whole sentences, so the prose stays
# free to improve. Graded end-to-end proof (positive + negative fixtures,
# Cosmos dogfood) is #377's evidence, not this file's.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/plugins/spark/skills/knowledge"
agents="$root/plugins/spark/agents/knowledge"

ref="$skill/references/hub-promotion.md"

# The classifier: the deletion test with its three outcomes, stated as ADR-0028's.
assert_flat_contains_all "$ref" "classification test" \
  'still be useful and true' 'disappeared' 'needs.ruling|needs ruling' 'ADR-0028'

# The negative boundary names the routine-engineering cases that stay local.
assert_flat_contains_all "$ref" "negative boundary" \
  'refactor' 'dependency bump' 'bug fix' 'release work' 'remain local|stays? local'

# Destination resolution: spark hub is the only source; never guessed.
assert_flat_contains_all "$ref" "destination resolution" \
  'spark hub' 'never (be )?guess|never guess' 'none' 'malformed'

# Evidence: source-repo GitHub links, cited not copied; memory is not authority.
assert_flat_contains_all "$ref" "evidence bundle" \
  'issue, PR, merge commit' 'release' 'cited, not transcribed|cite.*never.*transcrib' 'agent memory'

# The hub's own rules govern: inspect first, update over duplicate, supersession,
# journal routing, no bulk copy.
assert_flat_contains_all "$ref" "hub rules govern" \
  'inspect' 'update over duplicate|amending the hub' 'supersession|superseded' \
  'journal' 'bulk copy'

# Human authority gates architectural rulings; facts record without inventing one.
assert_flat_contains_all "$ref" "human authority" \
  'human' 'architectural ruling' 'without inventing a ruling'

# The no-op outcome is first-class and produces no ceremony.
assert_flat_contains_all "$ref" "no-op outcome" \
  'no.op|nothing durable' 'ceremony'

# The skill routes the lane: step names spark hub + the reference, description
# carries the promotion trigger so the selector can find it.
assert_flat_contains_all "$skill/SKILL.md" "skill wiring" \
  'hub-promotion\.md' 'spark hub' 'deletion test' 'no ceremony'
desc="$(awk '/^description:/{sub(/^description:[[:space:]]*/,"");print;exit}' "$skill/SKILL.md")"
printf '%s' "$desc" | grep -qiE 'memory hub' && ok || bad "skill description: missing memory-hub trigger"
[ "${#desc}" -le 1024 ] && ok || bad "skill description over the 1024-char budget (${#desc})"

# The librarian-editor owns the classification and the hub write path.
assert_flat_contains_all "$agents/02-librarian-editor.md" "librarian duties" \
  'Hub candidates' 'deletion test' 'spark hub' "hub's own process" 'bulk copy'

# Intake records the GitHub evidence the candidates will cite — pinned as the
# one phrase so a trimmed evidence list can't hide behind substring noise
# ("PR" inside "product", "issue" inside "issues").
assert_flat_contains_all "$agents/00-intake.md" "intake evidence" \
  'issue, PR, merge commit, release' 'agent memory'

# Provider neutrality: nothing shipped — core or companion — names a
# constellation.
assert_no_constellation_names "$root"

# --- the terminology split (#477) ------------------------------------------
# `provenance` names change-over-time history; the flow that carries durable
# meaning is `knowledge promotion`. Both halves are pinned: the canonical
# glossary must define each term, and no *current* shipped surface may name the
# promotion flow or its classification boundary `provenance`.

glossary="$root/plugins/spark/docs/glossary.md"

# One canonical definition each, cross-linked to the deciding ADR.
assert_flat_contains_all "$glossary" "provenance is change history" \
  '### provenance' 'change-over-time' 'Git and GitHub' 'cited' 'ADR-0031'

assert_flat_contains_all "$glossary" "knowledge promotion is durable meaning" \
  '### knowledge promotion' 'durable' 'memory hub' 'deletion test' 'ADR-0028'

# The old name is explained exactly where a reader meets it, not erased.
assert_flat_contains_all "$glossary" "historical name explained once" \
  'provenance.promotion'

# No current shipped surface names the promotion flow `provenance`. Checked per
# file so a failure names the file that regressed. The audit companion's
# `provenance leakage` finding class is the *correct* sense and is untouched.
for f in \
  "$root/plugins/spark/skills/ship/SKILL.md" \
  "$root/plugins/spark/skills/ship/references/release-please.md" \
  "$root/plugins/spark/skills/knowledge/references/hub-promotion.md" \
  "$root/plugins/spark/docs/reference/cli.md" \
  "$root/plugins/spark/docs/reference/engineering-preferences.md"; do
  assert_flat_lacks "$f" "no provenance-as-meaning in $(basename "$f")" \
    'provenance.(promotion|boundary)|cross-project provenance'
done

# The decision record carries the current term and discloses the rename.
adr="$root/docs/adr/0028-cross-project-memory-hubs.md"
assert_flat_contains_all "$adr" "ADR-0028 uses the current term" \
  'Spark owns knowledge promotion' 'Terminology refined by' '#477' 'ADR-0031'

# Historical records keep the name they were recorded under — the rename must
# not be applied retroactively to evidence.
assert_flat_contains_all "$root/docs/releases/v0.17.md" \
  "v0.17 record keeps its milestone name" 'Provenance promotion'

finish
