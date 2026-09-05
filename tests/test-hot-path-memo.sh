#!/usr/bin/env bash
# Behavioral suite for the per-process hot-path memoization (#722).
#
# git_root and resolve_prefs are pure within a single command yet were derived
# repeatedly (the brief header, the standards summary, every pref_get). The memo
# resolves each once per process. This suite proves two things that must both
# hold: the memo is TRANSPARENT (identical output with it on or off), and it is
# EFFECTIVE with a discriminating negative control (a run that disables it via
# SPARK_NO_MEMO=1 forks strictly more subprocesses than a run that keeps it).
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init

# A project repo with a project-tier preference file, so resolve_prefs reads all
# three tiers (defaults + operator + project) — the full merge whose repetition
# the memo removes.
repo="$WORK/proj"
make_repo "$repo"
mkdir -p "$repo/.spark"
printf '{ "stack": "python-uv", "release": "release-please" }\n' > "$repo/.spark/preferences.json"

# --- Transparency: resolve_prefs and git_root produce identical output whether
# memoized or not. Sourcing the plugin does not set __SPARK_MEMO, so a bare call
# is the unmemoized path; exporting a scratch dir is the memoized path.
prefs_unmemo="$( cd "$repo" && unset __SPARK_MEMO; . "$SPARK"; resolve_prefs )"
memo_dir="$(mktemp -d)"
prefs_memo1="$( cd "$repo" && export __SPARK_MEMO="$memo_dir"; . "$SPARK"; resolve_prefs )"
prefs_memo2="$( cd "$repo" && export __SPARK_MEMO="$memo_dir"; . "$SPARK"; resolve_prefs )"  # reads the cache
rm -rf "$memo_dir"

if [ "$prefs_unmemo" = "$prefs_memo1" ]; then ok; else bad "resolve_prefs memoized(fresh) output differs from unmemoized"; fi
if [ "$prefs_unmemo" = "$prefs_memo2" ]; then ok; else bad "resolve_prefs memoized(cache) output differs from unmemoized"; fi
# The merge actually resolved all three tiers (project override present).
case "$prefs_unmemo" in *"stack"*"python-uv"*"project"*) ok ;; *) bad "resolve_prefs did not resolve the project tier" ;; esac

root_unmemo="$( cd "$repo" && unset __SPARK_MEMO; . "$SPARK"; git_root )"
memo_dir2="$(mktemp -d)"
root_memo="$( cd "$repo" && export __SPARK_MEMO="$memo_dir2"; . "$SPARK"; git_root )"
rm -rf "$memo_dir2"
if [ "$root_unmemo" = "$root_memo" ] && [ -n "$root_unmemo" ]; then ok; else bad "git_root memoized output differs from unmemoized"; fi

# --- Effectiveness + negative control for `brief --short`, memo on (default)
# versus off (SPARK_NO_MEMO=1). The same shims are used both ways, so the only
# variable is the memo.
#
# WHAT THIS COUNTS, precisely: invocations of a FIXED tool vocabulary. It is a
# lower bound on selected tool invocations — not total process creation. It
# cannot see shell-only subshells, nor any program outside the list, nor forks a
# shimmed program makes internally. tests/bench-memo.sh --strace measures actual
# process creation; this assertion is deliberately the weaker, dependency-free
# one, and its wording must not claim more than that.
#
# The vocabulary still includes the operations the memo ITSELF introduces —
# mktemp for the scratch dir, mv to publish a miss, rm to drop a failed temp —
# because counting only the parsers it removes would let the test report a
# saving while the memo's own cost went unmeasured.
shim="$WORK/shim"
mkdir -p "$shim"
for t in awk sed grep cut tr jq git cat mv rm mkdir mktemp sort uniq head tail wc find date basename dirname; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] || continue
  { printf '#!/usr/bin/env bash\n'
    printf 'printf x >> "$SPARK_FORKLOG"\n'
    printf 'exec %s "$@"\n' "$real"; } > "$shim/$t"
  chmod +x "$shim/$t"
done

count_forks() { # <memo-env> -> echoes fork count for brief --short
  local log; log="$(mktemp)"
  ( cd "$repo" && SPARK_FORKLOG="$log" PATH="$shim:$PATH" env "$@" "$SPARK" brief --short >/dev/null 2>&1 )
  local n; n="$(wc -c < "$log" | tr -d ' ')"; rm -f "$log"; echo "$n"
}
# Captured to FILES, not command substitution: `$( )` strips trailing newlines,
# so comparing its results cannot establish byte identity — which is exactly what
# this asserts.
( cd "$repo" && "$SPARK" brief --short >"$WORK/out.on" 2>/dev/null )
( cd "$repo" && SPARK_NO_MEMO=1 "$SPARK" brief --short >"$WORK/out.off" 2>/dev/null )
forks_on="$(count_forks)"
forks_off="$(count_forks SPARK_NO_MEMO=1)"

