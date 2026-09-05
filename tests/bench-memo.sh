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

die() { printf 'bench-memo.sh: %s\n' "$1" >&2; exit 1; }

# A run count that is zero, negative or non-numeric would collect no samples and
# then print an empty median as though it were a measurement.
case "$RUNS" in
  ''|*[!0-9]*) die "--runs must be a positive integer, got '$RUNS'" ;;
esac
[ "$RUNS" -ge 1 ] || die "--runs must be at least 1, got '$RUNS'"

# Every setup step is checked. This script deliberately does not set errexit (a
# measured command is allowed to be slow, not silently fatal), so an unchecked
# failure here would leave it benchmarking a directory that is not the fixture it
# claims to measure.
TMP="$(mktemp -d)" || die "mktemp failed; cannot build the fixture"
trap 'rm -rf -- "$TMP"' EXIT
FIX="$TMP/fixture"
mkdir -p "$FIX" || die "could not create the fixture directory"
git -C "$FIX" init -q || die "git init failed in the fixture"
printf 'seed\n' > "$FIX/seed.txt" || die "could not write the fixture seed file"
mkdir -p "$FIX/.spark" || die "could not create the fixture .spark directory"
printf '{ "stack": "python-uv", "release": "release-please" }\n' > "$FIX/.spark/preferences.json" \
  || die "could not write the fixture preference file"
git -C "$FIX" add . >/dev/null 2>&1 || die "git add failed in the fixture"
git -C "$FIX" -c user.email=bench@example.invalid -c user.name=Bench \
  commit -qm "chore: bench fixture" >/dev/null 2>&1 || die "git commit failed in the fixture"
# The claim is "a fresh single-commit repo with a project preference file" — verify it.
[ "$(git -C "$FIX" rev-list --count HEAD 2>/dev/null)" = "1" ] \
  || die "the fixture is not the single-commit repository this script claims to measure"
[ -f "$FIX/.spark/preferences.json" ] || die "the fixture lost its project preference file"

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

# The two configurations. ON must explicitly REMOVE SPARK_NO_MEMO from the
# environment: setting some other variable leaves an inherited SPARK_NO_MEMO in
# force, and both sides would then run unmemoized while the report claimed a
# comparison. `env -u` is the only thing that guarantees the ON side is on.
off_env=(env SPARK_NO_MEMO=1 SPARK_MEMO_STATE_FILE="$TMP/state.off")
on_env=(env -u SPARK_NO_MEMO SPARK_MEMO_STATE_FILE="$TMP/state.on")

# A verb outside the dispatcher's allowlist is never memoized, so "ON" would
# silently be a second control and the comparison would be off-vs-off. Measuring
# a CANDIDATE is the whole point of doing this before allowlisting it, so the
# candidate case is supported explicitly and labelled, not faked.
verb_word="${VERB%% *}"
if grep -q "case \" [a-z0-9 -]*\b${verb_word}\b[a-z0-9 -]*\" in" "$SPARK" 2>/dev/null; then
  memo_mode="eligible"
else
  memo_mode="candidate (forced for measurement)"
  on_env=(env -u SPARK_NO_MEMO SPARK_MEMO_FORCE=1 SPARK_MEMO_STATE_FILE="$TMP/state.on")
fi

assert_state() { # <file> <expected> <label>
  local f="$1" want="$2" label="$3" got
  [ -f "$f" ] || die "$label did not report its memo state — cannot prove the configuration under test"
  got="$(cat "$f")"
  [ "$got" = "$want" ] || die "$label ran with memo '$got', expected '$want' — refusing to report an unverified comparison"
}

# count_parsers <logfile> — how many logged invocations are parsers. The
# vocabulary is passed IN with -v rather than embedded, so the program can never
# accidentally read a shell variable, and `$1` is unambiguously awk's field.
count_parsers() {
  awk -v vocab=" awk sed grep cut tr " \
    '{ if (index(vocab, " " $1 " ")) n++ } END { print n + 0 }' "$1"
}

# Prove the parser metric actually discriminates before any figure depends on it:
# a known log with five parser entries and six non-parser entries must count 5.
# A metric that silently reported 0, or counted everything, would otherwise be
# indistinguishable from a real result.
parser_selfcheck() {
  local probe="$TMP/parser-selfcheck" got
  printf 'awk\nsed\ngrep\ncut\ntr\ngit\ncat\nmv\nrm\nmktemp\njq\n' > "$probe" \
    || die "could not write the parser self-check log"
  got="$(count_parsers "$probe")"
  [ "$got" = "5" ] || die "parser metric is broken: expected 5 parser entries in the self-check log, counted $got"
  printf 'x\n' > "$probe"                      # no parser entries at all
  got="$(count_parsers "$probe")"
  [ "$got" = "0" ] || die "parser metric counts non-parser entries: expected 0, counted $got"
}

one_run() { # <env-array-name> -> elapsed ms; aborts if the command fails
  local -n e_ref="$1"
  local s e rc
  s="$(now_ms)"
  ( cd "$FIX" && "${e_ref[@]}" "$SPARK" $VERB >/dev/null 2>&1 ); rc=$?
  e="$(now_ms)"
  [ "$rc" -eq 0 ] || die "'$VERB' exited $rc under ${e_ref[*]} — refusing to report timings for a failed run"
  echo "$(( e - s ))"
}

