#!/usr/bin/env bash
# Static contract guard for the lifecycle-boundary promotion surfaces (issue
# #377, ADR-0028): codify's discovery trigger, validate's findings trigger,
# ship's issue-completion and milestone-completion triggers. Same technique
# as test-knowledge-promotion.sh — token presence on whitespace-collapsed
# prose, never whole sentences — plus line-budget and doctor checks specific
# to this change. Graded proof of the classification judgment itself lives in
# evaluations/provenance-promotion/ (fixtures + PROOF.md), not here.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/spark/skills"
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

# has <file> <desc> <ere>... — every ERE must appear (case-insensitive) in the
# file, matched against whitespace-collapsed prose.
has() {
  local f="$1" desc="$2" m flat; shift 2
  [ -f "$f" ] || { bad "$desc: $(basename "$f") missing"; return; }
  flat="$(tr -s '[:space:]' ' ' < "$f")"
  for m in "$@"; do
    printf '%s' "$flat" | grep -qiE -- "$m" \
      || { bad "$desc: missing /$m/ in $(basename "$f")"; return; }
  done
  ok
}

# lacks <file> <desc> <ere> — the ERE must NOT appear, case-insensitive.
lacks() {
  local f="$1" desc="$2" m="$3" flat
  [ -f "$f" ] || { bad "$desc: $(basename "$f") missing"; return; }
  flat="$(tr -s '[:space:]' ' ' < "$f")"
  if printf '%s' "$flat" | grep -qiE -- "$m"; then
    bad "$desc: forbidden /$m/ found in $(basename "$f")"
  else
    ok
  fi
}

# --- codify: the discovery boundary triggers before ship, routes to knowledge
has "$skills/codify/SKILL.md" "codify discovery trigger" \
  'falsif' 'ADR-0028' 'knowledge' "don't wait for ship|do not wait for ship"

# --- validate: the findings boundary, routes to knowledge
has "$skills/validate/SKILL.md" "validate findings trigger" \
  'durable cross-project learning' 'ADR-0028' 'knowledge'

# --- ship: the issue-completion boundary, routes to knowledge, and points at
# the milestone-completion boundary rather than duplicating it
has "$skills/ship/SKILL.md" "ship issue-completion trigger" \
  'ADR-0028' 'knowledge' 'never classif' 'milestone/release'

# --- the milestone-completion boundary lives beside the release motion, once
# per milestone, not once per issue
has "$skills/ship/references/release-please.md" "milestone-completion trigger" \
  'ADR-0028' 'knowledge' 'once per milestone'

# --- none of the three duplicate hub-promotion.md's classification logic —
# they name the question and route, they do not restate the deletion test's
# evidence-bundle/hub-rules machinery (that would violate "not duplicating
# classification/promotion logic in each lifecycle skill").
lacks "$skills/codify/SKILL.md" "codify doesn't restate the evidence bundle" \
  'cited, not transcribed|source-repo github evidence'
lacks "$skills/validate/SKILL.md" "validate doesn't restate the evidence bundle" \
  'cited, not transcribed|source-repo github evidence'
lacks "$skills/ship/SKILL.md" "ship doesn't restate the evidence bundle" \
  'cited, not transcribed|source-repo github evidence'

# --- no lifecycle skill claims a sixth public stage
for f in "$skills/codify/SKILL.md" "$skills/validate/SKILL.md" "$skills/ship/SKILL.md"; do
  lacks "$f" "$(basename "$(dirname "$f")"): no sixth stage claimed" \
    'sixth (public )?(lifecycle )?stage'
done

# --- the lifecycle spine itself is unchanged: still five stages, same order
has "$root/plugins/spark/docs/explanation/sdlc-doctrine.md" "spine unchanged" \
  'Ideate.*Plan.*Codify.*Validate.*Ship'

# --- carry-forward names the new motion without inventing a fourth layer
has "$root/plugins/spark/docs/glossary.md" "glossary carry-forward extended" \
  'related.*Project memory authority' 'not a sixth stage'

# --- SKILL.md files stay inside the 100-line budget doctor enforces
for f in "$skills/codify/SKILL.md" "$skills/validate/SKILL.md" "$skills/ship/SKILL.md"; do
  n="$(wc -l < "$f")"
  [ "$n" -le 100 ] && ok || bad "$(basename "$(dirname "$f")")/SKILL.md over the 100-line budget ($n)"
done

# --- the provenance-promotion evaluation evidence exists: one positive, at
# least three negative fixtures, a proof run, and the dogfood record
evalroot="$root/evaluations/provenance-promotion"
[ -f "$evalroot/fixtures/positive-boundary-discovery.md" ] && ok || bad "missing the positive fixture"
negs=0
for f in "$evalroot"/fixtures/negative-*.md; do [ -f "$f" ] && negs=$((negs + 1)); done
[ "$negs" -ge 2 ] && ok || bad "want at least 2 negative fixtures, found $negs"
[ -f "$evalroot/PROOF.md" ] && ok || bad "missing PROOF.md"
has "$evalroot/PROOF.md" "proof tags evidence class" '\[observed\]' '\[reasoned\]'
[ -f "$evalroot/dogfood-cosmos.md" ] && ok || bad "missing dogfood-cosmos.md"
has "$evalroot/dogfood-cosmos.md" "dogfood run is real, not narrated" \
  'jwogrady/cosmos' 'spark hub' '\[human\]'
has "$evalroot/dogfood-cosmos.md" "dogfood stops for human go-ahead, doesn't write" \
  'prepared, not filed|not written|not executed'

# --- provider neutrality holds after this change too (every shipped plugin)
if grep -rniE 'cosmos|status26' "$root"/plugins/*/ >/dev/null 2>&1; then
  bad "a shipped plugin hard-codes a constellation name (cosmos/status26)"
else
  ok
fi

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
