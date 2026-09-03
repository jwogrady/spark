#!/usr/bin/env bash
# Behavioural suite for #575 — routing by capability, cost and escalation policy.
#
# Sending everything to the strongest model wastes money; sending everything to
# the cheapest risks correctness. Neither is a policy, so the tradeoff is data:
# the code resolves classes, the policy file says what a class means today.
#
# The assertions that matter most are the ones a plausible implementation gets
# wrong while still looking correct:
#
#   * the human class is not a strength tier. A DECISION REQUIRED that can be
#     escalated into an autonomous attempt is not a boundary at all, so both
#     select and escalate must stop there rather than buy a bigger model;
#   * a failed cheap attempt is still spend. Unless the benchmark carries it,
#     "start cheap and escalate" wins every argument by not counting its losses
#     -- and the fixture here is built so the two-stage route is genuinely the
#     MORE expensive one, which a cost model that ignores failures cannot see;
#   * effort is a cache invalidator, so changing it mid-conversation spends the
#     prefix it was meant to save.
#
# And no provider model id may live in the routing code: an id compiled into
# logic is product truth the day it ships and a lie the day it is retired.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "capability routing (#575)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

rc() {
  local want="$1" desc="$2" got=0; shift 3
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$want" ]; then ok; else bad "$desc (wanted rc $want, got $got)"; fi
}

# --- the policy is data ------------------------------------------------------
POL="$("$SPARK" route policy)"
for c in deterministic routine normal complex human; do
  assert_contains "the policy declares the $c class" "$c" "$POL"
done
assert_contains "the human class is not routed to a model" "(not routed to a model)" "$POL"
assert_contains "escalation is declared as rules" "one rank at a time" "$POL"

# --- the cheapest adequate class, by default ---------------------------------
REV="$("$SPARK" route select --task review)"
assert_contains "routine review takes the cheap class" "review -> routine" "$REV"
assert_contains "and states why that class is adequate" "bounded diff" "$REV"
assert_contains "strength is bought, not assumed" "bought deliberately" "$REV"

assert_contains "ordinary coding takes the middle class" "implement -> normal" \
  "$("$SPARK" route select --task implement)"
assert_contains "hard diagnosis earns the strong class" "debug -> complex" \
  "$("$SPARK" route select --task debug)"
assert_contains "mechanical work needs no model at all" "lint -> deterministic" \
  "$("$SPARK" route select --task lint)"

rc 1 "an unrouted task kind is refused, not guessed" -- "$SPARK" route select --task invent-something
assert_contains "and the refusal lists what is routable" "known kinds:" \
  "$("$SPARK" route select --task invent-something 2>&1 || true)"

# --- the human boundary is not a tier ----------------------------------------
rc 5 "a human-class task selects no model" -- "$SPARK" route select --task decision-required
HUM="$("$SPARK" route select --task decision-required 2>&1 || true)"
assert_contains "it reports the decision boundary" "DECISION REQUIRED" "$HUM"
assert_contains "and refuses to name a model"      "no model is selected" "$HUM"
assert_contains "saying why it is not escalatable" "not a capability tier to escalate past" "$HUM"

"$SPARK" route select --task release-decision >/dev/null 2>&1 || true
rc 5 "release authority is a boundary too" -- "$SPARK" route select --task release-decision

# --- escalation is a recorded rule, one rank at a time -----------------------
"$SPARK" route select --task review --run e1 >/dev/null
rc 1 "escalating without a stated cause is refused" -- "$SPARK" route escalate --run e1
assert_contains "because an unexplained escalation is just starting at the top" \
  "starting at the top one step later" "$("$SPARK" route escalate --run e1 2>&1 || true)"

ESC="$("$SPARK" route escalate --run e1 --reason "the diff spans three subsystems")"
assert_contains "escalation moves exactly one rank" "routine -> normal" "$ESC"
assert_contains "and carries the rule it followed"  "failed on scope or ambiguity" "$ESC"
assert_contains "and records the evidence"          "spans three subsystems" "$ESC"

