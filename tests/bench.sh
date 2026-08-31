#!/usr/bin/env bash
# Spark hot-path baseline (#609).
#
# Wall time alone hides the costs worth finding. A command can be quick and
# still fork awk four hundred times, re-read the same file per item, or reach
# the network twice. So this records more than elapsed time.
#
# WHAT THE COUNTS ACTUALLY ARE. They are produced by prepending counting shims
# to PATH for a fixed list of binaries, so each is an invocation count for THAT
# LIST — not a complete accounting:
#
#   shimmed    invocations of the shimmed binaries only. A LOWER BOUND on
#              subprocesses: anything not on the list, and every fork a shimmed
#              program makes internally, is invisible here.
#   parsers    the awk/sed/grep/cut/tr subset of the above. The repeated-parsing
#              signal, and the one these names measure most honestly.
#   gh         invocations of the gh binary. NOT a count of HTTP requests: one
#              invocation may make several, and a request issued by anything
#              other than gh is not counted at all.
#
# They are named for what they count. A number called "external processes" or
# "remote requests" would claim an accounting this mechanism does not perform,
# and a baseline that overstates its own precision is worse than a coarse one,
# because the next person optimises against it.
#
# OFFLINE VERSUS LIVE. A path that invokes gh depends on the network and on live
# GitHub state, so its wall time is NOT reproducible and is reported as
# observational. Each path's mode is determined by measurement — whether it
# actually invoked gh — rather than by a hand-maintained list that could drift.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
SPARK="$root/plugins/spark/bin/spark"

RUNS=3
as_json=""
with_remote=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json)        as_json=1 ;;
    --runs)        shift; RUNS="${1:-3}" ;;
    --runs=*)      RUNS="${1#--runs=}" ;;
    --with-remote) with_remote=1 ;;
    -h|--help)
      echo "usage: bench.sh [--json] [--runs N] [--with-remote]"
      echo
      echo "  Measures Spark hot paths: median wall ms, plus invocation counts for"
      echo "  a fixed list of shimmed binaries (a lower bound, not a full"
      echo "  subprocess accounting) and for gh (invocations, not HTTP requests)."
      echo
      echo "  Paths that invoke gh depend on live GitHub and are reported as"
      echo "  observational: their wall time is not a reproducible baseline."
      echo "  --with-remote additionally measures next and course, which exist"
      echo "  only to query GitHub."
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  if [ "$#" -gt 0 ]; then shift; fi
done

SHIMMED="awk sed grep cut tr sort head tail git gh jq cksum wc find basename dirname"
PARSERS=" awk sed grep cut tr "
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

# Resolve real paths BEFORE the shims shadow them.
for t in $SHIMMED; do
  real="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$real" ] || continue
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s\\n" %s >> "$BENCH_COUNT"\n' "$t"
    printf 'exec %s "$@"\n' "$real"
  } > "$TMP/bin/$t"
  chmod +x "$TMP/bin/$t"
done

now_ms() {
  local n; n="$(date +%s%N 2>/dev/null)"
  case "$n" in
    *N*|'') echo "$(( $(date +%s) * 1000 ))" ;;
    *) echo "$(( n / 1000000 ))" ;;
  esac
}

median() { printf '%s\n' "$@" | LC_ALL=C sort -n | awk '{ v[NR]=$1 } END { print v[int((NR+1)/2)] }'; }

rows=""
measure() { # measure <label> <command...>
  local label="$1"; shift
  local i s e times=() ms

  for i in $(seq 1 "$RUNS"); do
    s="$(now_ms)"; "$@" >/dev/null 2>&1; e="$(now_ms)"
    times+=("$(( e - s ))")
  done
  ms="$(median "${times[@]}")"

  # One extra instrumented run for the counts.
  local counts="$TMP/counts.$label"
  : > "$counts"
  BENCH_COUNT="$counts" PATH="$TMP/bin:$PATH" "$@" >/dev/null 2>&1
  local shimmed par ghn mode
  shimmed="$(wc -l < "$counts" | tr -d ' ')"
  par="$(awk -v p="$PARSERS" '{ if (index(p, " " $1 " ")) n++ } END { print n+0 }' "$counts")"
  ghn="$(awk '$1 == "gh" { n++ } END { print n+0 }' "$counts")"
  # Mode is measured, not declared: a path that reached gh is live, whatever it
  # was assumed to be.
  if [ "$ghn" -gt 0 ]; then mode="live"; else mode="offline"; fi

  rows="${rows}${label}	${ms}	${shimmed}	${par}	${ghn}	${mode}
"
}

measure "brief --short"       "$SPARK" brief --short
measure "footprint"           "$SPARK" footprint
measure "governance"          "$SPARK" governance
measure "governance validate" "$SPARK" governance validate
measure "doctor"              "$SPARK" doctor
if [ -n "$with_remote" ]; then
  measure "next"   "$SPARK" next
  measure "course" "$SPARK" course
fi

env_line="$(uname -s) $(uname -r) | bash ${BASH_VERSION%%(*} | runs=$RUNS"

if [ -n "$as_json" ]; then
  printf '{"environment":"%s",' "$env_line"
  printf '"counts_are":{"shimmed":"invocations of a fixed shim list; a lower bound on subprocesses",'
  printf '"parsers":"awk/sed/grep/cut/tr invocations","gh":"gh invocations, not HTTP requests"},'
  printf '"paths":['
  printf '%s' "$rows" | awk -F'\t' '
    NF { printf "%s{\"path\":\"%s\",\"ms\":%s,\"shimmed_external_invocations\":%s,\"parser_invocations\":%s,\"gh_invocations\":%s,\"mode\":\"%s\"}",
         (n++ ? "," : ""), $1, $2, $3, $4, $5, $6 }'
  printf ']}\n'
  exit 0
fi

echo "Spark hot-path baseline"
echo "  $env_line"
echo
printf '  %-22s %8s %10s %9s %6s %9s\n' path "ms" shimmed parsers gh mode
printf '%s' "$rows" | awk -F'\t' 'NF { printf "  %-22s %8s %10s %9s %6s %9s\n", $1, $2, $3, $4, $5, $6 }'
echo
echo "shimmed = invocations of a fixed shim list — a LOWER BOUND on subprocesses,"
echo "not a full accounting. parsers = the awk/sed/grep/cut/tr subset. gh = gh"
echo "invocations, NOT HTTP requests: one invocation may make several."
echo
echo "mode=live means the path invoked gh, so its wall time depends on the network"
echo "and on live GitHub state. Live rows are observational, not a reproducible"
echo "baseline; compare offline rows against the same machine, never across hosts."