# Transparency for the real command: identical output on and off.
if cmp -s "$WORK/out.on" "$WORK/out.off"; then ok; else bad "brief --short output is not byte-identical with the memo on and off"; fi
# Effectiveness: the memo strictly reduces invocations across the counted tool
# vocabulary — including the mktemp/mv/rm it introduces, not merely the parser
# calls it removes. This is a lower bound, not a total.
if [ "$forks_on" -lt "$forks_off" ]; then ok; else bad "memo did not reduce counted tool invocations (on=$forks_on off=$forks_off)"; fi
# Negative control sanity: disabling the memo must not itself error to zero.
if [ "$forks_off" -gt 0 ]; then ok; else bad "fork counter produced no signal (harness broken)"; fi

# --- Context safety: both cached facts depend on the current directory, so a
# single memo scope reused across repositories, or from outside a repository to
# inside one, must never hand back a stale first result. These fixtures fail
# against a process-global cache with one entry.
repoA="$WORK/repoA"; repoB="$WORK/repoB"; outside="$WORK/outside"
make_repo "$repoA"; mkdir -p "$repoA/.spark"
printf '{ "stack": "alpha-stack" }\n' > "$repoA/.spark/preferences.json"
make_repo "$repoB"; mkdir -p "$repoB/.spark"
printf '{ "stack": "beta-stack" }\n' > "$repoB/.spark/preferences.json"
mkdir -p "$outside"   # a plain directory, not a git repository

ctx="$WORK/ctx"; mkdir -p "$ctx"
memo_ctx="$(mktemp -d)"
(
  export __SPARK_MEMO="$memo_ctx"; . "$SPARK"
  cd "$repoA"; resolve_prefs > "$ctx/a.prefs"; git_root > "$ctx/a.root"
  cd "$repoB"; resolve_prefs > "$ctx/b.prefs"; git_root > "$ctx/b.root"   # same memo scope
  cd "$outside"; git_root > "$ctx/out.root"                               # outside a repo
  cd "$repoA"; git_root > "$ctx/back.root"                                # back inside
)
rm -rf "$memo_ctx"

# Cross-repository: each repo resolves its own project preference, not the first.
case "$(cat "$ctx/a.prefs")" in *alpha-stack*) ok ;; *) bad "repoA resolve_prefs lost its own stack" ;; esac
case "$(cat "$ctx/b.prefs")" in *beta-stack*)  ok ;; *) bad "repoB got stale repoA preferences from the memo" ;; esac
case "$(cat "$ctx/b.prefs")" in *alpha-stack*) bad "repoB leaked repoA's stale preferences" ;; *) ok ;; esac
# git_root is repo-specific across the same memo scope.
if [ "$(cat "$ctx/a.root")" != "$(cat "$ctx/b.root")" ] && [ -n "$(cat "$ctx/a.root")" ]; then ok; else bad "git_root returned the same/blank root for two repos"; fi
# Outside-to-inside: outside is blank, and moving inside does not reuse the blank.
if [ -z "$(cat "$ctx/out.root")" ]; then ok; else bad "git_root outside a repo should be empty"; fi
if [ -n "$(cat "$ctx/back.root")" ] && [ "$(cat "$ctx/back.root")" = "$(cat "$ctx/a.root")" ]; then ok; else bad "git_root reused the stale empty result after cd into a repo"; fi

# --- Concurrency: many subshells missing the same key at once must each end up
# reading or writing a COMPLETE entry — a reader must never observe a truncated
# cache file. A shared, non-unique temp path ($$ is inherited by every subshell)
# would let one writer rename its temp into place while another is still writing
# the same temp, exposing partial content; a writer-unique temp ($BASHPID) does
# not. This fixture races a cold cache and asserts every reader saw the whole
# value.
conc="$WORK/conc"; make_repo "$conc"; mkdir -p "$conc/.spark"
printf '{ "stack": "conc-stack", "release": "conc-rel" }\n' > "$conc/.spark/preferences.json"
# Ground truth, resolved unmemoized (a fresh source sets no __SPARK_MEMO).
exp_prefs="$( cd "$conc" && unset __SPARK_MEMO; . "$SPARK"; resolve_prefs )"
cout="$WORK/cout"; mkdir -p "$cout"
memo_conc="$(mktemp -d)"
(
  export __SPARK_MEMO="$memo_conc"; . "$SPARK"; cd "$conc"
  i=0
  while [ "$i" -lt 24 ]; do
    ( resolve_prefs > "$cout/p.$i"; git_root > "$cout/r.$i" ) &   # all miss the cold cache, then race
    i=$((i + 1))
  done
  wait
)
rm -rf "$memo_conc"
bad_p=0; bad_r=0
for i in $(seq 0 23); do
  [ "$(cat "$cout/p.$i" 2>/dev/null)" = "$exp_prefs" ] || bad_p=$((bad_p + 1))
  [ "$(cat "$cout/r.$i" 2>/dev/null)" = "$conc" ]     || bad_r=$((bad_r + 1))