ESC2="$("$SPARK" route escalate --run e1 --reason "still ambiguous")"
assert_contains "a second escalation reaches the strong class" "normal -> complex" "$ESC2"
rc 2 "there is nothing above the strongest routed class" -- \
  "$SPARK" route escalate --run e1 --reason "harder still"
assert_contains "and that is a human decision, not a bigger model" "not a bigger model" \
  "$("$SPARK" route escalate --run e1 --reason "harder still" 2>&1 || true)"

rc 1 "a run with no route cannot escalate" -- "$SPARK" route escalate --run never --reason x

# --- the route lands in the run's telemetry ----------------------------------
"$SPARK" route select --task review --run t1 >/dev/null
TEL="$("$SPARK" telemetry show --run t1)"
assert_contains "telemetry records the selected model" "claude-haiku" "$TEL"
assert_contains "telemetry records the effort class"   "low" "$TEL"
assert_contains "telemetry records why this route"     "bounded diff" "$TEL"
"$SPARK" route escalate --run t1 --reason "needs wider context" >/dev/null
assert_contains "an escalation is visible beside its cost" "escalated from routine" \
  "$("$SPARK" telemetry show --run t1)"

# --- effort is a cache invalidator -------------------------------------------
"$SPARK" route select --task review --run k1 >/dev/null
rc 2 "changing effort mid-conversation is refused" -- "$SPARK" route select --task debug --run k1
CH="$("$SPARK" route select --task debug --run k1 2>&1 || true)"
assert_contains "the refusal names the cache cost" "invalidates the cached prefix" "$CH"
assert_contains "and offers the deliberate path"   "--rebuild-cache" "$CH"
rc 0 "a deliberate rebuild is allowed" -- "$SPARK" route select --task debug --run k1 --rebuild-cache
rc 0 "re-selecting the same effort is not churn" -- "$SPARK" route select --task architecture --run k1

# --- cost per COMPLETED task, carrying the failed cheap attempt --------------
# The fixture is deliberately arranged so the two-stage route is the more
# expensive one. A benchmark that ignores the failed attempt reports the
# opposite, which is the whole reason this criterion exists.
"$SPARK" telemetry record --run x1 cost_usd=0.05 wall_seconds=20 >/dev/null
"$SPARK" route select --task review --run x1 >/dev/null
"$SPARK" route attempt --run x1 --outcome fail >/dev/null
"$SPARK" route escalate --run x1 --reason "cheap attempt missed the cause" >/dev/null
"$SPARK" telemetry record --run x1 cost_usd=0.40 wall_seconds=90 >/dev/null
"$SPARK" route attempt --run x1 --outcome pass >/dev/null

# The direct attempt costs exactly what the escalated one did, so the ONLY
# difference between the two routes is the wasted cheap attempt. A cost model
# that drops it reports the two routes as identical rather than merely close.
"$SPARK" telemetry record --run y1 cost_usd=0.40 wall_seconds=90 >/dev/null
"$SPARK" route select --task implement --run y1 >/dev/null
"$SPARK" route attempt --run y1 --outcome pass >/dev/null

BENCH="$("$SPARK" route benchmark)"
assert_contains "the two-stage path is reported"            "routine->normal (two-stage)" "$BENCH"
assert_contains "and carries the wasted cheap attempt"      "0.4500" "$BENCH"
assert_contains "the benchmark is per completed task"       "cost per COMPLETED task" "$BENCH"
assert_contains "a class with no success has no unit cost"  "NOT ASSESSED" "$BENCH"
assert_contains "and it says why failures must be carried"  "always looks cheaper than it was" "$BENCH"

