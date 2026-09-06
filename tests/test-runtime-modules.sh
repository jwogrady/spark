#!/usr/bin/env bash
# Behavioural suite for #614 — runtime shell modules.
#
# The risk decomposition creates is not that a file split fails loudly. It is
# that it succeeds cosmetically: the same coupling under new filenames, or a
# second copy of a primitive so a module can stand alone. Both look tidy and
# both are worse than the monolith.
#
# So this pins the properties that make the split real:
#
#   * a core verb runs with lib/ ENTIRELY ABSENT — proving the dispatcher does
#     not depend on modules it did not ask for, which is the only external way
#     to observe that loading is genuinely on demand;
#   * a module verb reports the missing module clearly instead of dying with an
#     unbound function;
#   * sourcing the runtime exposes the whole API, because the suites source it
#     and must not have to know which file owns which function;
#   * NO function is defined in both the dispatcher and a module, and no module
#     restates a shared primitive — one canonical implementation per fact was
#     the point, and a module that copied `red` to stand alone would have
#     quietly traded the monolith for a duplication problem;
#   * every verb the table ships still dispatches.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "runtime modules (#614)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

LIB="$WORK/plugin/lib"
[ -d "$LIB" ] && ok || bad "the runtime module directory must exist at plugins/spark/lib"
[ -f "$LIB/execution.sh" ] && ok || bad "the execution module must exist"

# --- one canonical implementation per fact -----------------------------------
# The decisive structural assertion: a name defined in a module must not also be
# defined in the dispatcher.
defs_of() { grep -oE '^[a-z_][a-z0-9_]*\(\)' "$1" | tr -d '()' | LC_ALL=C sort -u; }
core_defs="$(defs_of "$WORK/plugin/bin/spark")"
mod_defs="$(cat "$LIB"/*.sh | grep -oE '^[a-z_][a-z0-9_]*\(\)' | tr -d '()' | LC_ALL=C sort -u)"
dupes="$(printf '%s\n' "$core_defs" | LC_ALL=C comm -12 - <(printf '%s\n' "$mod_defs"))"
if [ -z "$dupes" ]; then ok
else bad "a function is defined in BOTH the dispatcher and a module: $(printf '%s' "$dupes" | tr '\n' ' ')"; fi

# A module must not restate a shared primitive to stand alone.
for prim in red green yellow git_root check_json usage; do
  if printf '%s\n' "$mod_defs" | grep -qx "$prim"; then
    bad "module restates the shared primitive '$prim' instead of using the canonical one"
  else ok; fi
done

# --- loading is genuinely on demand ------------------------------------------
# Observable only from outside: with lib/ removed, a core verb must still work.
NOLIB="$WORK/plugin-nolib"
rm -rf "$NOLIB"; cp -r "$WORK/plugin" "$NOLIB"; rm -rf "$NOLIB/lib"

out="$("$NOLIB/bin/spark" version 2>&1)"; rc=$?
[ "$rc" = "0" ] && ok || bad "a core verb must run with no modules present (rc $rc)"
assert_contains "and still answer correctly" "spark" "$out"

rc=0; "$NOLIB/bin/spark" doctor >/dev/null 2>&1 || rc=$?
[ "$rc" = "0" ] && ok || bad "doctor must run with no modules present (rc $rc)"

# A module verb, by contrast, must fail with a legible reason rather than an
# unbound-function error.
rc=0
err="$("$NOLIB/bin/spark" telemetry show --run x 2>&1)" || rc=$?
[ "$rc" != "0" ] && ok || bad "a module verb must fail when its module is missing"
assert_contains "and name the missing module" "runtime module 'execution' is missing" "$err"
case "$err" in
  *"command not found"*) bad "a missing module must not surface as a command-not-found" ;;
  *) ok ;;
esac

