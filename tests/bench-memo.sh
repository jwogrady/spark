#!/usr/bin/env bash
# Reproducible measurement for the per-process hot-path memo (#722).
#
# This is the artifact behind any number quoted for the memo. It is a benchmark,
# not a suite: tests/run.sh globs test-*.sh, so this is never counted as a test.
# tests/test-hot-path-memo.sh asserts the PROPERTIES (transparency, a strict
# reduction, the negative control); this script produces the FIGURES.
#
# The workload is identical on both sides by construction — the same command,
# same fixture, same binary — with one variable: SPARK_NO_MEMO=1. That is why it
# is a fair comparison and a cross-version one is not.
#
# WHAT IS COUNTED. Process creation is counted by prepending counting shims for a
# fixed tool list. That list deliberately includes the operations the memo itself
# introduces (mktemp, cat, mv, rm) — counting only the parsers it removes would
# report a saving while total process creation stayed flat. It remains a LOWER
# BOUND: anything not on the list, and every fork a shimmed program makes
# internally, is invisible. `--strace` adds a true total via execve tracing where
# strace is available.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
SPARK="$root/plugins/spark/bin/spark"
RUNS=7
use_strace=""
VERB="brief --short"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runs)    shift; RUNS="${1:-7}" ;;
    --runs=*)  RUNS="${1#--runs=}" ;;
    --verb)    shift; VERB="${1:-brief --short}" ;;
    --verb=*)  VERB="${1#--verb=}" ;;
    --strace)  use_strace=1 ;;
    -h|--help)
      echo "usage: bench-memo.sh [--runs N] [--verb 'brief --short'] [--strace]"
      echo
      echo "  Measures one verb with the memo on and with SPARK_NO_MEMO=1:"
      echo "  median wall ms, and invocations of a fixed tool list that includes"
      echo "  the memo's own mktemp/cat/mv/rm. --strace adds total execve."
      exit 0 ;;
    *) echo "bench-memo.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

TMP="$(mktemp -d)"; trap 'rm -rf -- "$TMP"' EXIT
FIX="$TMP/fixture"; mkdir -p "$FIX"
git -C "$FIX" init -q
printf 'seed\n' > "$FIX/seed.txt"
mkdir -p "$FIX/.spark"
printf '{ "stack": "python-uv", "release": "release-please" }\n' > "$FIX/.spark/preferences.json"
git -C "$FIX" add . >/dev/null 2>&1
git -C "$FIX" -c user.email=bench@example.invalid -c user.name=Bench \
  commit -qm "chore: bench fixture" >/dev/null 2>&1

TOOLS="awk sed grep cut tr jq git cat mv rm mktemp sort uniq head tail wc find date basename dirname"
mkdir -p "$TMP/bin"
for t in $TOOLS; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] || continue
  { printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s\\n" %s >> "$BENCH_COUNT"\n' "$t"
    printf 'exec %s "$@"\n' "$real"; } > "$TMP/bin/$t"
  chmod +x "$TMP/bin/$t"
done

now_ms() { local n; n="$(date +%s%N 2>/dev/null)"
  case "$n" in *N*|'') echo "$(( $(date +%s) * 1000 ))" ;; *) echo "$(( n / 1000000 ))" ;; esac; }
median() { printf '%s\n' "$@" | LC_ALL=C sort -n | awk '{ v[NR]=$1 } END { print v[int((NR+1)/2)] }'; }

measure() { # <label> <env...>
  local label="$1"; shift
  local i s e times=() counts="$TMP/c.$label"
  : > "$counts"
  for i in $(seq 1 "$RUNS"); do
    s="$(now_ms)"
    ( cd "$FIX" && env "$@" "$SPARK" $VERB >/dev/null 2>&1 )
    e="$(now_ms)"; times+=("$(( e - s ))")
  done
  ( cd "$FIX" && BENCH_COUNT="$counts" PATH="$TMP/bin:$PATH" env "$@" "$SPARK" $VERB >/dev/null 2>&1 )
  local total parsers ex="n/a"
  total="$(wc -l < "$counts" | tr -d ' ')"
  parsers="$(awk 'BEGIN{p=" awk sed grep cut tr "}{if(index(p," "$1" "))n++}END{print n+0}' "$counts")"
  if [ -n "$use_strace" ] && command -v strace >/dev/null 2>&1; then
    local slog="$TMP/s.$label"
    ( cd "$FIX" && strace -f -qq -e trace=execve -o "$slog" env "$@" "$SPARK" $VERB >/dev/null 2>&1 )
    ex="$(grep -c 'execve(' "$slog" 2>/dev/null || echo 0)"
  fi
  printf '%-22s median %5s ms | tools %4s | parsers %4s | execve %s\n' \
    "$label" "$(median "${times[@]}")" "$total" "$parsers" "$ex"
}

echo "verb: $VERB   runs: $RUNS   fixture: a fresh single-commit repo with a project preference file"
echo "spark: $SPARK"
measure "memo OFF (control)" SPARK_NO_MEMO=1
measure "memo ON" SPARK_MEMO_BENCH=1
echo
echo "Counts are invocations of a fixed tool list (a lower bound on subprocesses,"
echo "including the memo's own mktemp/cat/mv/rm), not a full accounting."
[ -n "$use_strace" ] || echo "Run with --strace for a true total execve count where strace is available."