done
if [ "$bad_p" -eq 0 ]; then ok; else bad "$bad_p/24 concurrent resolve_prefs readers saw truncated/incorrect prefs"; fi
if [ "$bad_r" -eq 0 ]; then ok; else bad "$bad_r/24 concurrent git_root readers saw a truncated/incorrect root"; fi

# --- Writer uniqueness, deterministically. The completeness check above is
# behavioural but probabilistic: a small payload rarely loses the race, so it can
# pass even with a shared temp. This fixture proves the property directly —
# shim `mv`, record the SOURCE path every concurrent writer renames from, and
# require them all to differ. A temp built from the inherited $$ makes every
# writer log the same path, so this fails on the unsafe implementation. The
# shim's short delay holds the rename open, guaranteeing the workers overlap and
# genuinely miss together rather than serialising behind the first write.
mvlog="$WORK/mv.log"; : > "$mvlog"
mvshim="$WORK/mvshim"; mkdir -p "$mvshim"
real_mv="$(command -v mv)"
cat > "$mvshim/mv" <<EOF
#!/usr/bin/env bash
# The call is \`mv -f SRC DST\`, so the source is the second-to-last argument;
# logging \$1 would only ever record the option.
printf '%s\n' "\${@: -2:1}" >> "$mvlog"
sleep 0.05
exec $real_mv "\$@"
EOF
chmod +x "$mvshim/mv"

memo_u="$(mktemp -d)"
(
  export __SPARK_MEMO="$memo_u"; export PATH="$mvshim:$PATH"
  . "$SPARK"; cd "$conc"
  i=0
  while [ "$i" -lt 12 ]; do ( resolve_prefs >/dev/null 2>&1 ) & i=$((i + 1)); done
  wait
)
rm -rf "$memo_u"
# `grep -c` prints 0 AND exits 1 when nothing matches, so a `|| echo 0` fallback
# would emit a second zero and the arithmetic tests below would fail on "0\n0".
mv_total="$(grep -c . "$mvlog" 2>/dev/null)" || true
mv_distinct="$(sort -u "$mvlog" 2>/dev/null | grep -c .)" || true
case "$mv_total"    in ''|*[!0-9]*) mv_total=0 ;; esac
case "$mv_distinct" in ''|*[!0-9]*) mv_distinct=0 ;; esac
# Several writers must have raced (otherwise the fixture proves nothing) ...
if [ "$mv_total" -gt 1 ]; then ok; else bad "no concurrent cache writes observed (fixture did not race; total=$mv_total)"; fi
# ... and each must have renamed from its own temp path.
if [ "$mv_distinct" -eq "$mv_total" ]; then ok; else bad "concurrent writers shared a temp path ($mv_distinct distinct of $mv_total) — writer uniqueness lost"; fi

# --- Cleanup targets only the directory this run created. The EXIT trap must not
# re-read the exported, mutable $__SPARK_MEMO: code that reassigned it would
# redirect `rm -rf` at the replacement path. A decoy directory named by the
# inherited environment must therefore survive, the run's own scratch dir must be
# removed, and the trap must delete a captured readonly path with `--`.
# The run gets its own TMPDIR, so the directory it creates is the ONLY entry
# there and can be identified exactly. Counting /tmp/tmp.* globally would let an
# unrelated process hide a leak or invent a failure, and the glob can fail
# outright under pipefail when nothing matches.
leak_probe() { # <isolated-tmpdir> <env...> -> entries left behind
  local iso="$1"; shift
  rm -rf "$iso"; mkdir -p "$iso"
  ( cd "$repo" && TMPDIR="$iso" env "$@" "$SPARK" brief --short >/dev/null 2>&1 )
  find "$iso" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' '
}
decoy="$WORK/decoy"; mkdir -p "$decoy"; : > "$decoy/keep.txt"
left="$(leak_probe "$WORK/memotmp" __SPARK_MEMO="$decoy")"
if [ -d "$decoy" ] && [ -f "$decoy/keep.txt" ]; then ok; else bad "cleanup deleted the inherited \$__SPARK_MEMO path instead of the created one"; fi
if [ "$left" -eq 0 ]; then ok; else bad "the run left $left entry(ies) in its own TMPDIR — the scratch dir it created was not removed"; fi

