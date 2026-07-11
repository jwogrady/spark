#!/usr/bin/env bash
# Regression tests for the PreToolUse push guard (plugins/spark/hooks/guard-bash.sh).
# Each case feeds the guard a Claude tool-call payload and asserts the exit code:
# 0 = allowed, 2 = blocked.

set -euo pipefail

guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/spark/hooks/guard-bash.sh"
pass=0 fail=0

check() {
  local want="$1" desc="$2" cmd="$3" payload rc=0
  payload="$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")"
  printf '%s' "$payload" | bash "$guard" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "  ✖ $desc — want exit $want, got $rc: $cmd"
  fi
}

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

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
