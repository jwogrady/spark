#!/usr/bin/env bash
# Behavioural suite for the paired snapshot benchmark (#736): in stub mode every
# count is exact, and the harness proves the negative controls the benchmark
# rests on — disabling reuse restores the full reads, reuse never suppresses a
# source read, and a new HEAD moves exactly the HEAD-bound facts.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "paired snapshot benchmark (#736)"
BENCH="$repo_root/tests/bench-facts.sh"
[ -x "$BENCH" ] && ok || bad "tests/bench-facts.sh is executable"

assert_eq "a non-numeric work unit is refused" "2" "$(bash "$BENCH" --issue x --stub >/dev/null 2>&1; echo $?)"
assert_eq "a missing work unit is refused" "2" "$(bash "$BENCH" --stub >/dev/null 2>&1; echo $?)"

J="$(bash "$BENCH" --issue 801 --stub --json 2>/dev/null)"
[ -n "$J" ] && ok || bad "stub mode produces a JSON line"
row() { printf '%s' "$J" | jq -r --arg a "$1" --argjson r "$2" '.rows[] | select(.arm == $a and .round == $r) | .'"$3"; }
tel() { printf '%s' "$J" | jq -r --arg a "$1" --argjson r "$2" '.telemetry[] | select(.arm == $a and .round == $r) | .'"$3"; }

assert_eq "the mode is recorded" "stub" "$(printf '%s' "$J" | jq -r .mode)"
assert_contains "requests are declared as exact by construction" "HTTP requests by construction" "$(printf '%s' "$J" | jq -r .counts_are.requests)"
assert_contains "the compiler is inside the measured boundary" "inside the snapshot and reuse arms" "$(printf '%s' "$J" | jq -r .boundary)"

# --- journey: one read per surface per round, and no reuse between rounds ----
assert_eq "the journey reads twelve surfaces for a pull request" "12" "$(row journey 1 requests)"
assert_eq "and reads them all again next round" "12" "$(row journey 2 requests)"
assert_eq "returning the same bytes each time" "$(row journey 1 bytes)" "$(row journey 2 bytes)"

# --- snapshot: the compiler's reads, identical every round (reuse disabled) --
assert_eq "the snapshot arm makes the compiler's seven requests" "7" "$(row snapshot 1 requests)"
assert_eq "disabling reuse restores the full reads next round" "7" "$(row snapshot 2 requests)"
assert_eq "and the full output" "$(row snapshot 1 bytes)" "$(row snapshot 2 bytes)"
assert_eq "the shim's count is the compiler's own count" "$(tel snapshot 1 facts_api_calls)" "$(row snapshot 1 requests)"
assert_eq "and the shim's bytes are the compiler's printed bytes" "$(tel snapshot 1 facts_output_bytes)" "$(row snapshot 1 bytes)"
assert_eq "a complete snapshot was compiled" "snapshot" "$(tel snapshot 1 facts_output_shape)"

# --- reuse: no read is suppressed; only what the consumer receives shrinks ---
assert_eq "the cold reuse round reads exactly what the snapshot arm reads" "$(row snapshot 1 requests)" "$(row reuse 1 requests)"
assert_eq "the warm reuse round still reads every source (P4)" "$(row snapshot 1 requests)" "$(row reuse 2 requests)"
[ "$(row reuse 2 bytes)" -lt "$(row reuse 1 bytes)" ] && ok || bad "the warm round returns fewer bytes than the cold one"
assert_eq "the warm round changed nothing" "0" "$(tel reuse 2 facts_changed)"
assert_eq "and reused every fact by key" "10" "$(tel reuse 2 facts_unchanged)"
assert_eq "as a delta, not a snapshot" "delta" "$(tel reuse 2 facts_output_shape)"

# --- the simulated push: HEAD-bound facts move, the rest are reused ----------
assert_eq "the journey reads twelve surfaces again after a push" "12" "$(row journey 3 requests)"
assert_eq "the post-push delta moves the five HEAD-bound facts" "5" "$(tel reuse 3 facts_changed)"
assert_eq "and reuses the five that no push can move" "5" "$(tel reuse 3 facts_unchanged)"
[ "$(row reuse 3 bytes)" -gt "$(row reuse 2 bytes)" ] && ok || bad "a moved HEAD sends more than an unchanged round"
[ "$(row reuse 3 bytes)" -lt "$(row snapshot 3 bytes)" ] && ok || bad "but still less than the full output"

# --- what the compiler could not establish is carried, not hidden -----------
assert_eq "the first reuse round says it had no record" "1" \
  "$(printf '%s' "$J" | jq '[.notes[] | select(.arm == "reuse" and .round == 1 and (.note | test("no previous record")))] | length')"

finish