# The failure mode is a trap that re-reads the MUTABLE variable at exit, so the
# fixture must mutate it *after* the trap is installed — supplying it beforehand
# only proves the dispatcher overwrites its input.
#
# The mutation is injected into the sandbox dispatcher immediately after the trap
# is installed, and it runs ONLY once it has confirmed the memo directory exists.
# That confirmation is the point: an earlier version of this fixture reassigned
# the variable from a runtime module loaded by `telemetry`, and when the
# eligibility allowlist was narrowed `telemetry` stopped installing a memo at
# all — every assertion then passed while testing nothing. None of the eligible
# verbs load a runtime module, so the hook goes where the trap is.
decoy2="$WORK/decoy-runtime"; mkdir -p "$decoy2"; : > "$decoy2/keep.txt"
marker="$WORK/mutation-ran"
hook="if [ -n \"\${__SPARK_MEMO:-}\" ] \&\& [ -d \"\$__SPARK_MEMO\" ]; then : > \"$marker\"; __SPARK_MEMO=\"$decoy2\"; export __SPARK_MEMO; fi"
# Anchor on ANY exit trap, not the current one's exact text: anchoring on the
# correct form would make a regressed implementation fail to inject and the
# fixture would then fail for the wrong reason instead of catching the bug.
sed -i "/trap .*EXIT/a\\    $hook" "$WORK/plugin/bin/spark"
if grep -q "$marker" "$WORK/plugin/bin/spark"; then ok; else bad "the post-trap hook was not injected into the sandbox dispatcher"; fi

iso2="$WORK/memotmp2"; rm -rf "$iso2"; mkdir -p "$iso2"; rm -f "$marker"
( cd "$repo" && TMPDIR="$iso2" "$SPARK" brief --short >/dev/null 2>&1 )   # an ELIGIBLE verb
tel_rc=$?
if [ "$tel_rc" -eq 0 ]; then ok; else bad "the eligible verb failed (rc=$tel_rc); the mutation probe proves nothing"; fi
# The marker only appears if the memo directory existed when the hook ran, so its
# presence proves a memo and trap were actually installed before the mutation.
if [ -f "$marker" ]; then ok; else bad "no memo/trap was installed, so the post-trap mutation was never exercised"; fi
left2="$(find "$iso2" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
if [ -d "$decoy2" ] && [ -f "$decoy2/keep.txt" ]; then ok; else bad "a post-trap reassignment of \$__SPARK_MEMO redirected cleanup at the replacement path"; fi
if [ "$left2" -eq 0 ]; then ok; else bad "the run left $left2 entry(ies) in its own TMPDIR after a post-trap reassignment"; fi

# --- Source mutation inside one directory. Keying by $PWD alone would not notice
# a directory that BECOMES a repository, or a preference file written, during a
# run: the cached answer would stand for the rest of the process. Both are proven
# here to derive freshly on the path where they can happen.
#
# 1. A plain directory that becomes a repository mid-process.
mut_out="$WORK/mut"; mkdir -p "$mut_out"
cat > "$mut_out/becomes.sh" <<EOS
#!/usr/bin/env bash
. "$SPARK"
set +e            # a probe must survive a non-zero step; sourcing spark enables errexit
unset __SPARK_MEMO   # AFTER sourcing: a loaded module may set it, and this probe must be unmemoized
cd "$WORK/becomes-a-repo" || exit 1
printf 'before=[%s]\n' "\$(git_root)"
git init -q . >/dev/null 2>&1
printf 'after=[%s]\n' "\$(git_root)"
EOS
mkdir -p "$WORK/becomes-a-repo"
becomes_out="$(bash "$mut_out/becomes.sh" 2>/dev/null)"
case "$becomes_out" in *"before=[]"*) ok ;; *) bad "git_root reported a root before the directory was a repository" ;; esac
case "$becomes_out" in *"after=[]"*) bad "git_root did not notice the directory became a repository in the same \$PWD" ;; *) ok ;; esac

