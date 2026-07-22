#!/usr/bin/env bash
# Behavioral suite for the hot-path latency measurement and gate (#213). Wall
# clock is machine-dependent, so the pass/fail assertions drive the budgets via
# the env overrides rather than the clock — the suite must never flake on a slow
# runner. Runs against a throwaway copy of the plugin.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init

# --- machine-readable timing names the three paths, their ms, and their budgets.
json="$("$SPARK" footprint --timing --json)"
assert_contains "timing json states the method" '"method":"median-of-3 wall-clock ms' "$json"
assert_contains "timing json measures the guard" '"guard":{"ms":' "$json"
assert_contains "timing json measures the brief" '"brief":{"ms":' "$json"
assert_contains "timing json measures doctor" '"doctor":{"ms":' "$json"
assert_contains "timing json carries the default doctor budget" '"budget":6000' "$json"

# --- the hard gate PASSES when every path is within budget (budgets forced
# generous so the machine's real speed can't flake the assertion).
rc=0
LATENCY_GUARD_MS=999999 LATENCY_BRIEF_MS=999999 LATENCY_DOCTOR_MS=999999 \
  "$SPARK" footprint --timing >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] && ok || bad "footprint --timing passes within generous budgets (got $rc)"

# --- the hard gate FAILS non-zero and names the path when one is over budget.
out=""; rc=0
out="$(LATENCY_GUARD_MS=0 "$SPARK" footprint --timing 2>&1)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "footprint --timing must fail when a path is over budget"
assert_contains "the over-budget path is marked" "OVER BUDGET" "$out"

# --- doctor only WARNS on latency: even with an impossible brief budget it must
# still exit 0 (the whole point of the warn-not-fail decision), and say so.
out=""; rc=0
out="$( cd "$WORK" && LATENCY_BRIEF_MS=0 "$SPARK" doctor 2>&1 )" || rc=$?
[ "$rc" -eq 0 ] && ok || bad "doctor must not fail on a latency regression (got $rc)"
assert_contains "doctor prints the latency advisory" "Latency (advisory" "$out"
assert_contains "doctor warns on the over-budget brief" "over the 0ms budget" "$out"

# --- #265: on a date without GNU %N (macOS/BSD), timing must degrade, not
# compute garbage. Inject a fake date that prints a literal 'N' for +%s%N and
# delegates everything else to the real date by absolute path (no recursion).
fake="$WORK/fakebin"; mkdir -p "$fake"; realdate="$(command -v date)"
cat > "$fake/date" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "+%s%N" ]; then printf '%sN\n' "\$($realdate +%s)"; else exec $realdate "\$@"; fi
EOF
chmod +x "$fake/date"
bsd_json="$(PATH="$fake:$PATH" "$SPARK" footprint --timing --json 2>/dev/null || true)"
assert_contains "timing still emits a doctor ms without GNU %N" '"doctor":{"ms":' "$bsd_json"
bsd_ms="$(printf '%s' "$bsd_json" | sed -n 's/.*"doctor":{"ms":\([0-9][0-9]*\).*/\1/p')"
[ -n "$bsd_ms" ] && ok || bad "#265: doctor ms is a number under a %N-less date (got '$bsd_ms')"

# --- #281: no GNU %N AND no python3 → report "not measured", never fake a
# whole-second value as milliseconds. Build a minimal PATH with the BSD-stub
# date and no python3.
minpath="$WORK/minbin"; mkdir -p "$minpath"; cp "$fake/date" "$minpath/date"
for t in bash sh dirname basename cat cp mkdir grep sed awk sort tr head wc find env git; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] && ln -s "$real" "$minpath/$t"
done
noclock_json="$(env -i PATH="$minpath" HOME="$WORK/home" "$SPARK" footprint --timing --json 2>/dev/null || true)"
assert_contains "no ms clock reports null, not a faked number" '"doctor":{"ms":null' "$noclock_json"
# and the gate still exits 0 (an unmeasurable host must not fail the budget)
rc=0; ( env -i PATH="$minpath" HOME="$WORK/home" "$SPARK" footprint --timing >/dev/null 2>&1 ) || rc=$?
[ "$rc" -eq 0 ] && ok || bad "#281: unmeasurable host must not fail the timing gate (got $rc)"

finish
