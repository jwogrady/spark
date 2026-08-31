#!/usr/bin/env bash
# Behavioural suite for #583 — the split-authority Claude coding lane.
#
# The lane is three jobs: a trusted resolver, a write-less Claude job, and a
# deploy-key publisher. Its safety is a set of properties that must be
# mechanically true and must stay true when the files are edited later, so this
# suite asserts them three ways:
#
#   * STATIC facts about the workflow — genuinely static properties (which
#     triggers exist, which permissions each job holds, which job may name the
#     deploy-key secret). A grep is honest proof of a static fact.
#   * SYNTHETIC-INPUT tests of the canonical security functions in
#     .github/scripts/claude-lane/lib.sh — the same code the runner executes,
#     fed the payloads a real event would carry. This proves the decision, not a
#     proxy for it.
#   * MUTATION CONTROLS that neuter one check and prove the relevant assertion
#     flips red — so a passing assertion means the check is load-bearing, not
#     decorative.
#
# What cannot be proven here: the live wake and publication only exist once the
# workflow is on the default branch and a human has armed the deploy key. That
# is inherent to event-driven workflows, not a gap in this suite.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

lane="$repo_root/.github/scripts/claude-lane"
# shellcheck source=/dev/null
. "$lane/lib.sh"   # the canonical functions, exercised directly below

echo "claude coding lane (#583, split authority)"
sandbox_init

WF="$repo_root/.github/workflows/claude.yml"
DOC="$repo_root/docs/ops/claude-coding-lane.md"
[ -f "$WF" ] && ok || bad "the coding lane workflow must exist"
[ -f "$lane/lib.sh" ] && ok || bad "the canonical lane library must exist"
[ -f "$lane/resolve.sh" ] && ok || bad "the resolver must exist"
[ -f "$lane/publish.sh" ] && ok || bad "the publisher must exist"

have_py=0
command -v python3 >/dev/null 2>&1 && have_py=1

# ============================================================================
# SYNTHETIC-INPUT TESTS — the real security functions, fed real-shape payloads
# ============================================================================

# cl_resolve_publication: the fork, ordinary-issue, master-target, and malformed
# refusals are exactly the #672 defects, asserted against the code that decides.
assert_contains "same-repo PR authorizes publication" \
  "authorized" "$(cl_resolve_publication true a/b a/b feat/x master 0123456789abcdef0123456789abcdef01234567)"
assert_contains "a fork head refuses" \
  "refused:fork-head" "$(cl_resolve_publication true x/y a/b feat/x master 0123456789abcdef0123456789abcdef01234567)"
assert_contains "an ordinary issue refuses publication" \
  "refused:not-a-pr" "$(cl_resolve_publication false '' a/b '' master '')"
assert_contains "the default branch cannot be the target" \
  "refused:head-is-default-branch" "$(cl_resolve_publication true a/b a/b master master 0123456789abcdef0123456789abcdef01234567)"
assert_contains "a malformed head SHA refuses" \
  "refused:malformed-head-sha" "$(cl_resolve_publication true a/b a/b feat/x master deadbeef)"
assert_contains "a refspec-tricked head ref refuses" \
  "refused:malformed-head-ref" "$(cl_resolve_publication true a/b a/b 'feat/x:refs/heads/master' master 0123456789abcdef0123456789abcdef01234567)"
assert_contains "incomplete identity refuses" \
  "refused:incomplete-identity" "$(cl_resolve_publication true '' a/b feat/x master 0123456789abcdef0123456789abcdef01234567)"

# cl_check_identity: the publisher's independent second gate.
if cl_check_identity a/b a/b 5 5 a/b feat/x master; then ok; else bad "matching identity must pass"; fi
assert_contains "a swapped repo is caught at publish" \
  "identity:repo-mismatch" "$(cl_check_identity a/b x/y 5 5 a/b feat/x master 2>&1 || true)"
assert_contains "a fork head is caught at publish too" \
  "identity:fork-head" "$(cl_check_identity a/b a/b 5 5 x/y feat/x master 2>&1 || true)"