capture() { # <env-array-name> <prefix> -> records the COMPLETE observable result
  # stdout, stderr and status all count: a run that printed a warning to stderr,
  # or exited differently, did not do the same job even if stdout matched.
  local -n c_ref="$1"; local pre="$2" rc
  ( cd "$FIX" && "${c_ref[@]}" "$SPARK" $VERB >"$pre.out" 2>"$pre.err" ); rc=$?
  printf '%s\n' "$rc" > "$pre.rc"
  [ "$rc" -eq 0 ] || die "'$VERB' exited $rc under ${c_ref[*]} — refusing to report figures for a failed run"
}

counts_for() { # <label> <env-array-name> -> "total parsers"; aborts on failure
  local label="$1"; local -n k_ref="$2"
  local counts="$TMP/c.$label"; : > "$counts"
  local rc
  ( cd "$FIX" && BENCH_COUNT="$counts" PATH="$TMP/bin:$PATH" "${k_ref[@]}" "$SPARK" $VERB >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] || die "'$VERB' exited $rc while counting under ${k_ref[*]}"
  printf '%s %s' "$(wc -l < "$counts" | tr -d ' ')" "$(count_parsers "$counts")"
}

execve_for() { # <label> <env-array-name> -> total execve, or n/a
  local label="$1"; local -n x_ref="$2"
  if [ -n "$use_strace" ] && command -v strace >/dev/null 2>&1; then
    local slog="$TMP/s.$label" rc
    ( cd "$FIX" && strace -f -qq -e trace=execve -o "$slog" "${x_ref[@]}" "$SPARK" $VERB >/dev/null 2>&1 ); rc=$?
    [ "$rc" -eq 0 ] || die "'$VERB' exited $rc under strace with ${x_ref[*]}"
    grep -c 'execve(' "$slog" 2>/dev/null || echo 0
  else
    echo "n/a"
  fi
}

echo "verb:    $VERB"
echo "runs:    $RUNS paired, interleaved (OFF/ON alternate within each iteration)"
echo "fixture: a fresh single-commit repo with a project preference file, built by this script"
echo "spark:   $SPARK"
echo "commit:  $(git -C "$root" rev-parse HEAD 2>/dev/null || echo 'not a git checkout')"
echo "runtime: $(uname -sr) | bash ${BASH_VERSION}"
echo "memo:    $memo_mode"
echo

# Warm the filesystem and process caches for BOTH configurations before timing,
# then alternate them inside each iteration. Timing all of one side and then all
# of the other hands the second side a warmed environment and turns ordering into
# an apparent result.
parser_selfcheck

one_run off_env >/dev/null
one_run on_env  >/dev/null

# Equal outcome BEFORE any figure is reported: a faster run that produced
# different output is not a faster run, it is a different job.
capture off_env "$TMP/res.off"
capture on_env  "$TMP/res.on"
# Prove the two configurations really were off and on before anything is reported.
assert_state "$TMP/state.off" off "the control run"
assert_state "$TMP/state.on"  on  "the memo-on run"
cmp -s "$TMP/res.off.out" "$TMP/res.on.out" \
  || die "'$VERB' stdout differs between memo off and on — not the same work, so no figures are reported"
cmp -s "$TMP/res.off.err" "$TMP/res.on.err" \
  || die "'$VERB' stderr differs between memo off and on — not the same work, so no figures are reported"
cmp -s "$TMP/res.off.rc" "$TMP/res.on.rc" \
  || die "'$VERB' exit status differs between memo off and on — not the same work, so no figures are reported"

off_times=() on_times=()
for i in $(seq 1 "$RUNS"); do
  if [ $(( i % 2 )) -eq 1 ]; then
    off_times+=("$(one_run off_env)")
    on_times+=("$(one_run on_env)")
  else
    on_times+=("$(one_run on_env)")   # flip the order on even iterations
    off_times+=("$(one_run off_env)")
  fi
done

read -r off_total off_parsers <<EOF
$(counts_for off off_env)
EOF
read -r on_total on_parsers <<EOF
$(counts_for on on_env)
EOF
off_ex="$(execve_for off off_env)"
on_ex="$(execve_for on on_env)"

printf '%-22s median %5s ms | tools %4s | parsers %4s | execve %s\n' \
  "memo OFF (control)" "$(median "${off_times[@]}")" "$off_total" "$off_parsers" "$off_ex"
printf '%-22s median %5s ms | tools %4s | parsers %4s | execve %s\n' \
  "memo ON" "$(median "${on_times[@]}")" "$on_total" "$on_parsers" "$on_ex"
echo
echo "raw wall samples (ms), in collection order:"
echo "  OFF: ${off_times[*]}"
echo "  ON : ${on_times[*]}"
echo
echo "Counts are invocations of a fixed tool list (a lower bound on subprocesses,"
echo "including the memo's own mktemp/cat/mv/rm), not a full accounting."
[ -n "$use_strace" ] || echo "Run with --strace for a true total execve count where strace is available."
