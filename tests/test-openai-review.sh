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
# The checkout ref is the trusted base: base.sha for a PR event, the default
# branch for a workflow_run event (also trusted) — never the PR head.
haswf "checks out the trusted base SHA" 'ref: \$\{\{ github.event.pull_request.base.sha \|\| github.event.repository.default_branch \}\}'
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

# Final marker vs bare reservation (#692): a reservation means "claimed, review may
# be pending" (RESUMABLE); a final marker means "reviewed" (never review twice).
# orl_has_final_marker must fire ONLY on the marker, so a pending reservation does
# not suppress the resume that reviews the HEAD once its checks are terminal.
printf '%b\n' "$trusted_final" | orl_has_final_marker 688 abc123 && ok || bad "a trusted final marker must be detected"
printf '%b\n' "$trusted_res"   | orl_has_final_marker 688 abc123 && bad "a bare reservation must NOT count as a final marker (it must stay resumable)" || ok
printf '%b\n' "$spoof_login"   | orl_has_final_marker 688 abc123 && bad "a spoofed-login marker must not count" || ok
printf '%b\n' "$spoof_app"     | orl_has_final_marker 688 abc123 && bad "a spoofed-app marker must not count" || ok
printf '%b\n' "$wrong_head"    | orl_has_final_marker 688 abc123 && bad "a wrong-HEAD marker must not count" || ok

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
# Fail closed: only an EXACT "0" completeness flag lets a PASS stand. An empty or
# malformed flag must downgrade a PASS, never permit it.
[ "$(orl_enforce_completeness PASS "")" = "NOT ASSESSED" ] && ok || bad "PASS with an empty flag must fail closed"
[ "$(orl_enforce_completeness PASS 2)" = "NOT ASSESSED" ] && ok || bad "PASS with a malformed flag (2) must fail closed"
[ "$(orl_enforce_completeness PASS x)" = "NOT ASSESSED" ] && ok || bad "PASS with a non-numeric flag must fail closed"

# The acceptance scenario — a blocker after the 200000-byte boundary — is proven
# against real constructed bytes through orl_build_evidence further below, not by
# passing a number to a helper.

# Evidence completeness (#693): PASS needs a COMPLETE diff AND a fetched manifest.
et() { [ "$(orl_evidence_truncated "$2" "$3")" = "$1" ] && ok || bad "evidence_truncated $2/$3 — want $1"; }
et 0 COMPLETE 1     # whole diff seen and manifest present → complete, PASS allowed
et 1 COMPLETE 0     # manifest fetch failed → incomplete, blocks PASS
et 1 TRUNCATED 1    # diff cut → incomplete even with a manifest
et 1 UNAVAILABLE 1  # diff unfetchable → incomplete
et 1 TRUNCATED 0    # both gaps → incomplete
# End to end: a manifest-fetch failure on an otherwise complete diff downgrades PASS.
[ "$(orl_enforce_completeness PASS "$(orl_evidence_truncated COMPLETE 0)")" = "NOT ASSESSED" ] \
  && ok || bad "a model PASS with an unavailable manifest must become NOT ASSESSED"
# And a genuinely complete diff + manifest lets a PASS stand.
[ "$(orl_enforce_completeness PASS "$(orl_evidence_truncated COMPLETE 1)")" = "PASS" ] \
  && ok || bad "a model PASS on complete evidence must stand"

# Manifest completeness (#693): the files endpoint caps at 3000, so a returned
# count short of the PR's changed_files is a silently capped, incomplete manifest.
mc() { [ "$(orl_manifest_complete "$2" "$3")" = "$1" ] && ok || bad "manifest_complete $2/$3 — want $1"; }
mc 1 5 5        # every changed file returned → complete
mc 1 0 0        # a PR with no changed files: 0 of 0 → complete, not unavailable
mc 1 3500 3500  # uncapped GraphQL retrieval of all 3500 files (>3000) → complete
mc 0 3000 3500  # a list capped at 3000 of 3500 → incomplete, blocks PASS
mc 0 4 5        # one file short → incomplete
mc 0 6 5        # an inflated count (never legitimate) → mismatch, fail closed
mc 0 "" 5       # unreadable returned count → fail closed
mc 0 5 ""       # unknown changed_files → fail closed
mc 0 x 5        # non-numeric count → fail closed
# End to end: uncapped retrieval of every file beyond the 3000 REST cap lets a
# complete-evidence PASS stand (criterion 3 satisfied without a capped shortfall).
[ "$(orl_enforce_completeness PASS "$(orl_evidence_truncated COMPLETE "$(orl_manifest_complete 3500 3500)")")" = "PASS" ] \
  && ok || bad "complete retrieval beyond 3000 files must let a PASS stand"
