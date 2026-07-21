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

# --- repo-shape fixtures for the orientation classifier (issue #183). These
# live only in lib.sh because the classifier suite (test-orient.sh) and the
# first-run integration work (#199) both build on the same five shapes; one
# definition keeps the two suites from drifting apart.

# fixture_clean_dir <dir> — an empty directory, no version control. Classifies
# as new: there is nothing to preserve.
fixture_clean_dir() {
  mkdir -p "$1"
}

# fixture_empty_git <dir> — an initialized repo with zero commits and no files.
# Classifies as new: git is present but the project has not started.
fixture_empty_git() {
  mkdir -p "$1"
  git -C "$1" init -q
}

# fixture_mature_repo <dir> — an established project: tracked source, a
# manifest, CI, docs, and real commit history. Classifies as existing.
fixture_mature_repo() {
  local dir="$1"
  mkdir -p "$dir/src" "$dir/.github/workflows" "$dir/docs"
  git -C "$dir" init -q
  echo "def main(): pass" > "$dir/src/app.py"
  echo '{"name":"mature"}' > "$dir/package.json"
  printf 'name: ci\non: [push]\n' > "$dir/.github/workflows/ci.yml"
  echo "# Mature" > "$dir/README.md"
  echo "# Docs" > "$dir/docs/index.md"
  ( cd "$dir" && git add . && git commit -qm "chore: initial import" \
    && echo "print('hi')" >> src/app.py && git add . && git commit -qm "feat: add greeting" )
}

# fixture_imported_repo <dir> — a project brought in from elsewhere: tracked
# source, a manifest, and history, but never armed with Spark (no
# CLAUDE.md/AGENTS.md/.spark). Classifies as existing — its decisions stand.
fixture_imported_repo() {
  local dir="$1"
  mkdir -p "$dir/lib"
  git -C "$dir" init -q
  echo "module.exports = {}" > "$dir/lib/index.js"
  echo '{"name":"imported"}' > "$dir/package.json"
  ( cd "$dir" && git add . && git commit -qm "chore: import project" )
}

# fixture_ambiguous_repo <dir> — real content (source + manifest) but no
# version control at all: Spark cannot tell whether to adopt it or scaffold
# fresh, so it must ask. Classifies as ambiguous.
fixture_ambiguous_repo() {
  local dir="$1"
  mkdir -p "$dir"
  echo "print('scratch')" > "$dir/main.py"
  echo '{"name":"scratch"}' > "$dir/package.json"
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