# 2. A preference file written mid-process, same directory.
prefmut="$WORK/prefmut"; make_repo "$prefmut"
cat > "$mut_out/prefmut.sh" <<EOS
#!/usr/bin/env bash
. "$SPARK"
set +e            # a probe must survive a non-zero step; sourcing spark enables errexit
unset __SPARK_MEMO   # AFTER sourcing: a loaded module may set it, and this probe must be unmemoized
cd "$prefmut" || exit 1
printf 'BEFORE:%s\n' "\$(resolve_prefs | tr '\\n' ' ')"
mkdir -p "$prefmut/.spark"
printf '{ "stack": "written-midrun" }\n' > "$prefmut/.spark/preferences.json"
printf 'AFTER:%s\n' "\$(resolve_prefs | tr '\\n' ' ')"
EOS
pref_out="$(bash "$mut_out/prefmut.sh" 2>/dev/null)"
before_line="$(printf '%s\n' "$pref_out" | grep '^BEFORE:')"
after_line="$(printf '%s\n' "$pref_out" | grep '^AFTER:')"
case "$before_line" in *written-midrun*) bad "preferences reported a value before the file existed" ;; *) ok ;; esac
case "$after_line"  in *written-midrun*) ok ;; *) bad "resolve_prefs did not notice a preference file written in the same \$PWD" ;; esac

# 3. The confinement itself: a verb that can create those sources must not be
#    memoized, so it keeps deriving on every call. `setup` seeds preferences;
#    `brief` only reports. Compare what each run leaves in its scratch dir by
#    counting the memo's own cache reads.
elig="$WORK/elig.log"; : > "$elig"
if grep -q 'case " brief triage governance doctor footprint' "$SPARK"; then ok; else bad "the memo eligibility allowlist is missing"; fi
if grep -q '__SPARK_MEMO_ELIGIBLE' "$SPARK"; then ok; else bad "memoization is not gated on verb eligibility"; fi
# `setup` is not on the allowlist, so it must run unmemoized.
case " $(grep -o 'case " [a-z0-9 -]*" in' "$SPARK" | head -n1) " in *" setup "*) bad "a preference-seeding verb is on the memo allowlist" ;; *) ok ;; esac

# --- The memo must not tax commands it cannot help. A verb that resolves these
# facts once or not at all still pays for the scratch directory, so eligibility
# is measured, not assumed: `help` gains processes when memoized and is therefore
# NOT eligible. This asserts the allowlist stays evidence-based — a verb added
# without measuring would make a low-work command slower.
low_forks() { # <verb> <env...> -> tool process count
  local verb="$1"; shift
  local log; log="$(mktemp)"
  ( cd "$repo" && SPARK_FORKLOG="$log" PATH="$shim:$PATH" env "$@" "$SPARK" "$verb" >/dev/null 2>&1 )
  local n; n="$(wc -c < "$log" | tr -d ' ')"; rm -f "$log"; echo "$n"
}
help_off="$(low_forks help SPARK_NO_MEMO=1)"
help_on="$(low_forks help -u SPARK_NO_MEMO)"
if [ "$help_on" -le "$help_off" ]; then ok; else bad "a low-work verb gained $(( help_on - help_off )) process(es) from the memo (off=$help_off on=$help_on) — it must not be eligible"; fi
# And the allowlist itself must not name a verb known to regress.
case "$(grep -o 'case " [a-z0-9 -]*" in' "$SPARK" | head -n1)" in
  *" help "*|*" version "*|*" state "*|*" orient "*) bad "the memo allowlist names a verb measured to regress" ;;
  *) ok ;;
esac

# --- No environment switch may widen eligibility. Such a switch is inheritable,
# and an accidental setting would restore the stale-cache defect on exactly the
# verbs excluded for being able to run `git init` or write preferences. A
# candidate is measured by patching a throwaway copy of the plugin, never by a
# variable the shipped dispatcher honours.
if grep -q 'SPARK_MEMO_FORCE' "$SPARK"; then bad "the dispatcher honours an environment switch that widens memo eligibility"; else ok; fi
force_state="$WORK/force.state"
( cd "$repo" && SPARK_MEMO_FORCE=1 SPARK_MEMO_STATE_FILE="$force_state" "$SPARK" orient >/dev/null 2>&1 ) || true
if [ "$(cat "$force_state" 2>/dev/null)" = "off" ]; then ok; else bad "an ineligible verb was memoized when SPARK_MEMO_FORCE was set (state=$(cat "$force_state" 2>/dev/null))"; fi

# An inherited effective-state variable must not let a fallback report itself as
# memoized: the dispatcher resets it before deciding.
inherit_state="$WORK/inherit.state"
( cd "$repo" && __SPARK_MEMO_STATE=on SPARK_MEMO_STATE_FILE="$inherit_state" "$SPARK" orient >/dev/null 2>&1 ) || true
if [ "$(cat "$inherit_state" 2>/dev/null)" = "off" ]; then ok; else bad "an inherited __SPARK_MEMO_STATE was reported instead of the effective state"; fi