# The decisive comparison: two-stage 0.45 against direct 0.40 per completed
# task. Cheaper per token, more expensive per result.
two="$(printf '%s' "$BENCH" | awk '/\(two-stage\)/ { print $NF }')"
one="$(printf '%s' "$BENCH" | awk '$1 == "normal" { print $NF }')"
if awk -v a="$two" -v b="$one" 'BEGIN { exit !(a > b) }'; then ok
else bad "the failed cheap attempt must make the two-stage route dearer ($two vs $one)"; fi

J="$("$SPARK" route benchmark --json)"
assert_contains "json reports the two-stage path" 'routine->normal' "$J"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$J" | jq empty >/dev/null 2>&1 && ok || bad "--json must emit valid JSON"
else ok; fi

# --- configuration, not code -------------------------------------------------
# No provider model id may appear in the routing logic. The policy file is the
# only place a model name is allowed to live.
if awk '/^# spark route —/, /^cmd_route\(\)/' "$SPARK" | grep -Eq 'claude-[a-z0-9]'; then
  bad "a provider model id is hard-coded in the routing logic"
else ok; fi

# Overriding the policy changes the route without touching a line of code.
mkdir -p "$WORK/proj/.spark"
{
  printf 'class\tcheap\t1\tA project-specific tier\n'
  printf 'model\tcheap\tsome-other-model\tminimal\n'
  printf 'route\treview\tcheap\tThis project reviews differently\n'
} > "$WORK/proj/.spark/routing-classes.tsv"
OVR="$("$SPARK" route select --task review)"
assert_contains "a project override replaces the policy" "review -> cheap" "$OVR"
assert_contains "including the model it names"           "some-other-model" "$OVR"

# --- #648: a run id becomes a filename, so a traversal id must never escape -----
# select/escalate/attempt all take --run; an id carrying a separator, traversal, or
# control character must be refused BEFORE any write, and a tracked sentinel must
# stay byte-identical.
SENT="$WORK/proj/sentinel-tracked.tsv"
printf 'keep\tme\n' > "$SENT"
sent_before="$(sha1sum "$SENT" | cut -d' ' -f1)"
# Each malformed id must be refused BECAUSE canonical validation rejected it, not
# because an intermediate directory happened to be absent — so every case asserts
# the invalid-run diagnostic, not exit status alone. The control-char and
# space-bearing ids are quoted so the loop cannot split them apart.
CTRL="$(printf 'a\tb')"
for bad_id in '../x' '../../sentinel-tracked' '/abs/x' 'a/b' '..' 'a b' "$CTRL"; do
  rc 1 "route select refuses run id '$bad_id'"   -- "$SPARK" route select   --task review --run "$bad_id"
  rc 1 "route escalate refuses run id '$bad_id'" -- "$SPARK" route escalate --run "$bad_id" --reason x
  rc 1 "route attempt refuses run id '$bad_id'"  -- "$SPARK" route attempt  --run "$bad_id" --outcome pass
  assert_contains "and names the canonical rule for '$bad_id'" "invalid run id" \
    "$("$SPARK" route select --task review --run "$bad_id" 2>&1 || true)"
done
sent_after="$(sha1sum "$SENT" | cut -d' ' -f1)"
[ "$sent_before" = "$sent_after" ] && ok || bad "a traversal run id must not modify a tracked file (#648)"
rm -f "$SENT"

# --- MUTATION CONTROL --------------------------------------------------------
# Stop carrying the failed attempt into the two-stage total. The economics
# fixture must go red: without it, starting cheap always looks cheaper.
rm -f "$WORK/proj/.spark/routing-classes.tsv"
mutant_runtime 's|total = pcost\[p\] + failcost\[f\]|total = pcost[p]|'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

MB="$("$MUT" route benchmark)"
mtwo="$(printf '%s' "$MB" | awk '/\(two-stage\)/ { print $NF }')"
if awk -v a="$mtwo" -v b="$one" 'BEGIN { exit !(a > b) }'; then
  bad "MUTATION control — the two-stage route still looked dearer, so the fixture does not discriminate"
else ok; fi

finish