# And a list capped short of changed_files still downgrades PASS.
[ "$(orl_enforce_completeness PASS "$(orl_evidence_truncated COMPLETE "$(orl_manifest_complete 3000 3500)")")" = "NOT ASSESSED" ] \
  && ok || bad "a capped manifest must not let a PASS stand"

# The manifest count must come from API records, not rendered filenames: git
# permits a newline in a filename, which would otherwise inflate a wc -l count
# and make a capped manifest look complete. @json-escaping keeps one line per
# record (and stops the same newline injecting a line into the prompt).
if command -v jq >/dev/null 2>&1; then
  rec='{"changeType":"MODIFIED","path":"a\nb/c.md","additions":1,"deletions":0}'
  two="$(printf '[%s,%s]' "$rec" "$rec" \
    | jq -r '.[] | "\(.changeType)\t\(.path|@json)\t+\(.additions)/-\(.deletions)"' | wc -l | tr -d ' ')"
  [ "$two" = "2" ] && ok || bad "two newline-bearing records must count as 2 lines, got $two"
  raw="$(printf '[%s,%s]' "$rec" "$rec" \
    | jq -r '.[] | "\(.changeType)\t\(.path)\t+\(.additions)/-\(.deletions)"' | wc -l | tr -d ' ')"
  [ "$raw" -gt 2 ] && ok || bad "control: raw filename rendering must over-count (got $raw)"
fi

# --- orl_build_evidence: real byte/manifest scenarios (#693) -------------------
# These exercise the ACTUAL diff-bounding, flag, and disclosure the workflow runs
# — against constructed bytes, not numeric proxies. mkbig N writes N bytes of 'A'.
be="$(mktemp -d)"; trap 'rm -rf "$be"' EXIT
mkbig() { head -c "$1" /dev/zero | tr '\0' 'A'; }
m3="$be/m3.txt"; printf 'M\t"a"\t+1/-0\nM\t"b"\t+1/-0\nM\t"c"\t+1/-0\n' > "$m3"  # 3 records

# 1) A blocking change placed AFTER byte 200000 is not in the bounded diff, the
#    evidence is flagged truncated, and a model PASS is downgraded to NOT ASSESSED.
{ mkbig 200000; printf '\nLATE_BLOCKER_zzz\n'; } > "$be/diff.raw"
orl_build_evidence "$be/diff.raw" 1 200000 "$m3" 1 3 "$be"
[ "$(cat "$be/truncated")" = 1 ] && ok || bad "a diff with a late blocker past the bound must be truncated"
[ "$(wc -c < "$be/diff.txt" | tr -d ' ')" = 200000 ] && ok || bad "the bounded diff must be exactly the budget"
grep -q LATE_BLOCKER "$be/diff.txt" && bad "the late blocker must NOT be in the bounded diff" || ok
grep -q "DIFF TRUNCATED" "$be/completeness.txt" && ok || bad "truncation must be disclosed to the model"
[ "$(orl_enforce_completeness PASS "$(cat "$be/truncated")")" = "NOT ASSESSED" ] && ok || bad "a late blocker must force NOT ASSESSED"

# 2) A byte cut inside a line (no newline near the bound) is still detected.
mkbig 200050 > "$be/diff.raw"
orl_build_evidence "$be/diff.raw" 1 200000 "$m3" 1 3 "$be"
[ "$(cat "$be/truncated")" = 1 ] && ok || bad "a mid-line over-budget cut must be truncated"
[ "$(wc -c < "$be/diff.txt" | tr -d ' ')" = 200000 ] && ok || bad "the mid-line cut must be bounded to the budget"

# 3) A cut inside a multi-byte character (199999 + a 3-byte € = 200002) is detected.
{ mkbig 199999; printf '\xe2\x82\xac'; } > "$be/diff.raw"
orl_build_evidence "$be/diff.raw" 1 200000 "$m3" 1 3 "$be"
[ "$(cat "$be/truncated")" = 1 ] && ok || bad "a split multi-byte char (over budget) must be truncated"

# 4) A small complete diff + complete manifest passes through and lets PASS stand.
printf 'diff --git a b\n+ok\n' > "$be/diff.raw"
orl_build_evidence "$be/diff.raw" 1 200000 "$m3" 1 3 "$be"
[ "$(cat "$be/truncated")" = 0 ] && ok || bad "a small complete diff must not be truncated"
grep -q "DIFF COMPLETE" "$be/completeness.txt" && ok || bad "a complete diff must be disclosed COMPLETE"
[ "$(orl_enforce_completeness PASS "$(cat "$be/truncated")")" = "PASS" ] && ok || bad "complete evidence must let a PASS stand"