# --- A deep but valid repository path. What this proves is the BOUNDED-KEY
# property: the key is a fixed-length digest of $PWD, so the entry filename
# stays a short constant however long $PWD is, and both cached facts still
# resolve correctly there. Built to the ACTUAL filesystem limit rather than an
# arbitrary depth, so it exercises a genuinely long path.
path_max="$(getconf PATH_MAX / 2>/dev/null || echo 4096)"
deep="$repo"
while [ "${#deep}" -lt $(( path_max - 100 )) ]; do
  next="$deep/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  mkdir -p "$next" 2>/dev/null || break        # stop at whatever this filesystem allows
  deep="$next"
done
# Boundedness is the property asserted, because it is the one provable here: the
# entry filename is a short constant regardless of $PWD's length. This test makes
# no claim about how any alternative key scheme would behave.
if [ "${#deep}" -gt 3000 ]; then ok; else bad "the deep fixture is only ${#deep} characters; too short to exercise long-path behaviour"; fi
mkdir -p "$deep/.spark"
printf '{ "stack": "deep-path-stack" }\n' > "$repo/.spark/preferences.json"
cat > "$WORK/deep.sh" <<EOS
#!/usr/bin/env bash
. "$SPARK"
set +e
export __SPARK_MEMO="\$(mktemp -d)"
cd "$deep" || exit 1
printf 'R1:%s\n' "\$(git_root)"
printf 'R2:%s\n' "\$(git_root)"
printf 'P1:%s\n' "\$(resolve_prefs | tr '\\n' ' ')"
printf 'P2:%s\n' "\$(resolve_prefs | tr '\\n' ' ')"
# The key must be BOUNDED: a short constant name however long \$PWD is.
printf 'KEYLEN:%s\n' "\$(find "\$__SPARK_MEMO" -type f -name 'gitroot.*' -printf '%f' | wc -c)"
rm -rf "\$__SPARK_MEMO"
EOS
deep_out="$(bash "$WORK/deep.sh" 2>"$WORK/deep.err")"
r1="$(printf '%s\n' "$deep_out" | grep '^R1:')"; r2="$(printf '%s\n' "$deep_out" | grep '^R2:')"
p1="$(printf '%s\n' "$deep_out" | grep '^P1:')"; p2="$(printf '%s\n' "$deep_out" | grep '^P2:')"
# A cached second call must agree with the first, and both must be right.
if [ "${r1#R1:}" = "${r2#R2:}" ] && [ "${r1#R1:}" = "$repo" ]; then ok; else bad "git_root deep-path mismatch ($r1 vs $r2)"; fi
if [ "$p1" = "${p2/P2:/P1:}" ]; then ok; else bad "resolve_prefs disagreed with itself under a deep path"; fi
case "$p1" in *deep-path-stack*) ok ;; *) bad "resolve_prefs lost the project tier under a deep path" ;; esac
# And nothing may leak to stderr — a failed redirect would surface there.
if [ ! -s "$WORK/deep.err" ]; then ok; else bad "a deep path produced stderr output: $(head -1 "$WORK/deep.err")"; fi
# Boundedness, measured: the entry name stays short for a ~4000-character $PWD.
keylen="$(printf '%s\n' "$deep_out" | grep '^KEYLEN:' | cut -d: -f2)"
if [ -n "$keylen" ] && [ "$keylen" -gt 0 ] && [ "$keylen" -lt 64 ]; then ok; else bad "the cache entry name is not bounded for a ${#deep}-character path (name length=$keylen)"; fi
# Negative control: the same deep path with the memo disabled must give the same
# answers, so a long path is never the reason memoized and unmemoized differ.
cat > "$WORK/deep-off.sh" <<EOS
#!/usr/bin/env bash
. "$SPARK"
set +e
unset __SPARK_MEMO
cd "$deep" || exit 1
printf 'R:%s\n' "\$(git_root)"
printf 'P:%s\n' "\$(resolve_prefs | tr '\\n' ' ')"
EOS
deep_off="$(bash "$WORK/deep-off.sh" 2>"$WORK/deep-off.err")"
if [ "$(printf '%s\n' "$deep_off" | grep '^R:')" = "R:${r1#R1:}" ]; then ok; else bad "deep-path git_root differs with the memo disabled"; fi
if [ "$(printf '%s\n' "$deep_off" | grep '^P:')" = "${p1/P1:/P:}" ]; then ok; else bad "deep-path resolve_prefs differs with the memo disabled"; fi
if [ ! -s "$WORK/deep-off.err" ]; then ok; else bad "a deep path produced stderr with the memo disabled"; fi

# --- A newline is legal in a directory name. The cached entry records which
# directory it belongs to, so that record must survive one: a raw $PWD written as
# the first line would make such a repository miss its own cache on every call
# and pay the derivation every time, silently.
nl_repo="$WORK/nl"$'\n'"dir"
make_repo "$nl_repo"; mkdir -p "$nl_repo/.spark"
printf '{ "stack": "newline-stack" }\n' > "$nl_repo/.spark/preferences.json"

