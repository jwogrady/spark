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

# --- pure verdict: the full policy (PRs + CI gate with a context + no
# force-push + no deletion) conforms.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\ncheck\tvalidate\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "full rule set conforms" 0 "$rc"

# --- an unrelated extra rule changes nothing.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\ncheck\tdoctor\ncheck\ttests\nrule\tcreation\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "extra rules are fine" 0 "$rc"

# --- #359: the three classic rules WITHOUT a required_status_checks rule is
# drift — merges must be gated on CI.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "missing required checks is drift" 1 "$rc"
assert_contains "names the missing CI gate" "not gated on CI" "$out"

# --- a required_status_checks rule with zero contexts gates nothing = drift.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "empty check contexts is drift" 1 "$rc"
assert_contains "names the empty contexts" "names no contexts" "$out"

# --- the CONTRACT is the specific required contexts (#359): all present ->
# conforming; extra effective checks are fine.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\nrequire\tdoctor\nrequire\ttests\ncheck\tdoctor\ncheck\ttests\ncheck\textra-lint\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "all required contexts present (plus extras) conforms" 0 "$rc"

# --- one required check missing from the effective gate -> drift, named.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\nrequire\tdoctor\nrequire\ttests\ncheck\tdoctor\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "a missing required check is drift" 1 "$rc"
assert_contains "names the missing context" "tests" "$out"
assert_contains "says extras are fine but these are required" "extra remote checks are fine" "$out"

# --- ATTACK (under-block regression): a required context must never be
# satisfied by a DIFFERENT effective context that merely contains it as a
# word — "integration tests" does not satisfy required "tests".
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\nrequire\ttests\ncheck\tintegration tests\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "a superstring context does not satisfy a required name" 1 "$rc"
assert_contains "names the missing exact context" "'tests'" "$out"

# --- context names containing spaces compare as single names, both ways.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\nrequire\tbuild and test\ncheck\tbuild and test\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "a spaced context name matches itself exactly" 0 "$rc"
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\nrequire\tbuild and test\ncheck\tbuild\ncheck\tand\ncheck\ttest\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "word fragments never satisfy a spaced required name" 1 "$rc"

# --- a wrong check name (typo'd context) cannot satisfy the requirement.
rc=0; out="$(printf 'rule\tpull_request\nrule\tnon_fast_forward\nrule\tdeletion\nrule\trequired_status_checks\nrequire\tvalidate\ncheck\tvaldiate\n' | remote_enforcement_verdict)" || rc=$?
assert_rc "a wrong context name is drift" 1 "$rc"
assert_contains "names the required context" "validate" "$out"

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
  *"required_status_checks"*"rules/branches/master"*|*"rules/branches/master"*"required_status_checks"*) printf 'validate\nextra-scan\n' ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\nrequired_status_checks\n' ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fakebin/gh"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "conforming remote exits 0" 0 "$rc"
assert_contains "reports the held policy" "policy held server-side" "$out"
assert_contains "the held policy includes the CI gate" "merges CI-gated" "$out"

# --- a repo-local policy file overrides the shipped template's contexts: the
# remote must carry THIS repo's required checks (doctor+tests), and one
# missing is drift even though the rule exists and names another context.
mkdir -p "$repo/.github"
cat > "$repo/.github/spark-trunk-ruleset.json" <<'EOF'
{ "rules": [ { "type": "required_status_checks", "parameters": { "required_status_checks": [
  { "context": "doctor" }, { "context": "tests" } ] } } ] }
EOF
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"required_status_checks"*"rules/branches/master"*|*"rules/branches/master"*"required_status_checks"*) printf 'doctor\n' ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\nrequired_status_checks\n' ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "missing repo-required check still exits 0 (advisory)" 0 "$rc"
assert_contains "names the drift" "does not hold the policy" "$out"
assert_contains "names the missing repo-required context" "tests" "$out"

# --- same repo-local policy, remote carries both (plus an extra) -> healthy.
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"required_status_checks"*"rules/branches/master"*|*"rules/branches/master"*"required_status_checks"*) printf 'doctor\ntests\nlint\n' ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\nrequired_status_checks\n' ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "repo-required checks all present exits 0" 0 "$rc"
assert_contains "reports the held policy with the repo's contract" "policy held server-side" "$out"
rm -rf "$repo/.github"