# 5) An unfetchable diff (diff_ok=0) is UNAVAILABLE and blocks PASS.
echo "(diff unavailable)" > "$be/diff.raw"
orl_build_evidence "$be/diff.raw" 0 200000 "$m3" 1 3 "$be"
[ "$(cat "$be/truncated")" = 1 ] && ok || bad "an unavailable diff must be truncated"
grep -q "DIFF UNAVAILABLE" "$be/completeness.txt" && ok || bad "an unavailable diff must be disclosed honestly"

# 6) A manifest capped short of changed_files blocks PASS even with a complete diff.
printf 'diff --git a b\n+ok\n' > "$be/diff.raw"
awk 'BEGIN{for(i=0;i<3000;i++)printf "M\t\"f%d\"\t+1/-0\n",i}' > "$be/m3000.txt"
orl_build_evidence "$be/diff.raw" 1 200000 "$be/m3000.txt" 1 3500 "$be"
[ "$(cat "$be/truncated")" = 1 ] && ok || bad "a manifest capped at 3000 of 3500 must block PASS"
grep -q "INCOMPLETE" "$be/completeness.txt" && ok || bad "a capped manifest must be disclosed INCOMPLETE"

# 7) A complete manifest beyond the 3000 REST cap (as uncapped GraphQL returns) —
#    every filename represented, including one after record 3000 — lets PASS stand.
awk 'BEGIN{for(i=0;i<3500;i++)printf "M\t\"path/f%d.md\"\t+1/-0\n",i}' > "$be/m3500.txt"
grep -q '"path/f3400.md"' "$be/m3500.txt" && ok || bad "a filename after record 3000 must be represented"
orl_build_evidence "$be/diff.raw" 1 200000 "$be/m3500.txt" 1 3500 "$be"
[ "$(cat "$be/truncated")" = 0 ] && ok || bad "a full 3500-file manifest must be complete"
[ "$(orl_enforce_completeness PASS "$(cat "$be/truncated")")" = "PASS" ] && ok || bad "complete retrieval beyond 3000 must let a PASS stand"

# 8) A successful but EMPTY manifest (a 0-file PR) is complete, not unavailable.
printf 'diff --git a b\n+ok\n' > "$be/diff.raw"; : > "$be/m0.txt"
orl_build_evidence "$be/diff.raw" 1 200000 "$be/m0.txt" 1 0 "$be"
[ "$(cat "$be/truncated")" = 0 ] && ok || bad "a successful empty manifest (0 of 0) must be complete"
# A FAILED manifest fetch, by contrast, blocks PASS regardless of the file body.
orl_build_evidence "$be/diff.raw" 1 200000 "$be/m0.txt" 0 0 "$be"
[ "$(cat "$be/truncated")" = 1 ] && ok || bad "a failed manifest fetch must block PASS"

# --- terminal-CI gate (#692): the paid review consumes TERMINAL, GREEN CI -------
# The reviewer must not freeze a pre-terminal CI snapshot; a pending required
# check defers (no verdict), and a failed one can never PASS.
REQ="docs-truth doctor gate tests"
green="docs-truth: completed/success
doctor: completed/success
gate: completed/success
tests: completed/success"
pending="docs-truth: completed/success
doctor: completed/success
gate: in_progress/pending
tests: queued/pending"
failed="docs-truth: completed/success
doctor: completed/failure
gate: completed/success
tests: completed/success"
cancelled="docs-truth: completed/success
doctor: completed/cancelled
gate: completed/success
tests: completed/success"
missing="docs-truth: completed/success
doctor: completed/success
gate: completed/success"
# terminal: every required check reached "completed" (pass OR fail); the reviewer
# may run. pending / missing are NOT terminal → defer, fail closed.
printf '%s\n' "$green"     | orl_checks_terminal $REQ && ok || bad "all-completed checks must be terminal"
printf '%s\n' "$failed"    | orl_checks_terminal $REQ && ok || bad "a completed-but-failed set is still terminal"
printf '%s\n' "$cancelled" | orl_checks_terminal $REQ && ok || bad "a completed-but-cancelled set is still terminal"
printf '%s\n' "$pending"   | orl_checks_terminal $REQ && bad "a pending required check must NOT be terminal" || ok
printf '%s\n' "$missing"   | orl_checks_terminal $REQ && bad "a missing required check must NOT be terminal" || ok
printf '' | orl_checks_terminal $REQ && bad "an empty check set must NOT be terminal" || ok
# A re-run can add a SECOND entry for the same name in unspecified order. If ANY
# run for a required check is still non-terminal, the set is not terminal — the
# predicate scans every line, not just the first (independent-review hardening).
rerun="docs-truth: completed/success
doctor: completed/success
gate: completed/success
tests: completed/success
tests: in_progress/pending"
printf '%s\n' "$rerun" | orl_checks_terminal $REQ && bad "a re-run pending entry must make the set non-terminal" || ok
printf '%s\n' "$rerun" | orl_checks_passed  $REQ && bad "a re-run pending entry must not be passed" || ok
# passed: every required check is completed/success. Only green passes; a failed,
# cancelled, pending, or missing check is not-passed → a PASS is downgraded.
printf '%s\n' "$green"     | orl_checks_passed $REQ && ok || bad "all-green checks must be passed"
printf '%s\n' "$failed"    | orl_checks_passed $REQ && bad "a failed required check must NOT be passed" || ok
printf '%s\n' "$cancelled" | orl_checks_passed $REQ && bad "a cancelled required check must NOT be passed" || ok
printf '%s\n' "$pending"   | orl_checks_passed $REQ && bad "a pending required check must NOT be passed" || ok
printf '%s\n' "$missing"   | orl_checks_passed $REQ && bad "a missing required check must NOT be passed" || ok
# End to end (#692): pending CI defers (never a terminal verdict); once terminal
# and green, a PASS stands; terminal-but-failed downgrades a PASS to NOT ASSESSED.
if printf '%s\n' "$pending" | orl_checks_terminal $REQ; then bad "pending must defer, not review"; else ok; fi
if printf '%s\n' "$green" | orl_checks_terminal $REQ && printf '%s\n' "$green" | orl_checks_passed $REQ; then
  [ "$(orl_enforce_completeness PASS 0)" = "PASS" ] && ok || bad "terminal-green complete evidence must let PASS stand"