# Results go to FILES and are compared byte-for-byte: a value containing a
# newline cannot be parsed back out of a line-oriented capture, and an earlier
# version of this fixture silently truncated the root at the embedded newline.
#
# Counting entries cannot prove a cache HIT either, because repeated misses
# overwrite the same filename. Derivation forks can: git_root shells out to git
# only on a miss, so two calls cost two git invocations if the ownership check
# never matches and one if it does. The shim counts those.
nlshim="$WORK/nlshim"; mkdir -p "$nlshim"
for t in git jq; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] || continue
  { printf '#!/usr/bin/env bash\n'
    printf 'printf x >> "$NL_DERIVE"\n'
    printf 'exec %s "$@"\n' "$real"; } > "$nlshim/$t"
  chmod +x "$nlshim/$t"
done
cat > "$WORK/nl.sh" <<EOS
#!/usr/bin/env bash
. "$SPARK"
set +e
cd "\$1" || exit 1
if [ "\$2" = on ]; then export __SPARK_MEMO="\$(mktemp -d)"; else unset __SPARK_MEMO; fi
git_root      > "\$3.r1"
git_root      > "\$3.r2"
resolve_prefs > "\$3.p1"
resolve_prefs > "\$3.p2"
[ "\$2" = on ] && rm -rf "\$__SPARK_MEMO"
exit 0
EOS
nl_run() { # <mode> <out-prefix> -> derivation fork count
  local mode="$1" pre="$2"; local log="$WORK/nl.$mode.derive"; : > "$log"
  ( NL_DERIVE="$log" PATH="$nlshim:$PATH" bash "$WORK/nl.sh" "$nl_repo" "$mode" "$pre" ) 2>"$WORK/nl.$mode.err"
  wc -c < "$log" | tr -d ' '
}
nl_on_forks="$(nl_run on  "$WORK/nlon")"
nl_off_forks="$(nl_run off "$WORK/nloff")"

# Transparency: every value identical with the memo on and off, bytes included.
nl_same=0
for part in r1 r2 p1 p2; do
  cmp -s "$WORK/nlon.$part" "$WORK/nloff.$part" || nl_same=1
done
if [ "$nl_same" -eq 0 ]; then ok; else bad "a newline-named directory produced different results with the memo on and off"; fi
# Self-consistency: the second call agrees with the first, byte-for-byte.
if cmp -s "$WORK/nlon.r1" "$WORK/nlon.r2" && cmp -s "$WORK/nlon.p1" "$WORK/nlon.p2"; then ok; else bad "repeated calls disagreed in a newline-named directory"; fi
# The value really is the newline-containing root, not a truncation of it.
if [ "$(cat "$WORK/nlon.r1")" = "$nl_repo" ]; then ok; else bad "git_root returned a truncated root for a newline-named directory"; fi
case "$(cat "$WORK/nlon.p1")" in *newline-stack*) ok ;; *) bad "resolve_prefs lost the project tier in a newline-named directory" ;; esac
# Effectiveness: the memo must actually HIT here. If the ownership record could
# not survive the newline, the second calls would re-derive and the memoized run
# would fork as many times as the unmemoized one.
if [ "$nl_on_forks" -lt "$nl_off_forks" ]; then ok; else bad "a newline-named directory never hit its own cache (derivation forks on=$nl_on_forks off=$nl_off_forks)"; fi
if [ ! -s "$WORK/nl.on.err" ] && [ ! -s "$WORK/nl.off.err" ]; then ok; else bad "a newline-named directory produced stderr"; fi

