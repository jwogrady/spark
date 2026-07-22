#!/usr/bin/env bash
# Behavioral suite for the total context-footprint ratchet and cache-stability
# check doctor enforces (#292). Sources bin/spark (the dispatch is source-
# guarded) to drive the factored gate functions against a throwaway fixture
# marketplace with env-set budgets — the "--root fixture" path the issue asks
# for, with no dependency on the real repo's size.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # load fp_footprint_gate / fp_plugin_bytes / fp_cache_stability

mkt="$WORK/fpmkt"
mkdir -p "$mkt/plugins/p1/skills/a" "$mkt/plugins/p2/skills/b"
cat > "$mkt/plugins/p1/skills/a/SKILL.md" <<'EOF'
---
name: a
description: short
---
body
EOF
cat > "$mkt/plugins/p2/skills/b/SKILL.md" <<'EOF'
---
name: b
description: short
---
body
EOF

# fp_plugin_bytes returns a positive integer.
pb="$(fp_plugin_bytes "$mkt/plugins/p1")"
case "$pb" in ''|*[!0-9]*) bad "fp_plugin_bytes non-numeric ($pb)" ;; *) [ "$pb" -gt 0 ] && ok || bad "fp_plugin_bytes not positive ($pb)" ;; esac

# --- within budget: generous ceilings pass and the summary names the ceiling.
FOOTPRINT_MARKETPLACE_MAX_BYTES=1000000; FOOTPRINT_PLUGIN_MAX_BYTES=1000000
out="$(fp_footprint_gate "$mkt")"; rc=$?
assert_rc "within budget passes" 0 "$rc"
assert_contains "within-budget summary names the ceiling" "1000000B" "$out"

# --- over the marketplace budget: fails and names the marketplace breach.
FOOTPRINT_MARKETPLACE_MAX_BYTES=1; FOOTPRINT_PLUGIN_MAX_BYTES=1000000
rc=0; out="$(fp_footprint_gate "$mkt")" || rc=$?
assert_rc "over marketplace budget fails" 1 "$rc"
assert_contains "names the marketplace breach" "marketplace=" "$out"

# --- over the per-plugin budget: fails and names the offending plugin.
FOOTPRINT_MARKETPLACE_MAX_BYTES=1000000; FOOTPRINT_PLUGIN_MAX_BYTES=1
rc=0; out="$(fp_footprint_gate "$mkt")" || rc=$?
assert_rc "over plugin budget fails" 1 "$rc"
assert_contains "names the offending plugin" "p1=" "$out"

# --- cache stability: a clean fixture passes.
rc=0; out="$(fp_cache_stability "$mkt")" || rc=$?
assert_rc "clean surfaces pass cache-stability" 0 "$rc"

# --- a volatile date in the root CLAUDE.md is flagged, naming the file.
printf '# Repo\nLast updated 2026-01-02.\n' > "$mkt/CLAUDE.md"
rc=0; out="$(fp_cache_stability "$mkt")" || rc=$?
assert_rc "volatile CLAUDE.md is flagged" 1 "$rc"
assert_contains "names CLAUDE.md" "CLAUDE.md" "$out"

# --- a volatile token in a skill description is flagged.
rm -f "$mkt/CLAUDE.md"
cat > "$mkt/plugins/p1/skills/a/SKILL.md" <<'EOF'
---
name: a
description: short, as of 2026 already
---
body
EOF
rc=0; out="$(fp_cache_stability "$mkt")" || rc=$?
assert_rc "volatile description is flagged" 1 "$rc"

finish