# --- the module verbs work when the module is present ------------------------
"$SPARK" telemetry record --run m1 tool_calls=3 >/dev/null 2>&1 && ok || bad "telemetry must work via its module"
assert_contains "and its output is unchanged" "tool calls" "$("$SPARK" telemetry show --run m1)"
"$SPARK" budget declare --run m1 --convergence green >/dev/null 2>&1 && ok || bad "budget must work via its module"
"$SPARK" route policy >/dev/null 2>&1 && ok || bad "route must work via its module"
"$SPARK" evidence status >/dev/null 2>&1 && ok || bad "evidence must work via its module"

# --- sourcing exposes the whole API ------------------------------------------
# The suites source the runtime; making them know which file owns which function
# would export an implementation detail as a test contract.
probe="$(bash -c '. "$1" >/dev/null 2>&1
  for f in tm_valid_run bg_over ev_drift route_rows ci_verdict red git_root; do
    if declare -F "$f" >/dev/null 2>&1; then printf "%s=yes\n" "$f"; else printf "%s=NO\n" "$f"; fi
  done' _ "$SPARK")"
for f in tm_valid_run bg_over ev_drift route_rows ci_verdict red git_root; do
  case "$probe" in
    *"$f=yes"*) ok ;;
    *) bad "sourcing the runtime must define $f" ;;
  esac
done

# --- a broken runtime must not source "successfully" -------------------------
# Sourcing that half-loads leaves a partial API while reporting success, and the
# caller then fails somewhere unrelated with a missing-function error that says
# nothing about the cause. Three ways it can be broken, all of which once passed
# silently:
src_rc() { # src_rc <plugin-dir>
  local rc=0
  bash -c '. "$1" >/dev/null 2>&1' _ "$1/bin/spark" || rc=$?
  printf '%s' "$rc"
}

INTACT="$WORK/plugin"
[ "$(src_rc "$INTACT")" = "0" ] && ok || bad "sourcing an intact runtime must succeed"

GONE="$WORK/plugin-modgone"
rm -rf "$GONE"; cp -r "$WORK/plugin" "$GONE"; rm -f "$GONE/lib/execution.sh"
[ "$(src_rc "$GONE")" != "0" ] && ok || bad "sourcing must fail when a declared module is missing"

# The declared module list matters here: a glob over a removed lib/ matches
# nothing and would report success, so an absent runtime would look like a
# runtime that simply has no modules.
NOLIBDIR="$WORK/plugin-nolibdir"
rm -rf "$NOLIBDIR"; cp -r "$WORK/plugin" "$NOLIBDIR"; rm -rf "$NOLIBDIR/lib"
[ "$(src_rc "$NOLIBDIR")" != "0" ] && ok || bad "sourcing must fail when the module directory is absent"

# A module that exists but cannot parse is the subtlest case: the file is found,
# sourcing it fails, and marking it loaded anyway would hide that entirely.
BROKEN="$WORK/plugin-broken"
rm -rf "$BROKEN"; cp -r "$WORK/plugin" "$BROKEN"
printf '\nthis is ( not valid bash\n' >> "$BROKEN/lib/execution.sh"
[ "$(src_rc "$BROKEN")" != "0" ] && ok || bad "sourcing must fail when a module has a syntax error"

err="$(bash -c '. "$1"' _ "$GONE/bin/spark" 2>&1 || true)"
assert_contains "and the failure names the incomplete API" "runtime could not be fully loaded" "$err"

# --- the public CLI is unchanged ---------------------------------------------
# Every verb the table ships must still dispatch. A verb that lost its handler
# in the move would otherwise only be found by a user.
verbs="$(sed -n "/^VERBS='/,/^help|usage|/p" "$WORK/plugin/bin/spark" | sed "s/^VERBS='//" | cut -d'|' -f1)"
missing=""
while IFS= read -r v; do
  [ -n "$v" ] || continue
  "$SPARK" "$v" --help >/dev/null 2>&1 || "$SPARK" "$v" -h >/dev/null 2>&1 || true
  if "$SPARK" "$v" --help 2>&1 | grep -q 'unknown command'; then missing="$missing $v"; fi
