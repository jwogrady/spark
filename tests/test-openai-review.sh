#!/usr/bin/env bash
# Behavioral tests for the OpenAI reviewer lane (#584).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/.."
wf="$repo/.github/workflows/openai-review.yml"
lib="$repo/.github/scripts/openai-review/lib.sh"
claude_lib="$repo/.github/scripts/claude-lane/lib.sh"
# shellcheck source=/dev/null
. "$lib"

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }
haswf()    { grep -qE -- "$2" "$wf" && ok || bad "$1 — workflow lacks /$2/"; }
haswf_not(){ if grep -qE -- "$2" "$wf"; then bad "$1 — workflow wrongly matches /$2/"; else ok; fi; }

echo "OpenAI reviewer lane (#584)"
bash -n "$lib" && ok || bad "bash -n lib.sh"

# Trusted-execution boundary.
haswf "uses pull_request_target so execution comes from trusted base" '^  pull_request_target:'
haswf_not "does not execute a pull_request workflow from PR code" '^  pull_request:'
haswf "checks out the exact base SHA" 'ref: \$\{\{ github.event.pull_request.base.sha \}\}'
haswf_not "never checks out the PR head" 'ref: \$\{\{ github.event.pull_request.head.sha \}\}'
haswf "checkout persists no credential" 'persist-credentials: false'
haswf "reads contents, never writes them" 'contents: read'
haswf_not "reviewer has no contents write" 'contents: write'
haswf_not "reviewer has no publisher deploy key" 'DEPLOY_KEY|CLAUDE_PUBLISH'

# Serialized, durable one-invocation claim.
haswf "serializes one PR" 'group: openai-review-'
haswf "does not cancel an in-flight paid review" 'cancel-in-progress: false'
haswf "paginates comment claims" 'gh api --paginate.*comments\?per_page=100'
haswf "writes a durable reservation before review" 'orl_reservation'
haswf "rechecks the live HEAD before model invocation" 'superseded before reviewer invocation'
haswf "finalizes the existing reservation comment" 'issues/comments/\$RESERVATION_ID'
haswf_not "publication failures are not swallowed" 'gh (pr comment|api).*\|\| true'

# Prompt-injection boundary.
haswf "uses higher-authority Responses API instructions" 'instructions: \$instructions'
haswf "labels supplied evidence as untrusted" 'UNTRUSTED.*DATA'
haswf "keeps untrusted evidence in input" 'input: \$input'
# The binding policy is TRUSTED committed code, read from the base checkout — not
# a column-0 heredoc that breaks the workflow YAML.
instr="$repo/.github/scripts/openai-review/reviewer-instructions.txt"
[ -f "$instr" ] && ok || bad "committed reviewer instructions missing"
grep -qi "UNTRUSTED DATA" "$instr" 2>/dev/null && ok || bad "instructions must declare supplied evidence UNTRUSTED"
grep -q "PASS | CHANGES REQUIRED | DECISION REQUIRED | NOT ASSESSED" "$instr" 2>/dev/null && ok || bad "instructions must state the closed verdict vocabulary"
haswf "reads binding policy from the trusted committed file" 'reviewer-instructions.txt'

# Fail closed and exact-head evidence.
haswf "uses the OpenAI secret" 'OPENAI_API_KEY: \$\{\{ secrets.OPENAI_API_KEY \}\}'
haswf "missing key fails closed" 'OPENAI_API_KEY is not available'
haswf "provider failure fails closed" 'could not be reached \(HTTP'
haswf "posts structured exact-head marker" 'orl_marker'

# Cross-lane guard: Claude's deterministic publisher protects the independent
# reviewer helper tree as well as workflows and its own helpers.
# shellcheck source=/dev/null
. "$claude_lib"
case "$(printf '100644\t.github/scripts/openai-review/lib.sh\n' | cl_validate_paths 2>&1 || true)" in
  *"reject:reviewer-path"*) ok ;;
  *) bad "Claude publisher must reject OpenAI reviewer helper changes" ;;
esac

# Verdict normalization.
nv() { local want="$1" got; got="$(orl_normalize_verdict "$2")"; [ "$got" = "$want" ] && ok || bad "normalize '$2' — want '$want' got '$got'"; }
nv PASS "PASS"
nv "CHANGES REQUIRED" "CHANGES REQUIRED"
nv "DECISION REQUIRED" "DECISION REQUIRED"
nv "NOT ASSESSED" "NOT ASSESSED"
nv PASS "PASS — nothing blocking"
nv "NOT ASSESSED" "pass"
nv "NOT ASSESSED" ""

ci() { local got; got="$(printf '%s' "$2" | orl_closing_issues | paste -sd, -)"; [ "$got" = "$1" ] && ok || bad "closing_issues '$2' — want '$1' got '$got'"; }
ci "12" "closes #12"
ci "1,2,3" "closes #2, fixes #1, resolves #3"
ci "" "see #4"

m="$(orl_marker PASS 688 abc123)"
r="$(orl_reservation 688 abc123)"
case "$m" in *"spark-openai-review pr=688 head=abc123 verdict=PASS"*) ok ;; *) bad "final marker shape" ;; esac
case "$r" in *"spark-openai-review-reservation pr=688 head=abc123"*) ok ;; *) bad "reservation marker shape" ;; esac

