#!/usr/bin/env bash
# Static contract guard for the lifecycle-boundary promotion surfaces (issue
# #377, ADR-0028): codify's discovery trigger, validate's findings trigger,
# ship's issue-completion and milestone-completion triggers. Same technique
# as test-knowledge-promotion.sh (shared via lib.sh's assert_flat_* helpers) —
# token presence on whitespace-collapsed prose, never whole sentences. Graded
# proof of the classification judgment itself lives in
# evaluations/provenance-promotion/ (fixtures + PROOF.md), not here.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/spark/skills"

# --- codify: the discovery boundary triggers before ship, routes to knowledge
assert_flat_contains_all "$skills/codify/SKILL.md" "codify discovery trigger" \
  'falsif' 'ADR-0028' 'knowledge' "don't wait for ship|do not wait for ship"

# --- validate: the findings boundary, routes to knowledge
assert_flat_contains_all "$skills/validate/SKILL.md" "validate findings trigger" \
  'durable cross-project learning' 'ADR-0028' 'knowledge'

# --- ship: the issue-completion boundary, routes to knowledge, and points at
# the milestone-completion boundary rather than duplicating it
assert_flat_contains_all "$skills/ship/SKILL.md" "ship issue-completion trigger" \
  'ADR-0028' 'knowledge' 'never classif' 'milestone/release'

# --- the milestone-completion boundary lives beside the release motion, once
# per milestone, not once per issue
assert_flat_contains_all "$skills/ship/references/release-please.md" "milestone-completion trigger" \
  'ADR-0028' 'knowledge' 'once per milestone'

# --- none of the three duplicate hub-promotion.md's classification logic —
# they name the question and route, they do not restate the deletion test's
# evidence-bundle/hub-rules machinery (that would violate "not duplicating
# classification/promotion logic in each lifecycle skill").
assert_flat_lacks "$skills/codify/SKILL.md" "codify doesn't restate the evidence bundle" \
  'cited, not transcribed|source-repo github evidence'
assert_flat_lacks "$skills/validate/SKILL.md" "validate doesn't restate the evidence bundle" \
  'cited, not transcribed|source-repo github evidence'
assert_flat_lacks "$skills/ship/SKILL.md" "ship doesn't restate the evidence bundle" \
  'cited, not transcribed|source-repo github evidence'

# --- no lifecycle skill claims a sixth public stage
for f in "$skills/codify/SKILL.md" "$skills/validate/SKILL.md" "$skills/ship/SKILL.md"; do
  assert_flat_lacks "$f" "$(basename "$(dirname "$f")"): no sixth stage claimed" \
    'sixth (public )?(lifecycle )?stage'
done

# --- the lifecycle spine itself is unchanged: still five stages, same order
assert_flat_contains_all "$root/plugins/spark/docs/explanation/sdlc-doctrine.md" "spine unchanged" \
  'Ideate.*Plan.*Codify.*Validate.*Ship'

# --- carry-forward names the new motion without inventing a fourth layer
assert_flat_contains_all "$root/plugins/spark/docs/glossary.md" "glossary carry-forward extended" \
  'related.*Project memory authority' 'not a sixth stage'

# --- SKILL.md files stay inside the 100-line budget doctor enforces
for f in "$skills/codify/SKILL.md" "$skills/validate/SKILL.md" "$skills/ship/SKILL.md"; do
  n="$(wc -l < "$f")"
  [ "$n" -le 100 ] && ok || bad "$(basename "$(dirname "$f")")/SKILL.md over the 100-line budget ($n)"
done

# --- the provenance-promotion evaluation evidence exists: one positive, all
# three named negative fixtures (refactor, dependency bump, release work —
# the exact routine-engineering cases #377's acceptance criteria name), a
# proof run, and the dogfood record.
evalroot="$root/evaluations/provenance-promotion"
[ -f "$evalroot/fixtures/positive-boundary-discovery.md" ] && ok || bad "missing the positive fixture"
for f in negative-routine-refactor negative-dependency-bump negative-release-work; do
  [ -f "$evalroot/fixtures/$f.md" ] && ok || bad "missing the $f fixture"
done
[ -f "$evalroot/PROOF.md" ] && ok || bad "missing PROOF.md"
assert_flat_contains_all "$evalroot/PROOF.md" "proof tags evidence class" '\[observed\]' '\[reasoned\]'
[ -f "$evalroot/dogfood-cosmos.md" ] && ok || bad "missing dogfood-cosmos.md"
assert_flat_contains_all "$evalroot/dogfood-cosmos.md" "dogfood run is real, not narrated" \
  'jwogrady/cosmos' 'spark hub' '\[human\]'
assert_flat_contains_all "$evalroot/dogfood-cosmos.md" "dogfood names the human gate and its outcome" \
  'human ruling required by ADR-0019' 'explicitly authorized filing it'

# --- provider neutrality holds after this change too (every shipped plugin)
assert_no_constellation_names "$root"

finish