done <<EOF
$verbs
EOF
if [ -z "$missing" ]; then ok
else bad "verbs no longer dispatch:$missing"; fi

# --- the source actually loaded is observable --------------------------------
# The reduction has to be visible in the run record, not only to a person
# reading a PR. Opt-in through SPARK_RUN_ID.
loaded_of() { # loaded_of <run>
  "$SPARK" telemetry show --run "$1" --json 2>/dev/null \
    | sed -n 's/.*"runtime_modules_loaded":"\([^"]*\)".*/\1/p'
}
bytes_of() { # bytes_of <run>
  "$SPARK" telemetry show --run "$1" --json 2>/dev/null \
    | sed -n 's/.*"runtime_peak_source_bytes":\([0-9]*\).*/\1/p'
}

SPARK_RUN_ID=rt-core   "$SPARK" version        >/dev/null 2>&1
SPARK_RUN_ID=rt-exec   "$SPARK" telemetry list >/dev/null 2>&1
SPARK_RUN_ID=rt-plan   "$SPARK" plan --help    >/dev/null 2>&1

assert_contains "a core verb loads no module"        "none"      "$(loaded_of rt-core)"
assert_contains "a module verb names what it loaded" "execution" "$(loaded_of rt-exec)"
assert_contains "plan loads the planning module"     "planning"  "$(loaded_of rt-plan)"

# The figure is MECHANICALLY DERIVED, not estimated: it must equal the sum of
# the files actually read, to the byte. An approximation here would invite the
# token-cost claim this field deliberately refuses to make.
disp_b="$(wc -c < "$WORK/plugin/bin/spark" | tr -d ' ')"
exec_b="$(wc -c < "$WORK/plugin/lib/execution.sh" | tr -d ' ')"
plan_b="$(wc -c < "$WORK/plugin/lib/planning.sh" | tr -d ' ')"

[ "$(bytes_of rt-core)" = "$disp_b" ] && ok \
  || bad "a core verb's source bytes must equal the dispatcher exactly (got $(bytes_of rt-core), want $disp_b)"
[ "$(bytes_of rt-exec)" = "$(( disp_b + exec_b ))" ] && ok \
  || bad "an execution verb's bytes must equal dispatcher+execution exactly"
[ "$(bytes_of rt-plan)" = "$(( disp_b + plan_b ))" ] && ok \
  || bad "plan's bytes must equal dispatcher+planning exactly"

# The reduction itself: a core verb reads strictly less than a module verb.
if [ "$(bytes_of rt-core)" -lt "$(bytes_of rt-exec)" ]; then ok
else bad "a core verb must load strictly less source than a module verb"; fi

# No token figure is derived from bytes anywhere: that is a different
# measurement, and a constant divisor would dress a guess as a cost claim.
if grep -qE 'runtime_source_bytes.*/ *[0-9]+|tokens.*runtime_source_bytes' "$WORK/plugin/bin/spark"; then
  bad "source bytes must not be converted into a token estimate"
else ok; fi

# Recording goes through this same executable, so the guard against infinite
# recursion is load-bearing rather than decorative.
if grep -q 'SPARK_RECORDING' "$WORK/plugin/bin/spark"; then ok
else bad "the nested-recording guard must exist"; fi

# --- #670: the run summary is per-RUN, not the last command in the run --------
# A run invokes Spark many times. The #667 fields were last-write-wins, so a
# later lightweight verb erased that an earlier verb loaded a module and shrank
# the peak footprint. The footprint is now an append-only per-invocation log and
# the summary is DERIVED from it: the distinct module union and the peak bytes,
# neither of which a trailing command can undo.
plan_peak_b="$(( disp_b + plan_b ))"