else bad "terminal-green must be reviewable and passed"; fi
if printf '%s\n' "$failed" | orl_checks_passed $REQ; then bad "failed CI must not be passed"; else
  # the workflow maps not-passed → NOT ASSESSED for a would-be PASS
  ok
fi
# Criterion-7 transition: each event checks terminality ONCE; the pending events
# defer (no verdict, reservation stays pending) and the completion event that first
# sees terminal-green reviews. Modelled as the sequence of per-event outcomes: the
# decision stays "defer" until the terminal snapshot, then becomes "review" once.
seq_reviewed=0
for snap in "$pending" "$pending" "$green"; do
  if printf '%s\n' "$snap" | orl_checks_terminal $REQ; then seq_reviewed=$((seq_reviewed + 1)); fi
done
[ "$seq_reviewed" = 1 ] && ok || bad "pending→pending→green must become reviewable exactly once, got $seq_reviewed"

# Static workflow facts: the workflow fetches, delegates to the tested helper, and
# enforces the flag; the derived logic itself is proven by the fixtures above.
haswf "retrieves every path via uncapped GraphQL"     'files\(first:100,after:\$endCursor\)'
haswf "paginates the GraphQL manifest"                'gh api graphql --paginate'
haswf "reads the trusted changed_files count"         'changed_files="\$\(gh api'
haswf "counts manifest records newline-safely"        '\.path\|@json'
haswf "builds evidence through the tested helper"     'orl_build_evidence /tmp/rev/diff.raw'
haswf "tracks the manifest-fetch outcome"             'manifest_fetch_ok=0'
haswf "labels the trusted machine-generated status"   'DIFF COMPLETENESS'
haswf "always supplies the manifest as untrusted data" 'UNTRUSTED CHANGED-FILE MANIFEST'
haswf "enforces completeness on the verdict"          'orl_enforce_completeness "\$model_verdict"'
haswf "an unreadable completeness flag fails closed"   'cat /tmp/rev/truncated 2>/dev/null \|\| echo 1'
haswf_not "no silent head -c bound without detection" 'head -c 200000 /tmp/rev/diff.txt'
# Terminal-CI continuation (#692): check terminality once; resume via completion.
haswf "re-fires on required-check completion"         'workflow_run:'
haswf "watches the required-check workflows"          'workflows: \[validate, docs-truth, milestone-gate\]'
haswf "resolves the target PR and HEAD from either event" 'Resolve target PR and HEAD'
haswf "serializes by exact HEAD SHA"                  'openai-review-\$\{\{ github.event.pull_request.head.sha'
haswf "checks terminality with the tested helper"     'orl_checks_terminal \$required'
haswf "requires all required checks green to pass"    'orl_checks_passed \$required'
haswf "a non-green terminal HEAD cannot pass"         'CI_PASSED'
haswf "resumes a pending reservation, never re-reviews" 'orl_has_final_marker'
haswf "reviews only when checks are terminal"         "steps.ci.outputs.terminal == 'true'"
haswf_not "no bounded-wait timeout that can freeze a verdict" 'ci-not-terminal-timeout'

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
