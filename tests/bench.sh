#!/usr/bin/env bash
# Spark hot-path baseline (#609).
#
# Wall time alone hides the interesting costs. A command can be fast and still be
# wasteful — forking awk four hundred times, re-parsing the same model on every
# call, or making the same remote request twice. So this records four dimensions
# per path:
#
#   wall ms      median of N runs, not one anecdotal sample
#   externals    total external processes spawned (the subprocess cost)
#   parsers      awk/sed/grep/cut/tr invocations (the repeated-parsing cost)
#   remote       gh invocations (the remote-request cost)
#
# The last three are counted by prepending a directory of counting shims to PATH.
# Each shim records its invocation and then execs the real binary, so the
# measured command behaves exactly as it normally would — the numbers describe a
# real run, not an instrumented approximation of one.
#
# Baselines are machine-dependent by nature. This prints the environment it
# measured so a later comparison is against a stated machine rather than an
# implied one, and so a number that moved can be told from a machine that did.
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
      echo "  Measures Spark hot paths: wall ms, external processes, parser"
      echo "  invocations, and remote requests. --with-remote adds paths that"
      echo "  need GitHub and are therefore not reproducible offline."
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
  # date +%s%N is GNU; fall back to seconds when it is unavailable so the tool
  # still reports something honest on a host without it.
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
  local ext par rem
  ext="$(wc -l < "$counts" | tr -d ' ')"
  par="$(awk -v p="$PARSERS" '{ if (index(p, " " $1 " ")) n++ } END { print n+0 }' "$counts")"
  rem="$(awk '$1 == "gh" { n++ } END { print n+0 }' "$counts")"

  rows="${rows}${label}	${ms}	${ext}	${par}	${rem}
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
  printf '{"environment":"%s","paths":[' "$env_line"
  printf '%s' "$rows" | awk -F'\t' '
    NF { printf "%s{\"path\":\"%s\",\"ms\":%s,\"externals\":%s,\"parsers\":%s,\"remote\":%s}",
         (n++ ? "," : ""), $1, $2, $3, $4, $5 }'
  printf ']}\n'
  exit 0
fi

echo "Spark hot-path baseline"
echo "  $env_line"
echo
printf '  %-22s %8s %11s %9s %8s\n' path "ms" externals parsers remote
printf '%s' "$rows" | awk -F'\t' 'NF { printf "  %-22s %8s %11s %9s %8s\n", $1, $2, $3, $4, $5 }'
echo
echo "externals = external processes spawned; parsers = awk/sed/grep/cut/tr;"
echo "remote = gh invocations. Wall time is machine-dependent — compare against"
echo "a baseline from the same machine, never against another host's numbers."