# --- conforming rules with an UNREADABLE protected flag must still report
# conforming (regression: the empty-prot evidence group used to fail the
# pipeline under pipefail and print a zero-finding false drift).
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"required_status_checks"*"rules/branches/master"*|*"rules/branches/master"*"required_status_checks"*) printf 'validate\n' ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\nrequired_status_checks\n' ;;
  *"branches/master --jq .protected"*) exit 1 ;;
  *) exit 0 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "unreadable protected flag still exits 0" 0 "$rc"
assert_contains "full rules conform without the protected probe" "policy held server-side" "$out"

# --- a FAILED rules read (vs an empty rule list) is not assessed, never a
# guessed drift verdict.
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"rules/branches/master"*) exit 1 ;;
  *"branches/master --jq .protected"*) echo "true" ;;
  *) exit 0 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "failed rules read exits 0" 0 "$rc"
assert_contains "failed rules read is not assessed" "not assessed" "$out"

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

# --- the CONTEXTS read failing (types read fine) is not assessed, never a
# guessed "no contexts" drift.
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"required_status_checks"*"rules/branches/master"*|*"rules/branches/master"*"required_status_checks"*) exit 1 ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\nrequired_status_checks\n' ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "failed contexts read exits 0" 0 "$rc"
assert_contains "failed contexts read is not assessed" "not assessed" "$out"

# --- the shipped policy template satisfies the verdict it is measured
# against, and carries the CI-gate rule with at least one context.
if command -v jq >/dev/null 2>&1; then
  tpl="$WORK/plugin/settings/github-ruleset-trunk.json"
  jq empty "$tpl" && ok || bad "ruleset template is valid JSON"
  rc=0; out="$(
    { jq -r '.rules[].type' "$tpl" | awk 'NF{printf "rule\t%s\n", $0}'
      jq -r '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context' "$tpl" \
        | awk 'NF{printf "check\t%s\n", $0}'
      jq -r '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context' "$tpl" \
        | awk 'NF{printf "require\t%s\n", $0}'
    } | remote_enforcement_verdict)" || rc=$?
  assert_rc "the shipped template conforms to its own verdict" 0 "$rc"
  [ "$(jq -r '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks | length' "$tpl")" -ge 1 ] \
    && ok || bad "template carries at least one required check context"
fi

# --- ATTACK (policy-evidence regression): a repo-local policy file that
# exists but yields no readable contexts must be NOT ASSESSED — never the
# any-one-context fallback that would pass a wrong-check remote as healthy.
mkdir -p "$repo/.github"
printf '{}\n' > "$repo/.github/spark-trunk-ruleset.json"
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"required_status_checks"*"rules/branches/master"*|*"rules/branches/master"*"required_status_checks"*) printf 'totally-wrong-check\n' ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\nrequired_status_checks\n' ;;
  *"branches/master --jq .protected"*) echo "false" ;;
  *) exit 0 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "zero-context policy file exits 0" 0 "$rc"
assert_contains "zero-context policy is not assessed" "not assessed" "$out"
case "$out" in *"policy held server-side"*) bad "an unusable policy file must never verify healthy" ;; *) ok ;; esac

# --- same for an unreadable policy file (skipped when running as root,
# where mode 000 is still readable).
printf '{ "rules": [ { "type": "required_status_checks", "parameters": { "required_status_checks": [ { "context": "doctor" } ] } } ] }\n' > "$repo/.github/spark-trunk-ruleset.json"
chmod 000 "$repo/.github/spark-trunk-ruleset.json"
if [ -r "$repo/.github/spark-trunk-ruleset.json" ]; then
  echo "  (running privileged - unreadable-policy case skipped)"
else
  rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" "$SPARK" doctor --requirements 2>&1)" || rc=$?
  assert_rc "unreadable policy file exits 0" 0 "$rc"
  assert_contains "unreadable policy is not assessed" "not assessed" "$out"
  case "$out" in *"policy held server-side"*) bad "an unreadable policy file must never verify healthy" ;; *) ok ;; esac
fi
chmod 644 "$repo/.github/spark-trunk-ruleset.json"
rm -rf "$repo/.github"

# --- json output carries the assessed/ready pair.
if command -v jq >/dev/null 2>&1; then
  cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version*) echo "gh version 0.0.0-stub" ;;
  "auth status") exit 0 ;;
  *"api repos/{owner}/{repo} --jq .default_branch"*) echo "master" ;;
  *"required_status_checks"*"rules/branches/master"*|*"rules/branches/master"*"required_status_checks"*) printf 'validate\n' ;;
  *"rules/branches/master"*) printf 'pull_request\nnon_fast_forward\ndeletion\nrequired_status_checks\n' ;;
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