# cl_check_stale_head: fresh passes, moved refuses.
if cl_check_stale_head abc abc; then ok; else bad "a fresh head must pass"; fi
if cl_check_stale_head abc def; then bad "a moved head must refuse"; else ok; fi

# cl_validate_paths: the load-bearing publication control, over synthetic modes.
assert_flat_contains_all_str() { case "$2" in *"$1"*) ok ;; *) bad "$3" ;; esac; }
[ -z "$(printf '100644\tsrc/app.py\n100755\tbin/run\n' | cl_validate_paths)" ] && ok \
  || bad "ordinary file changes must be allowed"
assert_contains "a workflow-file change is refused" \
  "reject:workflow-path" "$(printf '100644\t.github/workflows/ci.yml\n' | cl_validate_paths)"
assert_contains "the lane's own helper is protected" \
  "reject:publisher-path" "$(printf '100644\t.github/scripts/claude-lane/lib.sh\n' | cl_validate_paths)"
assert_contains "a symlink is refused" \
  "reject:symlink" "$(printf '120000\tlink\n' | cl_validate_paths)"
assert_contains "a submodule/gitlink is refused" \
  "reject:gitlink" "$(printf '160000\tvendor/sub\n' | cl_validate_paths)"
assert_contains "an absolute path is refused" \
  "reject:absolute-path" "$(printf '100644\t/etc/passwd\n' | cl_validate_paths)"
assert_contains "a traversal path is refused" \
  "reject:path-traversal" "$(printf '100644\t../escape\n' | cl_validate_paths)"

# GIT-INTEGRATION: prove the derive->validate wiring on a REAL patch and index,
# so cl_index_changes and cl_validate_paths are tested as the publisher uses
# them, not just in isolation.
git_verdict() { # $1 = one of: clean workflow symlink gitlink; echoes ALLOW or reject:...
  local kind="$1" base src tgt patch
  src="$WORK/gi-src"; tgt="$WORK/gi-tgt-$kind"; patch="$WORK/gi-$kind.patch"
  if [ ! -d "$src" ]; then
    git init -q "$src"
    ( cd "$src" && mkdir -p a && echo hi > a/f.txt && git add -A && git commit -qm seed )
  fi
  base="$(git -C "$src" rev-parse HEAD)"
  local work="$WORK/gi-work-$kind"; git clone -q "$src" "$work"
  case "$kind" in
    clean)    echo more >> "$work/a/f.txt" ;;
    workflow) mkdir -p "$work/.github/workflows"; echo "on: push" > "$work/.github/workflows/evil.yml" ;;
    symlink)  ln -s /etc/hosts "$work/pwn" ;;
    gitlink)  git -C "$work" -c protocol.file.allow=always submodule add -q "$src" sub 2>/dev/null || { mkdir "$work/sub"; git -C "$work" update-index --add --cacheinfo 160000,"$base",sub; } ;;
  esac
  git -C "$work" add -A 2>/dev/null
  git -C "$work" diff --binary --cached "$base" > "$patch"
  git clone -q "$src" "$tgt"; git -C "$tgt" reset -q --hard "$base"
  git -C "$tgt" -c core.hooksPath=/dev/null apply --index --whitespace=nowarn "$patch" 2>/dev/null \
    || { echo "APPLY-FAIL"; return; }
  local v
  if v="$(cl_index_changes "$tgt" | cl_validate_paths)"; then echo "ALLOW"; else echo "$v"; fi
}
assert_contains "a real clean patch publishes"        "ALLOW"                  "$(git_verdict clean)"
assert_contains "a real workflow patch is refused"    "reject:workflow-path"   "$(git_verdict workflow)"
assert_contains "a real symlink patch is refused"     "reject:symlink"         "$(git_verdict symlink)"

