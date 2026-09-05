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
# introduces (mktemp, mv, rm — a cache HIT reads with the mapfile builtin and
# forks nothing) — counting only the parsers it removes would
# report a saving while total process creation stayed flat. It remains a LOWER
# BOUND: anything not on the list, and every fork a shimmed program makes
# internally, is invisible.
#
# `--strace` adds two SEPARATE syscall counts, because they measure different
# things: `execs` counts execve, i.e. program images actually executed, and
# `procs` counts process creation — clone/clone3/fork/vfork that SUCCEEDED and
# did not carry CLONE_THREAD — which includes subshells the shell forks WITHOUT
# exec, and excludes threads and failed attempts. A shell-only subshell is invisible to
# execve and to the shims, so execve alone must never be called a total.
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
      echo "  the memo's own mktemp/mv/rm. --strace adds execs and procs counts."
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

TOOLS="awk sed grep cut tr jq git cat mv rm mkdir mktemp sort uniq head tail wc find date basename dirname"
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
off_env=(env SPARK_NO_MEMO=1)
on_env=(env -u SPARK_NO_MEMO)

# A verb outside the dispatcher's allowlist is never memoized, so "ON" would
# silently be a second control and the comparison would be off-vs-off. Measuring
# a CANDIDATE before allowlisting it is the point of this tool, so it is done
# HERE rather than through an environment switch in the shipped dispatcher: an
# env switch is inheritable and could re-enable caching for a mutating verb
# during real work. Instead the plugin is copied and the list widened in the
# copy, which cannot affect any command outside this script. Both sides then run
# the same patched binary, so the only variable is still the memo.
verb_word="${VERB%% *}"
if grep -q "case \" [a-z0-9 -]*\b${verb_word}\b[a-z0-9 -]*\" in" "$SPARK" 2>/dev/null; then
  memo_mode="eligible"
else
  memo_mode="candidate (measured in a patched throwaway copy)"
  cp -r "$root/plugins/spark" "$TMP/candidate-plugin" || die "could not copy the plugin for a candidate measurement"
  SPARK="$TMP/candidate-plugin/bin/spark"
  sed -i "s|case \" brief triage governance doctor footprint labels \" in|case \" brief triage governance doctor footprint labels ${verb_word} \" in|" "$SPARK" \
    || die "could not widen the allowlist in the throwaway copy"
  grep -q "footprint labels ${verb_word} " "$SPARK" \
    || die "the candidate verb was not added to the throwaway copy's allowlist"
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

# Every measured invocation writes its OWN state file and is checked. Asserting
# once after a warmup would let a later run whose mktemp failed contribute an
# unmemoized sample to a series still labelled memo ON.
#
# The path must be unique WITHOUT a shared counter: these helpers are themselves
# called inside command substitution, so a parent-side counter never increments —
# every run would reuse one path and a later invocation that wrote no state could
# pass on the previous run's file. $BASHPID differs per subshell, and the file is
# deleted before the run so the assertion demands a freshly created record.
state_path() { # <expected> -> a fresh, unique state file path
  local p="$TMP/state.$1.$BASHPID.$RANDOM"
  rm -f "$p"
  echo "$p"
}

one_run() { # <env-array-name> <expected-state> -> elapsed ms; aborts on failure
  local -n e_ref="$1"; local want="$2"
  local s e rc sf; sf="$(state_path "$want")"
  s="$(now_ms)"
  ( cd "$FIX" && "${e_ref[@]}" SPARK_MEMO_STATE_FILE="$sf" "$SPARK" $VERB >/dev/null 2>&1 ); rc=$?
  e="$(now_ms)"
  [ "$rc" -eq 0 ] || die "'$VERB' exited $rc under ${e_ref[*]} — refusing to report timings for a failed run"
  assert_state "$sf" "$want" "a timed $want run"
  echo "$(( e - s ))"
}

capture() { # <env-array-name> <prefix> -> records the COMPLETE observable result
  # stdout, stderr and status all count: a run that printed a warning to stderr,
  # or exited differently, did not do the same job even if stdout matched.
  local -n c_ref="$1"; local pre="$2" want="$3" rc sf; sf="$(state_path "$want")"
  ( cd "$FIX" && "${c_ref[@]}" SPARK_MEMO_STATE_FILE="$sf" "$SPARK" $VERB >"$pre.out" 2>"$pre.err" ); rc=$?
  printf '%s\n' "$rc" > "$pre.rc"
  [ "$rc" -eq 0 ] || die "'$VERB' exited $rc under ${c_ref[*]} — refusing to report figures for a failed run"
  assert_state "$sf" "$want" "the outcome-comparison $want run"
}

counts_for() { # <label> <env-array-name> -> "total parsers"; aborts on failure
  local label="$1"; local -n k_ref="$2"
  local counts="$TMP/c.$label"; : > "$counts"
  local rc sf; sf="$(state_path "$3")"
  ( cd "$FIX" && BENCH_COUNT="$counts" PATH="$TMP/bin:$PATH" "${k_ref[@]}" SPARK_MEMO_STATE_FILE="$sf" "$SPARK" $VERB >/dev/null 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] || die "'$VERB' exited $rc while counting under ${k_ref[*]}"
  assert_state "$sf" "$3" "the counted $3 run"
  printf '%s %s' "$(wc -l < "$counts" | tr -d ' ')" "$(count_parsers "$counts")"
}

