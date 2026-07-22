#!/usr/bin/env bash
# Behavioral suite for `spark footprint` (#208). It measures a fixture
# marketplace with known file sizes and asserts the per-surface and total
# counts, the machine-readable shape, the stated approximation method, and that
# nothing requires jq/python3. No network; the fixture is built from scratch so
# "known sizes" means known.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init

# --- a two-plugin fixture marketplace. Descriptions are fixed-length strings so
# the always-loaded selection cost is exactly known; every other file's bytes
# are measured independently with wc, so the assertions never just re-run the
# script's own arithmetic.
mkt="$WORK/mkt"
mkdir -p "$mkt/plugins/p-core/skills/alpha/references" \
         "$mkt/plugins/p-core/agents/crew" \
         "$mkt/plugins/p-comp/skills/beta"

# p-core: one skill (20-char description), one reference, one agent.
cat > "$mkt/plugins/p-core/skills/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: aaaaaaaaaaaaaaaaaaaa
---
Alpha body line one.
Alpha body line two.
EOF
printf 'reference one\nreference two\n' > "$mkt/plugins/p-core/skills/alpha/references/r1.md"
cat > "$mkt/plugins/p-core/agents/crew/a1.md" <<'EOF'
---
name: a1
description: crew agent
---
agent body
EOF

# p-comp: one skill (10-char description), no refs, no agents.
cat > "$mkt/plugins/p-comp/skills/beta/SKILL.md" <<'EOF'
---
name: beta
description: bbbbbbbbbb
---
Beta body.
EOF

# Independent expectations.
desc_chars=$((20 + 10))
core_skill_b=$(wc -c < "$mkt/plugins/p-core/skills/alpha/SKILL.md")
core_ref_b=$(wc -c < "$mkt/plugins/p-core/skills/alpha/references/r1.md")
core_agent_b=$(wc -c < "$mkt/plugins/p-core/agents/crew/a1.md")
comp_skill_b=$(wc -c < "$mkt/plugins/p-comp/skills/beta/SKILL.md")
file_b=$((core_skill_b + core_ref_b + core_agent_b + comp_skill_b))
grand_b=$((file_b + desc_chars))
grand_t=$((grand_b / 4))

json="$("$SPARK" footprint --root "$mkt" --json)"
human="$("$SPARK" footprint --root "$mkt")"

# --- machine-readable: grand total bytes and tokens match the independent sums.
assert_contains "json states the approximation method" '"method":"bytes/4"' "$json"
assert_contains "json grand total bytes match wc + description chars" \
  "\"total\":{\"bytes\":${grand_b},\"lines\":" "$json"
assert_contains "json grand total tokens are bytes/4" \
  ",\"tokens\":${grand_t}}" "$json"

# --- per-surface: the always-loaded description cost is exactly the two strings.
assert_contains "core skill-descriptions counts the 20-char description" \
  "\"skill-descriptions\":{\"bytes\":20," "$json"
assert_contains "comp skill-descriptions counts the 10-char description" \
  "\"skill-descriptions\":{\"bytes\":10," "$json"

# --- a plugin with no agents reports the surface as zero, not absent.
assert_contains "comp reports zero agents rather than omitting the surface" \
  '"agents":{"bytes":0,"lines":0,"tokens":0}' "$json"

# --- both plugins appear, and --root suppresses the environment-dependent
# runtime brief so the fixture total stays deterministic.
assert_contains "core plugin named in json" '"name":"p-core"' "$json"
assert_contains "companion plugin named in json" '"name":"p-comp"' "$json"
case "$json" in *'"runtime"'*) bad "--root run must omit the runtime brief" ;; *) ok ;; esac

# --- human-readable: the method line, a surface table, and the total.
assert_contains "human output states the method" "Token estimate = bytes ÷ 4" "$human"
assert_contains "human output shows the marketplace total" "marketplace total" "$human"
assert_contains "human total bytes match the sums" "$grand_b" "$human"

# --- zero-dependency: with neither jq nor python3 on PATH, --json still works
# (footprint builds JSON itself and counts with wc/awk).
barepath="$WORK/barebin"; mkdir -p "$barepath"
for t in bash sh dirname basename cat cp mkdir grep sed awk sort tr head wc find env; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] && ln -s "$real" "$barepath/$t"
done
bare_json="$(env -i PATH="$barepath" HOME="$WORK/home" bash "$SPARK" footprint --root "$mkt" --json 2>/dev/null || true)"
assert_contains "footprint --json works without jq/python3" \
  "\"total\":{\"bytes\":${grand_b}," "$bare_json"

finish
