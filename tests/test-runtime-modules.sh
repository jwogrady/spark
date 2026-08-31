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

# --- MUTATION CONTROL --------------------------------------------------------
# Make every verb claim it needs the execution module. The split would still
# "work" in the happy path and would have bought nothing — every invocation
# paying for every module is the coupling this was meant to remove, wearing new
# filenames. With modules absent, a core verb must then fail; if it still runs,
# this suite is not actually proving on-demand loading.
mutant_runtime "s#telemetry|budget|evidence|route|ci) printf 'execution' ;;#*) printf 'execution' ;;#"
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

rm -rf "$WORK/mutant-plugin/lib"
rc=0; "$MUT" version >/dev/null 2>&1 || rc=$?
if [ "$rc" = "0" ]; then
  bad "MUTATION control — a core verb still ran with modules absent; on-demand loading is not actually proven"
else ok; fi

finish
