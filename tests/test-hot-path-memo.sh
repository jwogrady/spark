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

# --- Effectiveness + negative control: count subprocess forks for `brief
# --short` with the memo on (default) and off (SPARK_NO_MEMO=1). Shims prepend a
# counting wrapper for a fixed tool list; the same shims are used both ways, so
# the only variable is the memo. On must fork strictly fewer than off.
shim="$WORK/shim"
mkdir -p "$shim"
for t in awk sed grep cut tr jq git; do
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
out_on="$( cd "$repo" && "$SPARK" brief --short 2>/dev/null )"
out_off="$( cd "$repo" && SPARK_NO_MEMO=1 "$SPARK" brief --short 2>/dev/null )"
forks_on="$(count_forks)"
forks_off="$(count_forks SPARK_NO_MEMO=1)"

# Transparency for the real command: identical output on and off.
if [ "$out_on" = "$out_off" ]; then ok; else bad "brief --short output changed with the memo (should be transparent)"; fi
# Effectiveness: memo strictly reduces forks.
if [ "$forks_on" -lt "$forks_off" ]; then ok; else bad "memo did not reduce forks (on=$forks_on off=$forks_off)"; fi
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
mv_total="$(grep -c . "$mvlog" 2>/dev/null || echo 0)"
mv_distinct="$(sort -u "$mvlog" 2>/dev/null | grep -c . || echo 0)"
# Several writers must have raced (otherwise the fixture proves nothing) ...
if [ "$mv_total" -gt 1 ]; then ok; else bad "no concurrent cache writes observed (fixture did not race; total=$mv_total)"; fi
# ... and each must have renamed from its own temp path.
if [ "$mv_distinct" -eq "$mv_total" ]; then ok; else bad "concurrent writers shared a temp path ($mv_distinct distinct of $mv_total) — writer uniqueness lost"; fi

finish
