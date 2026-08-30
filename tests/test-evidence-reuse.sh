#!/usr/bin/env bash
# Behavioural suite for #576 — capture a fact once, share it, invalidate it by
# named inputs.
#
# Two claims are under test, and they pull against each other, which is why
# neither can be trusted without the other:
#
#   * FEWER READS. Several consumers of the same fact must cost one remote
#     capture, not one each -- proven by a producer stub that records every
#     invocation, with both consumers required to reach the same verdict.
#   * NO STALE TRUTH. A capture may be reused only while every stated
#     invalidator is unchanged, and the refusal must NAME what moved. Cheapness
#     bought by serving an answer about an earlier commit is not efficiency; it
#     is a correctness bug with better economics.
#
# The same tension governs bounds: a capture that hit its limit is partial, and
# partial evidence presented as whole evidence is how a run concludes something
# false at a discount.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "evidence reuse and invalidation (#576)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

rc() {
  local want="$1" desc="$2" got=0; shift 3
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$want" ]; then ok; else bad "$desc (wanted rc $want, got $got)"; fi
}

# --- one capture, many consumers --------------------------------------------
# The producer stub stands in for a remote read. Every invocation is logged, so
# "collected once" is a counted fact rather than a claim.
PRODUCER_LOG="$WORK/producer.calls"
: > "$PRODUCER_LOG"
produce() {
  echo "called" >> "$PRODUCER_LOG"
  printf 'issue\t1\topen\nissue\t2\tclosed\n'
}
# The shape a consumer uses: read the shared capture, and collect only if there
# is nothing fresh to read.
consume() {
  "$SPARK" evidence get --key slate --head abc123 --model claude-opus-5 2>/dev/null || {
    produce | "$SPARK" evidence put --key slate --head abc123 --model claude-opus-5 >/dev/null
    "$SPARK" evidence get --key slate --head abc123 --model claude-opus-5 2>/dev/null
  }
}

A="$(consume)"
B="$(consume)"
CALLS="$(wc -l < "$PRODUCER_LOG" | tr -d ' ')"
[ "$CALLS" = "1" ] && ok || bad "two consumers must share one capture (the producer ran $CALLS times)"
[ "$A" = "$B" ] && ok || bad "sharing a capture must not change what a consumer sees"
assert_contains "the shared projection is the real payload" "issue	2	closed" "$B"
assert_contains "the capture counts its consumers" "consumers=2" "$("$SPARK" evidence status)"

# A second producer of an already-fresh fact is duplicate collection, and it is
# reported rather than silently paid for twice.
DUP="$(printf 'x\n' | "$SPARK" evidence put --key slate --head abc123 --model claude-opus-5 2>&1)"
assert_contains "a duplicate producer is detected" "already captured — reusing" "$DUP"
assert_contains "and points at the deliberate override" "--force" "$DUP"
assert_contains "the duplicate did not overwrite the capture" "issue	2	closed" \
  "$("$SPARK" evidence get --key slate --head abc123 --model claude-opus-5)"

printf 'replaced\n' | "$SPARK" evidence put --key slate --head abc123 --model claude-opus-5 --force >/dev/null
assert_contains "--force recaptures deliberately" "replaced" \
  "$("$SPARK" evidence get --key slate --head abc123 --model claude-opus-5)"

# --- invalidation names what moved -------------------------------------------
printf 'body\n' | "$SPARK" evidence put --key inv --head abc123 --contract v1 \
  --model claude-opus-5 --effort high --tools sha-aaa >/dev/null

rc 0 "an unchanged fingerprint reads clean" -- \
  "$SPARK" evidence get --key inv --head abc123 --contract v1 --model claude-opus-5 --effort high --tools sha-aaa

check_drift() { # check_drift <desc> <needle> <flag> <value>
  local out
  out="$("$SPARK" evidence get --key inv --head abc123 --contract v1 --model claude-opus-5 \
        --effort high --tools sha-aaa "$3" "$4" 2>&1 || true)"
  assert_contains "$1" "$2" "$out"
}
check_drift "a moved commit invalidates, and is named"      "the head changed (abc123 -> zzz999)"          --head zzz999
check_drift "a changed governing contract invalidates"      "the contract changed (v1 -> v2)"              --contract v2
check_drift "a changed model invalidates"                   "the model changed"                            --model claude-sonnet-5
check_drift "a changed effort class invalidates"            "the effort changed (high -> low)"             --effort low
check_drift "a changed tool surface invalidates"            "the tools changed (sha-aaa -> sha-bbb)"       --tools sha-bbb

