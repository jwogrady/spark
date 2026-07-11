#!/usr/bin/env bash
# Regression tests for the PreToolUse push guard (plugins/spark/hooks/guard-bash.sh).
# Each case feeds the guard a Claude tool-call payload and asserts the exit code:
# 0 = allowed, 2 = blocked.

set -euo pipefail

guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/spark/hooks/guard-bash.sh"
pass=0 fail=0

check_in() {
  local dir="$1" want="$2" desc="$3" cmd="$4" payload rc=0
  payload="$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")"
  printf '%s' "$payload" | (cd "$dir" && bash "$guard") >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "  ✖ $desc — want exit $want, got $rc: $cmd"
  fi
}

check() { check_in "$PWD" "$@"; }

allow() { check 0 "$1" "$2"; }
deny()  { check 2 "$1" "$2"; }

# --- non-git and plain commands pass through
allow "non-git command"                    "ls -la"
allow "git status"                         "git status"
allow "git commit"                         "git commit -m 'feat: x'"

# --- plain trunk pushes (the original coverage)
deny  "push master"                        "git push origin master"
deny  "push main"                          "git push origin main"
deny  "push main no remote"                "git push main"
allow "push feature branch"                "git push origin feat/x"
allow "push -u feature"                    "git push -u origin feat/x"

# --- option-bearing invocations (the reported bypasses)
deny  "-C path push refspec main"          "git -C /path/to/repo push origin HEAD:refs/heads/main"
deny  "-c config push refspec master"      "git -c credential.helper= push origin HEAD:refs/heads/master"
deny  "--git-dir push refspec main"        "git --git-dir=/path/to/repo/.git push origin HEAD:refs/heads/main"
deny  "--git-dir with separate arg"        "git --git-dir /repo/.git push origin main"
allow "-C path push feature refspec"       "git -C /path push origin HEAD:refs/heads/feature/example"

# --- full and partial refspecs
deny  "HEAD:main"                          "git push origin HEAD:main"
deny  "branch:master"                      "git push origin feat/x:master"
deny  "delete trunk refspec"               "git push origin :main"
allow "HEAD:feature"                       "git push origin HEAD:feature/example"
allow "refs/heads/feature dst"             "git push origin HEAD:refs/heads/feature/example"
allow "branch named main-fix"              "git push origin main-fix"
allow "src named main, feature dst"        "git push origin main:feat/backport"

# --- force pushes
deny  "--force"                            "git push --force origin feat/x"
deny  "-f"                                 "git push -f origin feat/x"
deny  "-f bundled"                         "git push -fu origin feat/x"
deny  "-C path --force"                    "git -C /repo push --force origin feat/x"
deny  "+refspec force"                     "git push origin +feat/x:feat/x"
deny  "+refspec to trunk"                  "git push origin +HEAD:main"
allow "--force-with-lease"                 "git push --force-with-lease origin feat/x"
allow "--force-with-lease=ref"             "git push --force-with-lease=feat/x origin feat/x"
allow "+refspec tempered by lease"         "git push --force-with-lease origin +feat/x:feat/x"
deny  "--force despite feature branch"     "git push origin feat/x --force"

# --- compound commands
deny  "push main after &&"                 "git add . && git push origin main"
deny  "second invocation forces"           "git push origin feat/x && git push -f origin feat/y"
allow "two clean pushes"                   "git push origin feat/x && git push origin feat/y"

# --- push options that take arguments must not be misread as refspecs
allow "-o option value main"               "git push -o main origin feat/x"
allow "--push-option main"                 "git push --push-option main origin feat/x"

# --- Release Please boundary (conditional on release-please-config.json)
# The rule depends on the repo the command runs in, so build one repo with
# the config and one without instead of relying on the enclosing checkout.
rp_repo="$(mktemp -d)" plain_repo="$(mktemp -d)"
trap 'rm -rf "$rp_repo" "$plain_repo"' EXIT
git -C "$rp_repo" init -q
: > "$rp_repo/release-please-config.json"
mkdir -p "$rp_repo/sub"
git -C "$plain_repo" init -q

allow_in() { check_in "$1" 0 "$2" "$3"; }
deny_in()  { check_in "$1" 2 "$2" "$3"; }

deny_in  "$rp_repo" "tag create with RP config"          "git tag v1.0.0"
deny_in  "$rp_repo" "annotated tag with RP config"       "git tag -a v1.0.0 -m 'release'"
deny_in  "$rp_repo" "signed tag with RP config"          "git tag -s v1.0.0"
deny_in  "$rp_repo" "tag create after &&"                "git add . && git tag v2.0.0"
deny_in  "$rp_repo/sub" "tag create from subdirectory"   "git tag v1.0.0"
deny_in  "$rp_repo" "gh release create with RP config"   "gh release create v1.0.0"
deny_in  "$rp_repo" "gh -R release create"               "gh -R jwogrady/spark release create v1.0.0"
allow_in "$rp_repo" "bare git tag lists"                 "git tag"
allow_in "$rp_repo" "git tag -l"                         "git tag -l 'v*'"
allow_in "$rp_repo" "git tag --list"                     "git tag --list"
allow_in "$rp_repo" "git tag delete"                     "git tag -d v1.0.0"
allow_in "$rp_repo" "git tag verify"                     "git tag -v v1.0.0"
allow_in "$rp_repo" "gh release list"                    "gh release list"
allow_in "$rp_repo" "gh release view"                    "gh release view v1.0.0"
allow_in "$rp_repo" "feature push unaffected"            "git push origin feat/x"
deny_in  "$rp_repo" "trunk push still blocked"           "git push origin master"
deny_in  "$rp_repo" "companion-style tag create"         "git tag spark-audit-v0.2.1"
deny_in  "$rp_repo" "-c config tag create"               "git -c user.name=x tag v1.0.0"
deny_in  "$rp_repo" "refspec tag push"                   "git push origin HEAD:refs/tags/v1.0.0"
deny_in  "$rp_repo" "forced refspec tag push"            "git push origin +HEAD:refs/tags/v1.0.0"
deny_in  "$rp_repo" "remote tag delete refspec"          "git push origin :refs/tags/v1.0.0"
deny_in  "$rp_repo" "push --tags"                        "git push --tags origin feat/x"
deny_in  "$rp_repo" "push --follow-tags"                 "git push --follow-tags origin feat/x"
deny_in  "$rp_repo" "update-ref tag write"               "git update-ref refs/tags/v1.0.0 HEAD"
allow_in "$rp_repo" "update-ref non-tag ref"             "git update-ref refs/notes/x HEAD"
allow_in "$plain_repo" "tag create without RP config"    "git tag v1.0.0"
allow_in "$plain_repo" "gh release create without config" "gh release create v1.0.0"
allow_in "$plain_repo" "refspec tag push without config" "git push origin HEAD:refs/tags/v1.0.0"

# Workflow-only marker: the ship skill treats a release-please workflow as the
# same signal as the config file, so the guard must too.
wf_repo="$(mktemp -d)"
trap 'rm -rf "$rp_repo" "$plain_repo" "$wf_repo"' EXIT
git -C "$wf_repo" init -q
mkdir -p "$wf_repo/.github/workflows"
: > "$wf_repo/.github/workflows/release-please.yml"
deny_in  "$wf_repo" "tag create with RP workflow only"   "git tag v1.0.0"
deny_in  "$wf_repo" "gh release create with RP workflow" "gh release create v1.0.0"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