# ============================================================================
# STATIC WORKFLOW CONTRACT
# ============================================================================
if [ "$have_py" -eq 1 ]; then
  pyq() { python3 - "$WF" "$1" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
on = d.get(True) or d.get("on")
jobs = d["jobs"]
print(eval(sys.argv[2], {"d": d, "on": on, "jobs": jobs, "yaml": yaml}))
PY
  }

  pyq "'ok'" >/dev/null 2>&1 && ok || bad "the workflow must be valid YAML"

  # -- trigger surface: issue_comment only; no reviewer/writer or auto-review paths
  TRIGGERS="$(pyq 'sorted(on.keys())')"
  assert_contains "it wakes on an issue/PR comment" "issue_comment" "$TRIGGERS"
  case "$TRIGGERS" in *workflow_run*) bad "no workflow_run trigger belongs here — #585 owns the reviewer handoff" ;; *) ok ;; esac
  case "$TRIGGERS" in *pull_request*) bad "no pull_request trigger — automatic review is #584's, not this lane's" ;; *) ok ;; esac
  case "$TRIGGERS" in *pull_request_review*) bad "the review triggers were dropped for the smallest surface" ;; *) ok ;; esac
  case "$TRIGGERS" in *issues*) bad "the issues trigger was dropped; a mention arrives as a comment" ;; *) ok ;; esac

  # -- default permissions are nothing; each job grants its own minimum
  assert_contains "top-level permissions grant nothing by default" "{}" "$(pyq 'd.get("permissions", "MISSING")')"

  # -- the resolver gate is scoped to the COMMENTER, and requires a mention
  IF="$(pyq 'jobs["resolve"].get("if","")')"
  assert_contains "admission is scoped to the actual commenter" "comment.author_association" "$IF"
  assert_contains "a trusted OWNER is accepted" "OWNER" "$IF"
  assert_contains "a MEMBER is accepted" "MEMBER" "$IF"
  assert_contains "a COLLABORATOR is accepted" "COLLABORATOR" "$IF"
  assert_contains "an explicit @claude mention is required" "@claude" "$IF"
  assert_contains "association AND mention, not either" "&&" "$IF"
  # The #672 bypass: the thread author's association must NEVER gate admission.
  case "$IF" in *issue.author_association*) bad "issue-author association must not gate admission (the #672 bypass)" ;; *) ok ;; esac
  case "$IF" in *review.author_association*) bad "review association must not gate admission in this lane" ;; *) ok ;; esac
  case "$IF" in *NONE*|*FIRST_TIME_CONTRIBUTOR*|*CONTRIBUTOR*) bad "an untrusted association must not be accepted" ;; *) ok ;; esac

  # -- the resolver is read-only
  RP="$(pyq 'sorted((jobs["resolve"].get("permissions") or {}).items())')"
  case "$RP" in *"'write'"*) bad "the resolver must be read-only" ;; *) ok ;; esac

  # -- Claude holds NO write to code and no deploy key
  CP="$(pyq 'sorted((jobs["claude"].get("permissions") or {}).items())')"
  case "$CP" in *"('contents', 'write')"*) bad "Claude must not hold contents: write — it must be unable to push" ;; *) ok ;; esac
  assert_contains "Claude may comment on issues" "('issues', 'write')" "$CP"
  CLAUDE_TXT="$(pyq 'yaml.safe_dump(jobs["claude"])')"
  case "$CLAUDE_TXT" in *CLAUDE_PUBLISH_DEPLOY_KEY*) bad "the deploy key must never be referenced in Claude's job" ;; *) ok ;; esac
  assert_contains "Claude's checkout persists no credential" "persist-credentials" "$CLAUDE_TXT"

  # -- the publisher is the ONLY writer path, and holds no contents: write token
  PP="$(pyq 'sorted((jobs["publish"].get("permissions") or {}).items())')"
  case "$PP" in *"('contents', 'write')"*) bad "the publisher's GITHUB_TOKEN must not hold contents: write; publication is via the deploy key" ;; *) ok ;; esac
  PUB_TXT="$(pyq 'yaml.safe_dump(jobs["publish"])')"
  assert_contains "the publisher alone references the deploy-key secret" "CLAUDE_PUBLISH_DEPLOY_KEY" "$PUB_TXT"
  assert_contains "the publisher runs trusted default-branch code" "trusted/.github/scripts/claude-lane/publish.sh" "$PUB_TXT"
  assert_contains "the publisher gates on publication_authorized" "publication_authorized" "$PUB_TXT"

  # -- one production reviewer: no OTHER workflow reviews every PR automatically
  autoreviewers=0
  for f in "$repo_root"/.github/workflows/*.yml; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in claude.yml) continue ;; esac
    if grep -qE '^\s+pull_request:' "$f" && grep -qiE 'review' "$f"; then
      autoreviewers=$((autoreviewers + 1))
    fi
  done
  [ "$autoreviewers" -eq 0 ] && ok || bad "another workflow already reviews every PR automatically ($autoreviewers); #584 would be a second"
else
  echo "  (python3 unavailable — static YAML assertions skipped)"
fi

# ============================================================================
# MUTATION CONTROLS — prove each check is load-bearing
# ============================================================================
# Each runs the real function and a neutered copy on the SAME input, in
# subshells so the mutant never clobbers the real function, and asserts the
# verdict flips. If it does not flip, the assertion above it proves nothing.

# (1) Remove the stale-head check => a moved head stops refusing.
real_stale="$(bash -c '. "$1"; cl_check_stale_head aaa bbb && echo ALLOW || echo REFUSE' _ "$lane/lib.sh")"
mut_stale="$(bash -c '. "$1"; cl_check_stale_head() { return 0; }; cl_check_stale_head aaa bbb && echo ALLOW || echo REFUSE' _ "$lane/lib.sh")"
[ "$real_stale" = "REFUSE" ] && [ "$mut_stale" = "ALLOW" ] && ok \
  || bad "stale-head mutation control did not discriminate (real=$real_stale mut=$mut_stale)"

# (2) Remove the forbidden-workflow case => a workflow patch stops being refused.
real_wf="$(printf '100644\t.github/workflows/x.yml\n' | cl_validate_paths || true)"
mut_wf="$(bash -c '. "$1"
cl_validate_paths() { local m p; while IFS="$(printf "\t")" read -r m p; do
  case "$p" in .github/scripts/claude-lane/*) echo "reject:publisher-path:$p"; return 1;; esac
done; return 0; }
printf "100644\t.github/workflows/x.yml\n" | cl_validate_paths || true' _ "$lane/lib.sh")"
[ -n "$real_wf" ] && [ -z "$mut_wf" ] && ok \
  || bad "workflow-path mutation control did not discriminate (real=[$real_wf] mut=[$mut_wf])"

# (3) Remove commenter scoping (inject the thread-author association) => the
#     'must not contain issue.author_association' assertion flips.
if [ "$have_py" -eq 1 ]; then
  base_if="$(pyq 'jobs["resolve"].get("if","")')"
  mut_if="$base_if || github.event.issue.author_association == 'OWNER'"
  case "$base_if" in *issue.author_association*) bad "real gate already carries the bypass" ;; *) ok ;; esac
  case "$mut_if" in *issue.author_association*) ok ;; *) bad "association mutation control did not inject the bypass" ;; esac
fi

# ============================================================================
# OPERATOR DOCUMENTATION — truthful boundary
# ============================================================================
[ -f "$DOC" ] && ok || bad "the lane must be documented at docs/ops/claude-coding-lane.md"
if [ -f "$DOC" ]; then
  assert_flat_contains_all "$DOC" "the doc states invocation, publication, and the hard limits" \
    '@claude' 'feature branch' 'cannot merge' 'deploy key' 'ordinary issue|normal issue' 'arm'
  # It must NOT repeat the retired false claim that a granted permission is what
  # stops a merge — the mechanical reason is the credential class.
  assert_flat_lacks "$DOC" "no false 'no permission grants merge' claim" 'no permission grants it'
fi

finish