# Trusted claim identity: marker text alone is not authority.
trusted_final="github-actions[bot]	github-actions	$m"
trusted_res="github-actions[bot]	github-actions	$r"
spoof_login="attacker	github-actions	$m"
spoof_app="github-actions[bot]	evil-app	$m"
wrong_pr="github-actions[bot]	github-actions	$(orl_marker PASS 999 abc123)"
wrong_head="github-actions[bot]	github-actions	$(orl_marker PASS 688 def456)"
printf '%b\n' "$trusted_final" | orl_has_trusted_claim 688 abc123 && ok || bad "trusted final claim not detected"
printf '%b\n' "$trusted_res" | orl_has_trusted_claim 688 abc123 && ok || bad "trusted reservation not detected"
printf '%b\n' "$spoof_login" | orl_has_trusted_claim 688 abc123 && bad "spoofed login suppressed review" || ok
printf '%b\n' "$spoof_app" | orl_has_trusted_claim 688 abc123 && bad "spoofed app suppressed review" || ok
printf '%b\n' "$wrong_pr" | orl_has_trusted_claim 688 abc123 && bad "wrong PR suppressed review" || ok
printf '%b\n' "$wrong_head" | orl_has_trusted_claim 688 abc123 && bad "wrong HEAD suppressed review" || ok

# Mutation controls prove both trusted identity fields are load-bearing.
mut_login="$(printf '%b\n' "$spoof_login" | sed 's/^attacker/github-actions[bot]/')"
printf '%s\n' "$mut_login" | orl_has_trusted_claim 688 abc123 && ok || bad "login mutation control did not flip"
mut_app="$(printf '%b\n' "$spoof_app" | sed 's/evil-app/github-actions/')"
printf '%s\n' "$mut_app" | orl_has_trusted_claim 688 abc123 && ok || bad "app mutation control did not flip"

case "$(orl_route PASS)" in *"not merge authority"*) ok ;; *) bad "PASS route" ;; esac
case "$(orl_route "CHANGES REQUIRED")" in *"#585"*"do not merge"*) ok ;; *) bad "CHANGES route" ;; esac
case "$(orl_route "DECISION REQUIRED")" in *"@jwogrady"*) ok ;; *) bad "DECISION route" ;; esac
case "$(orl_route "NOT ASSESSED")" in *"not assessed"*) ok ;; *) bad "NOT ASSESSED route" ;; esac

# --- diff completeness (#693): a truncated diff can never PASS ----------------
# Truncation detection is size-based, so it fires wherever the cut lands.
orl_is_truncated 200001 200000 && ok || bad "a diff over budget must be truncated"
orl_is_truncated 200000 200000 && bad "a diff at exactly the budget is not truncated" || ok
orl_is_truncated 5 200000 && bad "a small diff is not truncated" || ok
# A byte cut inside a line, and inside a multi-byte character, both leave the
# original larger than the budget — so both are detected as truncated.
orl_is_truncated 200050 200000 && ok || bad "a mid-line cut (over budget) must be truncated"
orl_is_truncated 200003 200000 && ok || bad "a split multi-byte char (over budget) must be truncated"
# Unreadable size fails closed to truncated — never treated as a complete diff.
orl_is_truncated "" 200000 && ok || bad "an unreadable size must fail closed to truncated"
orl_is_truncated abc 200000 && ok || bad "a non-numeric size must fail closed to truncated"

# The mechanical guarantee: a model PASS on a truncated diff is downgraded.
[ "$(orl_enforce_completeness PASS 1)" = "NOT ASSESSED" ] && ok || bad "PASS on a truncated diff must become NOT ASSESSED"
[ "$(orl_enforce_completeness PASS 0)" = "PASS" ] && ok || bad "PASS on a complete diff must stand"
# A real defect or decision found in the shown prefix is still valid when truncated.
[ "$(orl_enforce_completeness "CHANGES REQUIRED" 1)" = "CHANGES REQUIRED" ] && ok || bad "CHANGES REQUIRED must survive truncation"
[ "$(orl_enforce_completeness "DECISION REQUIRED" 1)" = "DECISION REQUIRED" ] && ok || bad "DECISION REQUIRED must survive truncation"
[ "$(orl_enforce_completeness "NOT ASSESSED" 1)" = "NOT ASSESSED" ] && ok || bad "NOT ASSESSED stays NOT ASSESSED"

# The acceptance scenario: a blocker after the 200000-byte boundary. The diff is
# over budget (truncated=1), so even a model PASS cannot publish PASS.
late_blocker_orig=200015
if orl_is_truncated "$late_blocker_orig" 200000; then
  [ "$(orl_enforce_completeness PASS 1)" = "NOT ASSESSED" ] && ok || bad "a late blocker must not be able to PASS"
else bad "a diff with a late blocker past the bound must be truncated"; fi

# Static workflow facts: truncation is detected, disclosed, and enforced.
haswf "detects truncation with the tested helper"     'orl_is_truncated "\$orig_bytes" "\$budget"'
haswf "fetches the complete changed-file manifest"    'pulls/\$PR/files'
haswf "discloses diff completeness to the model"      'DIFF COMPLETENESS'
haswf "enforces completeness on the verdict"          'orl_enforce_completeness "\$model_verdict"'
haswf_not "no silent head -c bound without detection" 'head -c 200000 /tmp/rev/diff.txt'
# A refused/unfetchable diff is treated as truncated, never disclosed as COMPLETE.
haswf "an unfetched diff forces the truncated branch"  '\[ "\$diff_ok" = "0" \] \|\| orl_is_truncated'
haswf "discloses an unavailable diff honestly"         'DIFF UNAVAILABLE'
haswf "an unreadable completeness flag fails closed"   'cat /tmp/rev/truncated 2>/dev/null \|\| echo 1'

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