rc 2 "a stale capture is refused, not served" -- "$SPARK" evidence get --key inv --head zzz999
STALE="$("$SPARK" evidence get --key inv --head zzz999 2>&1 || true)"
case "$STALE" in *body*) bad "a stale capture must not hand back its payload" ;; *) ok ;; esac
assert_contains "and says why reuse would be wrong" "never make an old verdict valid" "$STALE"

# An invalidator the caller does not state cannot invalidate — otherwise every
# consumer would have to restate the whole fingerprint to read anything.
rc 0 "an unstated invalidator does not invalidate" -- "$SPARK" evidence get --key inv --head abc123

# --- bounds: partial evidence must announce itself ---------------------------
PUT="$(printf 'row\n' | "$SPARK" evidence put --key pages --head abc123 --bound 100 --count 100 2>&1)"
assert_contains "hitting the bound is NOT ASSESSED at capture time" "NOT ASSESSED" "$PUT"
rc 4 "and on every read thereafter" -- "$SPARK" evidence get --key pages --head abc123
GOT="$("$SPARK" evidence get --key pages --head abc123 2>&1 || true)"
assert_contains "the read names the bound it hit"      "hit its bound (100 of 100)" "$GOT"
assert_contains "partial evidence is still returned, but marked" "row" "$GOT"
assert_contains "status marks the incomplete capture"  "NOT ASSESSED (bound exceeded)" \
  "$("$SPARK" evidence status)"

printf 'row\n' | "$SPARK" evidence put --key within --head abc123 --bound 100 --count 12 >/dev/null
rc 0 "a capture inside its bound is complete" -- "$SPARK" evidence get --key within --head abc123
assert_contains "and reports as complete" "complete" "$("$SPARK" evidence status)"

# --- preflight happens before dispatch, not after generation -----------------
head -c 40000 /dev/zero | tr '\0' 'x' > "$WORK/big.txt"
rc 0 "a bundle inside budget proceeds" -- "$SPARK" evidence preflight --budget 100000 "$WORK/big.txt"
rc 2 "an oversized bundle stops before dispatch" -- "$SPARK" evidence preflight --budget 100 "$WORK/big.txt"
OVER="$("$SPARK" evidence preflight --budget 100 "$WORK/big.txt" 2>&1 || true)"
assert_contains "the refusal says when to act" "before dispatch, not after generation" "$OVER"

# Fits-or-not without a budget is an unknown, not a pass.
NB="$("$SPARK" evidence preflight "$WORK/big.txt")"
assert_contains "no budget means NOT ASSESSED, never WITHIN" "NOT ASSESSED" "$NB"
case "$NB" in *"WITHIN BUDGET"*) bad "an unbudgeted preflight must not claim it fits" ;; *) ok ;; esac

# The estimate must agree with the footprint gate's heuristic; two different
# answers about what a surface costs would make both useless.
assert_contains "the estimate uses the shared bytes-per-token heuristic" "~10000 tokens" "$NB"

J="$("$SPARK" evidence preflight --budget 100 --json "$WORK/big.txt" 2>&1 || true)"
assert_contains "json reports the verdict" '"verdict":"OVER BUDGET"' "$J"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$J" | jq empty >/dev/null 2>&1 && ok || bad "--json must emit valid JSON"
else ok; fi

# --- housekeeping ------------------------------------------------------------
rc 1 "reading a fact nobody captured fails" -- "$SPARK" evidence get --key nothing --head abc123
rc 1 "a key that escapes the store is refused" -- \
  "$SPARK" evidence put --key ../escape --head abc123
"$SPARK" evidence forget --key within >/dev/null
rc 1 "a forgotten capture is gone" -- "$SPARK" evidence get --key within --head abc123

# --- the documented model ----------------------------------------------------
DOC="$repo_root/docs/ops/context-efficiency.md"
[ -f "$DOC" ] && ok || bad "the context-efficiency model must be documented at docs/ops/context-efficiency.md"
if [ -f "$DOC" ]; then
  assert_contains "the record states what Spark cannot own" "host" "$(cat "$DOC")"
fi

# --- MUTATION CONTROL --------------------------------------------------------
# Stop noticing drift: serve every capture as if it were fresh. The staleness
# fixture must go red — reuse without invalidation is the bug, not the feature.
MUT="$WORK/plugin/bin/spark-mutant"
sed 's|^  \[ "$2" = "$3" \] && return 0$|  return 0|' "$SPARK" > "$MUT"
chmod +x "$MUT"
if ! cmp -s "$SPARK" "$MUT"; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

mgot=0
"$MUT" evidence get --key inv --head zzz999 >/dev/null 2>&1 || mgot=$?
if [ "$mgot" = "2" ]; then
  bad "MUTATION control — drift was still detected, so the fixture does not discriminate"
else ok; fi

finish