# plan then a trailing core verb, under ONE run id — the exact reproduction.
SPARK_RUN_ID=rt-multi "$SPARK" plan --help >/dev/null 2>&1
SPARK_RUN_ID=rt-multi "$SPARK" version     >/dev/null 2>&1
assert_contains "#670: a trailing core verb cannot erase an earlier module load" "planning" "$(loaded_of rt-multi)"
[ "$(bytes_of rt-multi)" = "$plan_peak_b" ] && ok \
  || bad "#670: a trailing lightweight verb must not shrink the peak bytes (got $(bytes_of rt-multi), want $plan_peak_b)"

# The reverse order proves the summary is order-independent, not merely first- or
# last-write.
SPARK_RUN_ID=rt-rev "$SPARK" version     >/dev/null 2>&1
SPARK_RUN_ID=rt-rev "$SPARK" plan --help >/dev/null 2>&1
assert_contains "#670: the derived module set is order-independent" "planning" "$(loaded_of rt-rev)"
[ "$(bytes_of rt-rev)" = "$plan_peak_b" ] && ok \
  || bad "#670: the derived peak is order-independent (got $(bytes_of rt-rev), want $plan_peak_b)"

# Two differently-loaded module verbs in one run: the summary is their DISTINCT
# UNION, sorted — not just the last one.
SPARK_RUN_ID=rt-union "$SPARK" plan --help    >/dev/null 2>&1
SPARK_RUN_ID=rt-union "$SPARK" telemetry list  >/dev/null 2>&1
[ "$(loaded_of rt-union)" = "execution,planning" ] && ok \
  || bad "#670: a run's modules must be the distinct union of every invocation (got '$(loaded_of rt-union)')"

# The authority is an append-only log that retains EVERY invocation: three
# commands, three lines, none overwritten.
mlog="$WORK/proj/.spark/telemetry/rt-union.footprint"
[ -f "$mlog" ] && ok || bad "#670: the append-only footprint log must exist at .spark/telemetry/<run>.footprint"
[ "$(wc -l < "$mlog" | tr -d ' ')" = 2 ] && ok \
  || bad "#670: the append-only log must retain one line per invocation, never overwrite"

# MUTATION CONTROL (#670): disable the read-time derivation and the erased
# last-write projection must resurface — proving the derivation, not the stored
# .tsv, is what keeps the run summary truthful.
mutant_runtime 's#\[ -f "$flog" \] || return 1#return 1#'
[ "$MUTANT_CHANGED" = "1" ] && ok || bad "#670 MUTATION changed nothing — it proves nothing"
mut_loaded="$("$MUTANT_PATH" telemetry show --run rt-multi --json 2>/dev/null \
  | sed -n 's/.*"runtime_modules_loaded":"\([^"]*\)".*/\1/p')"
[ "$mut_loaded" = "none" ] && ok \
  || bad "#670 MUTATION — with derivation disabled the erased last-write value must resurface (got '$mut_loaded')"

# --- MUTATION CONTROL --------------------------------------------------------
# Make every verb claim it needs the execution module. The split would still
# "work" in the happy path and would have bought nothing — every invocation
# paying for every module is the coupling this was meant to remove, wearing new
# filenames. With modules absent, a core verb must then fail; if it still runs,
# this suite is not actually proving on-demand loading.
# Anchored on the SHAPE of the execution case arm, not on the verb list inside
# it. Listing the verbs meant that adding one (#726's merge-authority) silently
# stopped the substitution from matching, so the control mutated nothing and
# failed for the wrong reason instead of proving anything.
mutant_runtime "s#^\( *\)[a-z0-9|_-]*) printf 'execution' ;;#\1*) printf 'execution' ;;#"
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

rm -rf "$WORK/mutant-plugin/lib"
rc=0; "$MUT" version >/dev/null 2>&1 || rc=$?
if [ "$rc" = "0" ]; then
  bad "MUTATION control — a core verb still ran with modules absent; on-demand loading is not actually proven"
else ok; fi

finish
