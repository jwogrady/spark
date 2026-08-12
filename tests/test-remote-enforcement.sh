#!/usr/bin/env bash
# Behavioral suite for the third enforcement door (#359): the server-side
# trunk-policy check in `spark doctor --requirements`. The verdict is a pure
# function over evidence lines; gathering degrades to "not assessed" without
# auth or reachable rules and NEVER mutates remote settings. End-to-end runs
# against a fake gh.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # load remote_enforcement_verdict (dispatch is source-guarded)

# --- pure verdict: all three rules present -> conforming.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "full rule set conforms" 0 "$rc"

# --- an unrelated extra rule changes nothing.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "extra rules are fine" 0 "$rc"

# --- no rules at all -> drift, every missing element named.
rc=0; out="$(printf 'protected\tfalse\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "unprotected trunk drifts" 1 "$rc"
assert_contains "names direct pushes" "direct pushes" "$out"
assert_contains "names force-push" "force-push" "$out"
assert_contains "names deletion" "deletion" "$out"

# --- classic protection present but rules unreadable -> drift with the
# verify-by-hand caveat, never a silent pass.
rc=0; out="$(printf 'protected\ttrue\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "classic protection alone still drifts" 1 "$rc"
assert_contains "caveats classic protection" "classic branch protection" "$out"

# --- end-to-end: a conforming repo reports the held policy.
repo="$WORK/prj"; make_repo "$repo"
fakebin="$WORK/fakegh"; mkdir -p "$fakebin"
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\n' ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fakebin/gh"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "conforming remote exits 0" 0 "$rc"
assert_contains "reports the held policy" "policy held server-side" "$out"

# --- end-to-end: an unprotected trunk is reported as drift with the explicit
# (human) apply path — and the run itself never calls a mutating endpoint.
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
log="${GH_STUB_LOG:-/dev/null}"
printf '%s\n' "$*" >> "$log"
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"rules/branches/master"*) : ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
export GH_STUB_LOG="$WORK/gh-calls.log"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "drifted remote still exits 0 (advisory, not a gate)" 0 "$rc"
assert_contains "names the drift" "does not hold the policy" "$out"
assert_contains "points at the ruleset template" "github-ruleset-trunk.json" "$out"
assert_contains "degrades the summary" "remote-enforcement" "$out"
case "$(cat "$GH_STUB_LOG")" in
  *"-X "*|*"--method"*|*"-f "*|*"--input"*) bad "the check must never call a mutating gh endpoint" ;;
  *) ok ;;
esac
unset GH_STUB_LOG

# --- json output carries the assessed/ready pair.
if command -v jq >/dev/null 2>&1; then
  cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\n' ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
  out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements --json 2>&1)"
  printf '%s' "$out" | jq empty 2>/dev/null && ok || bad "--json with remote check parses"
  [ "$(printf '%s' "$out" | jq -r '.remote_enforcement.assessed and .remote_enforcement.ready')" = "true" ] \
    && ok || bad "--json remote_enforcement flags not true on a conforming repo"
fi

# --- no gh auth -> honestly not assessed, still exit 0.
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 1 ;;
esac
exit 0
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "unauthenticated stays exit 0" 0 "$rc"
assert_contains "remote check is honestly not assessed" "not assessed" "$out"

finish