# --- A repository path that ENDS in a newline. This is the case a mid-name
# newline does not reach: command substitution strips trailing newlines, so a
# capture-based implementation silently eats the last byte of the path itself,
# not just git's delimiter. The value is compared against git's own output
# captured to a file, so the expectation is git's bytes and not this test's idea
# of them.
tn_repo="$WORK/tn"$'\n'
make_repo "$tn_repo"; mkdir -p "$tn_repo/.spark"
printf '{ "stack": "trailing-stack" }\n' > "$tn_repo/.spark/preferences.json"
( cd "$tn_repo" && git rev-parse --show-toplevel ) > "$WORK/tn.git" 2>/dev/null
cat > "$WORK/tn.sh" <<EOS
#!/usr/bin/env bash
. "$SPARK"
set +e
cd "\$1" || exit 1
if [ "\$3" = on ]; then export __SPARK_MEMO="\$(mktemp -d)"; else unset __SPARK_MEMO; fi
git_root      > "\$2.first"
git_root      > "\$2.second"
resolve_prefs > "\$2.p1"
resolve_prefs > "\$2.p2"
[ "\$3" = on ] && rm -rf "\$__SPARK_MEMO"
exit 0
EOS
bash "$WORK/tn.sh" "$tn_repo" "$WORK/tnout"    on  2>"$WORK/tn.err"
bash "$WORK/tn.sh" "$tn_repo" "$WORK/tnoffout" off 2>"$WORK/tn.off.err"
if cmp -s "$WORK/tnout.first" "$WORK/tn.git"; then ok; else bad "git_root lost bytes for a repository path ending in a newline"; fi
if cmp -s "$WORK/tnout.first" "$WORK/tnout.second"; then ok; else bad "the cached value differs from the derived one for a newline-terminated path"; fi
# resolve_prefs consumes git_root to locate .spark/preferences.json. If those
# bytes are lost the path is wrong and the PROJECT tier vanishes silently, so
# the tier is asserted directly rather than inferred from the root alone.
case "$(cat "$WORK/tnout.p1")" in *trailing-stack*) ok ;; *) bad "resolve_prefs lost the project tier for a newline-terminated repository path" ;; esac
if cmp -s "$WORK/tnout.p1" "$WORK/tnout.p2"; then ok; else bad "cached preferences differ from derived ones for a newline-terminated path"; fi
if cmp -s "$WORK/tnout.p1" "$WORK/tnoffout.p1"; then ok; else bad "preferences differ with the memo on and off for a newline-terminated path"; fi
if cmp -s "$WORK/tnout.first" "$WORK/tnoffout.first"; then ok; else bad "git_root differs with the memo on and off for a newline-terminated path"; fi
if [ ! -s "$WORK/tn.err" ] && [ ! -s "$WORK/tn.off.err" ]; then ok; else bad "a newline-terminated repository path produced stderr"; fi

# --- Independent hit proof per cached function. An aggregate fork reduction can
# hide a broken cache: either function could still be missing while the other's
# saving keeps the total lower. So each is probed alone, counting only the tool
# its own derivation shells out to — git for git_root, jq for the preference
# merge — and each must fall on its own.
onefn_shim="$WORK/onefn"; mkdir -p "$onefn_shim"
for t in git jq; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] || continue
  { printf '#!/usr/bin/env bash\n'
    printf 'printf x >> "$ONEFN_%s"\n' "$(printf '%s' "$t" | tr 'a-z' 'A-Z')"
    printf 'exec %s "$@"\n' "$real"; } > "$onefn_shim/$t"
  chmod +x "$onefn_shim/$t"
done
cat > "$WORK/onefn.sh" <<EOS
#!/usr/bin/env bash
. "$SPARK"
set +e
cd "\$1" || exit 1
if [ "\$2" = on ]; then export __SPARK_MEMO="\$(mktemp -d)"; else unset __SPARK_MEMO; fi
"\$3" >/dev/null
"\$3" >/dev/null
[ "\$2" = on ] && rm -rf "\$__SPARK_MEMO"
exit 0
EOS
onefn_count() { # <fn> <mode> <counter-var-suffix> -> forks of that tool
  local fn="$1" mode="$2" tool="$3"
  local log="$WORK/onefn.$fn.$mode.$tool"; : > "$log"
  ( ONEFN_GIT="$WORK/onefn.$fn.$mode.GIT" ONEFN_JQ="$WORK/onefn.$fn.$mode.JQ" \
    PATH="$onefn_shim:$PATH" bash "$WORK/onefn.sh" "$nl_repo" "$mode" "$fn" ) >/dev/null 2>&1
  wc -c < "$WORK/onefn.$fn.$mode.$tool" 2>/dev/null | tr -d ' '
}
: > "$WORK/onefn.git_root.on.GIT";      : > "$WORK/onefn.git_root.off.GIT"
: > "$WORK/onefn.resolve_prefs.on.JQ";  : > "$WORK/onefn.resolve_prefs.off.JQ"
gr_on="$(onefn_count git_root on GIT)";            gr_off="$(onefn_count git_root off GIT)"
rp_on="$(onefn_count resolve_prefs on JQ)";        rp_off="$(onefn_count resolve_prefs off JQ)"
if [ "${gr_on:-0}" -lt "${gr_off:-0}" ]; then ok; else bad "git_root alone did not hit its cache (git forks on=$gr_on off=$gr_off)"; fi
if [ "${rp_on:-0}" -lt "${rp_off:-0}" ]; then ok; else bad "resolve_prefs alone did not hit its cache (jq forks on=$rp_on off=$rp_off)"; fi

finish
