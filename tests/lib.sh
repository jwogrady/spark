# Shared helpers for the behavioral suites. Source, don't execute.
#
# Every suite works in a throwaway sandbox: a private copy of the plugin, a
# private HOME/XDG so operator-tier config never leaks in or out, and temp
# git repos. Nothing in the checkout is ever mutated.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sandbox_init() {
  WORK="$(mktemp -d)"
  trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
  cp -r "$repo_root/plugins/spark" "$WORK/plugin"
  SPARK="$WORK/plugin/bin/spark"
  export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
  mkdir -p "$XDG_CONFIG_HOME"
  export GIT_CONFIG_NOSYSTEM=1
  git config --global user.email "test@example.invalid"
  git config --global user.name "Spark Tests"
  git config --global init.defaultBranch master
}

make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  ( cd "$dir" && echo "seed" > seed.txt && git add . && git commit -qm "chore: seed" )
}

pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

# assert <desc> <want-exit> <got-exit> [extra-cond-result]
assert_rc() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" -eq "$want" ]; then ok; else bad "$desc — want exit $want, got $got"; fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) ok ;;
    *) bad "$desc — output lacks '$needle'" ;;
  esac
}

finish() {
  echo "  $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}
