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

# assert_eq <desc> <want> <got> — exact equality. Twenty-three suites carried this
# body byte-for-byte; one definition keeps the failure message identical everywhere.
assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

finish() {
  echo "  $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

# assert_flat_contains_all <file> <desc> <ere>... — every ERE must appear
# (case-insensitive) in the file, matched against whitespace-collapsed prose
# (runs of any whitespace become one space) so a hard-wrapped, indented line
# can't split a phrase the guard pins. Shared by the prose-contract guards
# (test-knowledge-promotion.sh, test-lifecycle-promotion.sh) so the technique
# has one definition instead of a byte-for-byte copy per suite.
assert_flat_contains_all() {
  local f="$1" desc="$2" m flat; shift 2
  [ -f "$f" ] || { bad "$desc: $(basename "$f") missing"; return; }
  flat="$(tr -s '[:space:]' ' ' < "$f")"
  for m in "$@"; do
    printf '%s' "$flat" | grep -qiE -- "$m" \
      || { bad "$desc: missing /$m/ in $(basename "$f")"; return; }
  done
  ok
}

# assert_flat_lacks <file> <desc> <ere> — the ERE must NOT appear
# (case-insensitive) in the whitespace-collapsed file.
assert_flat_lacks() {
  local f="$1" desc="$2" m="$3" flat
  [ -f "$f" ] || { bad "$desc: $(basename "$f") missing"; return; }
  flat="$(tr -s '[:space:]' ' ' < "$f")"
  if printf '%s' "$flat" | grep -qiE -- "$m"; then
    bad "$desc: forbidden /$m/ found in $(basename "$f")"
  else
    ok
  fi
}

# assert_no_constellation_names <root> — none of the shipped plugins under
# <root>/plugins/*/ may hard-code a constellation/organization name (ADR-0028
# provider neutrality). One definition shared across every suite that checks
# this, so the pattern list can't drift between callers.
assert_no_constellation_names() {
  local root="$1" desc="${2:-provider neutrality}"
  if grep -rniE 'cosmos|status26' "$root"/plugins/*/ >/dev/null 2>&1; then
    bad "$desc: a shipped plugin hard-codes a constellation name (cosmos/status26)"
  else
    ok
  fi
}

# gov_iss <num> <milestone> <label>... — the issue/label record pair
# gov_issue_rows consumes. A label name is never joined into a delimited
# scalar: it may contain a comma as easily as a space, so each one is its own
# record. Tests build rows through this rather than hand-writing the shape,
# which is what keeps the shape in one place.
gov_iss() {
  local num="$1" ms="$2"; shift 2
  printf 'issue\t%s\t%s\n' "$num" "$ms"
  local l
  for l in "$@"; do printf 'label\t%s\t%s\n' "$num" "$l"; done
}

# --- the release-gate capture, as GitHub actually answers it ---------------
#
# Fixtures build the GraphQL RESPONSE and let the binary's own --jq shape it.
# Handing the projection pre-shaped records would leave the shaping — where a
# label name, a parent link or an issue's state is either preserved or lost —
# untested, and a replica passes while the original is wrong. The shape lives
# here, once, because `governance` and `next` now read the same capture and a
# second copy of it in a second suite is how they would drift apart again.

# gate_iss <number> <milestone|-> <parent|-> <state> <subs-csv|-> <label>... —
# one issue node, in whatever state it is in. Closed issues are part of the
# answer: a gate does not stop being the gate the moment it closes.
#
# ONE NODE FOR BOTH CAPTURES. The release-gate capture and the milestone
# snapshot read the same issues for different questions, and a fixture that
# described them differently could make the two verbs disagree in a way no
# repository can — which is the opposite of what these suites exist to prove.
gate_iss() {
  local n="$1" ms="$2" par="$3" st="$4" subs="$5"; shift 5
  local labs="" l nodes="" x cnt=0
  for l in "$@"; do labs="${labs:+$labs,}$(printf '{"name":%s}' "$(printf '%s' "$l" | jq -R .)")"; done
  if [ "$subs" != "-" ]; then
    for x in $(printf '%s' "$subs" | tr ',' ' '); do
      nodes="${nodes:+$nodes,}{\"number\":$x}"; cnt=$((cnt+1))
    done
  fi
  printf '{"number":%s,"state":"%s","milestone":%s,"parent":%s,"subIssues":{"totalCount":%s,"pageInfo":{"hasNextPage":%s},"nodes":[%s]},"labels":{"pageInfo":{"hasNextPage":%s},"nodes":[%s]}}' \
    "$n" "$st" \
    "$([ "$ms" = "-" ] && echo null || printf '{"title":%s}' "$(printf '%s' "$ms" | jq -R .)")" \
    "$([ "$par" = "-" ] && echo null || printf '{"number":%s}' "$par")" \
    "$cnt" "${SUBS_TRUNCATED:-false}" "$nodes" \
    "${LABELS_TRUNCATED:-false}" "$labs"
}

# gate_mil <title> <issue-nodes> — one OPEN milestone. It is a node in its own
# right, so a milestone holding no issues at all is still a milestone judged.
gate_mil() {
  printf '{"title":%s,"issues":{"pageInfo":{"hasNextPage":%s},"nodes":[%s]}}' \
    "$(printf '%s' "$1" | jq -R .)" "${ISSUES_TRUNCATED:-false}" "$2"
}

# gate_cap <milestone-nodes> [marked-issue-nodes] — the whole response. The
# second half is what GitHub answers for the marker label repository-wide, so a
# marked issue legitimately arrives TWICE and must still be one issue.
gate_cap() {
  printf '{"data":{"repository":{"milestones":{"pageInfo":{"hasNextPage":%s},"nodes":[%s]},"marked":{"pageInfo":{"hasNextPage":%s},"nodes":[%s]}}}}' \
    "${MILESTONES_TRUNCATED:-false}" "$1" "${MARKED_TRUNCATED:-false}" "${2:-}"
}

# mutant_runtime <sed-expression> — a COMPLETE copy of the plugin whose shipped
# shell sources have had the expression applied, echoing the path to its
# bin/spark and setting MUTANT_CHANGED to 1 when something actually changed.
#
# The mutation is applied wherever the shipped source lives — the dispatcher and
# every runtime module. A control that edited only bin/spark used to work by
# accident and stopped discriminating the moment a domain moved into lib/,
# silently passing while proving nothing. That is exactly the divergence between
# a focused component and the assembled runtime that these controls exist to
# catch, so the helper closes it rather than each suite having to remember.
MUTANT_PATH=""
MUTANT_CHANGED=0
MUTANT_TMPDIR=""
mutant_runtime() {
  local expr="$1" src dest f rel orig
  # Prefer the sandbox copy. Suites that source the runtime directly never call
  # sandbox_init, so fall back to the real plugin rather than requiring every
  # caller to sandbox purely to own a mutant.
  if [ -n "${WORK:-}" ] && [ -d "${WORK:-}/plugin" ]; then
    src="$WORK/plugin"; dest="$WORK/mutant-plugin"
  else
    if [ -z "$MUTANT_TMPDIR" ]; then
      MUTANT_TMPDIR="$(mktemp -d)"
      trap 'rm -rf "$MUTANT_TMPDIR"' EXIT
    fi
    src="$repo_root/plugins/spark"; dest="$MUTANT_TMPDIR/mutant-plugin"
  fi
  rm -rf "$dest"
  cp -r "$src" "$dest"
  MUTANT_CHANGED=0
  # Hooks are shipped source too: a control that mutated only bin/ and lib/
  # would silently stop discriminating for anything enforced in a hook.
  for f in "$dest/bin/spark" "$dest"/lib/*.sh "$dest"/hooks/*.sh; do
    [ -f "$f" ] || continue
    rel="${f#"$dest"/}"
    orig="$src/$rel"
    sed -i "$expr" "$f" 2>/dev/null || true
    cmp -s "$f" "$orig" || MUTANT_CHANGED=1
  done
  chmod +x "$dest/bin/spark" 2>/dev/null || true
  # Returned through globals, not stdout: a command substitution would run this
  # in a subshell and MUTANT_CHANGED would never reach the caller.
  MUTANT_PATH="$dest/bin/spark"
}

# gh_stub_prelude — the lines a `gh` stub begins with, printed for a suite to
# embed after its shebang. It parses the caller's --jq into GH_JQ and defines
# answer_json <json>, which applies that jq exactly as gh would (or prints the
# JSON verbatim when none was passed). A stub built on it answers with the JSON
# GitHub returns, so the production jq program is exercised on every call; a
# stub that prints pre-shaped rows agrees with any jq, including a broken one.
gh_stub_prelude() {
  cat <<'PRELUDE'
GH_JQ=""; __prev=""
for __a in "$@"; do [ "$__prev" = "--jq" ] && GH_JQ="$__a"; __prev="$__a"; done
answer_json() { if [ -n "$GH_JQ" ]; then printf '%s' "$1" | jq -r "$GH_JQ"; else printf '%s\n' "$1"; fi; }
PRELUDE
}
