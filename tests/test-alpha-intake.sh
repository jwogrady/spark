#!/usr/bin/env bash
# Regression suite for the Alpha intake canonical-route guard (#322): the
# shipped docs pass, and each known non-canonical route fails.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"
check="$root/.github/scripts/alpha-intake-check.sh"
form="$root/.github/ISSUE_TEMPLATE/alpha-feedback.yml"

bash -n "$check" && ok "bash -n alpha-intake-check.sh" || bad "syntax"

# --- the real, shipped docs pass -------------------------------------------
rc=0; ( bash "$check" "$root/docs/alpha" "$form" >/dev/null 2>&1 ) || rc=$?
assert_rc "canonical route: shipped Alpha docs pass" 0 "$rc"

# --- a fixture set that ROUTES AROUND the form fails, one hazard at a time --
sandbox_init
mkfix() { # build a minimal-but-clean alpha-docs fixture, then let the caller dirty it
  local d="$1"; mkdir -p "$d"
  cp "$root/docs/alpha/testing-guide.md" "$d/testing-guide.md"
  cp "$root/docs/alpha/feedback-template.md" "$d/feedback-template.md"
}

# clean copy passes (sanity: the fixture itself is canonical)
fix="$WORK/clean"; mkfix "$fix"
rc=0; bash "$check" "$fix" "$form" >/dev/null 2>&1 || rc=$?
assert_rc "clean fixture passes" 0 "$rc"

# hazard 1: imperative copy-into-issue
fix="$WORK/copy"; mkfix "$fix"
printf '\nCopy this into a GitHub issue labeled `alpha-feedback`.\n' >> "$fix/testing-guide.md"
rc=0; out="$(bash "$check" "$fix" "$form" 2>&1)" || rc=$?
assert_rc "copy-into-issue instruction fails" 1 "$rc"
assert_contains "names the copy hazard" "copying a template into an issue" "$out"

# hazard 2: the ambiguous identity prompt
fix="$WORK/handle"; mkfix "$fix"
printf '\n- **Participant (handle):**\n' >> "$fix/feedback-template.md"
rc=0; out="$(bash "$check" "$fix" "$form" 2>&1)" || rc=$?
assert_rc "Participant (handle) prompt fails" 1 "$rc"
assert_contains "names the identity hazard" "Participant (handle)" "$out"

# hazard 3: routing to a non-canonical destination
fix="$WORK/route"; mkfix "$fix"
printf '\nFile it wherever the coordinator directs.\n' >> "$fix/testing-guide.md"
rc=0; out="$(bash "$check" "$fix" "$form" 2>&1)" || rc=$?
assert_rc "non-canonical destination fails" 1 "$rc"

# hazard 4: submitting through the markdown template
fix="$WORK/mdroute"; mkfix "$fix"
printf '\nFile one feedback-template report per run.\n' >> "$fix/testing-guide.md"
rc=0; out="$(bash "$check" "$fix" "$form" 2>&1)" || rc=$?
assert_rc "markdown-template submission route fails" 1 "$rc"

# hazard 5: a form that lost a privacy control fails
fix="$WORK/pass"; mkfix "$fix"
weakform="$WORK/weak-form.yml"
grep -v 'no secrets\|No secrets\|NO secrets' "$form" > "$weakform" 2>/dev/null || cp "$form" "$weakform"
# force-strip the secrets attestation to simulate weakening
sed -i.bak '/[Ss]ecrets/d' "$weakform" 2>/dev/null || true
rc=0; out="$(bash "$check" "$fix" "$weakform" 2>&1)" || rc=$?
assert_rc "weakened form (lost a privacy control) fails" 1 "$rc"

finish