# count_procs <strace-log> — processes created, which is narrower than
# "clone/fork syscalls seen" in two ways that both matter:
#
#   - a failed attempt is not a creation. A clone3 that fails with ENOSYS and
#     falls back to clone is ONE process, and strace marks the failure "= -1".
#   - a successful clone carrying CLONE_THREAD creates a THREAD sharing the
#     process, not a new process. Counting it would inflate the figure with
#     something the claim does not mean.
count_procs() {
  grep -E '(clone3?|v?fork)\(' "$1" 2>/dev/null \
    | grep -v '= -1' \
    | grep -cv 'CLONE_THREAD' || echo 0
}

syscalls_for() { # <label> <env-array-name> <expected-state> -> "execs procs"
  local label="$1"; local -n x_ref="$2"
  if [ -n "$use_strace" ] && command -v strace >/dev/null 2>&1; then
    local slog="$TMP/s.$label" rc sf; sf="$(state_path "$3")"
    ( cd "$FIX" && strace -f -qq -e trace=execve,clone,clone3,fork,vfork -o "$slog" \
        "${x_ref[@]}" SPARK_MEMO_STATE_FILE="$sf" "$SPARK" $VERB >/dev/null 2>&1 ); rc=$?
    [ "$rc" -eq 0 ] || die "'$VERB' exited $rc under strace with ${x_ref[*]}"
    assert_state "$sf" "$3" "the traced $3 run"
    printf '%s %s' \
      "$(grep -c 'execve(' "$slog" 2>/dev/null || echo 0)" \
      "$(count_procs "$slog")"
  else
    printf 'n/a n/a'
  fi
}

# Prove the process-creation metric sees a subshell the shell forks WITHOUT
# exec — precisely the kind the memo could add invisibly. If it cannot, the
# figure is not a process-creation count and must not be published as one.
syscall_selfcheck() {
  [ -n "$use_strace" ] && command -v strace >/dev/null 2>&1 || return 0
  local log="$TMP/s.selfcheck" execs procs
  strace -f -qq -e trace=execve,clone,clone3,fork,vfork -o "$log" \
    bash -c 'x=$(:); :' >/dev/null 2>&1
  execs="$(grep -c 'execve(' "$log" 2>/dev/null || echo 0)"
  local created; created="$(count_procs "$log")"
  [ "$created" -gt 0 ] || die "the process-creation metric missed a shell-only subshell (execs=$execs created=$created); it cannot be reported as process creation"

  # The two exclusions are proven against a synthetic log rather than hoping the
  # kernel exercises them: one ordinary fork, one failed clone3, one threading
  # clone. Exactly one process was created, so anything else means the metric
  # counts something other than what it is published as.
  local probe="$TMP/procs-selfcheck" got
  {
    printf 'clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|SIGCHLD) = 4242\n'
    printf 'clone3({flags=0, exit_signal=SIGCHLD}, 88) = -1 ENOSYS (Function not implemented)\n'
    printf 'clone(child_stack=0x7f00, flags=CLONE_VM|CLONE_FS|CLONE_THREAD|CLONE_SIGHAND) = 4243\n'
  } > "$probe" || die "could not write the process-metric self-check log"
  got="$(count_procs "$probe")"
  [ "$got" = "1" ] || die "the process-creation metric counts failed attempts or threads as processes: expected 1 from the self-check log, counted $got"
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
syscall_selfcheck

one_run off_env off >/dev/null
one_run on_env  on  >/dev/null

# Equal outcome BEFORE any figure is reported: a faster run that produced
# different output is not a faster run, it is a different job.
capture off_env "$TMP/res.off" off
capture on_env  "$TMP/res.on"  on
cmp -s "$TMP/res.off.out" "$TMP/res.on.out" \
  || die "'$VERB' stdout differs between memo off and on — not the same work, so no figures are reported"
cmp -s "$TMP/res.off.err" "$TMP/res.on.err" \
  || die "'$VERB' stderr differs between memo off and on — not the same work, so no figures are reported"
cmp -s "$TMP/res.off.rc" "$TMP/res.on.rc" \
  || die "'$VERB' exit status differs between memo off and on — not the same work, so no figures are reported"

off_times=() on_times=()
for i in $(seq 1 "$RUNS"); do
  if [ $(( i % 2 )) -eq 1 ]; then
    off_times+=("$(one_run off_env off)")
    on_times+=("$(one_run on_env on)")
  else
    on_times+=("$(one_run on_env on)")   # flip the order on even iterations
    off_times+=("$(one_run off_env off)")
  fi
done

read -r off_total off_parsers <<EOF
$(counts_for off off_env off)
EOF
read -r on_total on_parsers <<EOF
$(counts_for on on_env on)
EOF
read -r off_execs off_procs <<< "$(syscalls_for off off_env off)"
read -r on_execs on_procs  <<< "$(syscalls_for on on_env on)"

printf '%-22s median %5s ms | tools %4s | parsers %4s | execs %s | procs %s\n' \
  "memo OFF (control)" "$(median "${off_times[@]}")" "$off_total" "$off_parsers" "$off_execs" "$off_procs"
printf '%-22s median %5s ms | tools %4s | parsers %4s | execs %s | procs %s\n' \
  "memo ON" "$(median "${on_times[@]}")" "$on_total" "$on_parsers" "$on_execs" "$on_procs"
echo
echo "raw wall samples (ms), in collection order:"
echo "  OFF: ${off_times[*]}"
echo "  ON : ${on_times[*]}"
echo
echo "Counts are invocations of a fixed tool list (a lower bound on subprocesses,"
echo "including the memo's own mktemp/mv/rm), not a full accounting."
[ -n "$use_strace" ] || echo "Run with --strace to add execs (program images) and procs (process creation, subshells included)."
