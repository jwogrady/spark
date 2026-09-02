#!/usr/bin/env bash
# Behavioral tests for the OpenAI reviewer lane (#584).
#
# Three ways, like the coding lane's suite: static facts about the workflow,
# the real canonical functions on synthetic input, and discriminating controls
# — flip a load-bearing line and the matching assertion goes red.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wf="$here/../.github/workflows/openai-review.yml"
lib="$here/../.github/scripts/openai-review/lib.sh"
# shellcheck source=/dev/null
. "$lib"

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

echo "OpenAI reviewer lane (#584)"

bash -n "$lib" && ok || bad "bash -n lib.sh"

# --- static workflow facts ---------------------------------------------------
haswf()    { if grep -qE -- "$2" "$wf"; then ok; else bad "$1 — workflow lacks /$2/"; fi; }
haswf_not(){ if grep -qE -- "$2" "$wf"; then bad "$1 — workflow wrongly matches /$2/"; else ok; fi; }

haswf    "fires on the four PR event types" 'types: \[opened, synchronize, reopened, ready_for_review\]'
haswf    "reads contents, never writes them"        'contents: read'
# The load-bearing negative control: a reviewer that gains contents:write has
# become a coding lane. If read ever flips to write, this assertion goes red.
haswf_not "the job has NO contents: write"          'contents: write'
haswf_not "no publish deploy key in this lane"       'DEPLOY_KEY|CLAUDE_PUBLISH'
haswf    "posts the verdict via pull-requests: write" 'pull-requests: write'
haswf    "checkout persists no credential"           'persist-credentials: false'
haswf    "one review per PR via concurrency"         'concurrency:'
haswf    "a new push cancels the stale-HEAD review"  'cancel-in-progress: true'
haswf    "the review call reads OPENAI_API_KEY from secrets" 'OPENAI_API_KEY: \$\{\{ secrets.OPENAI_API_KEY \}\}'
haswf    "fail-closed when the key is absent"        'OPENAI_API_KEY is not available'
haswf    "fail-closed when the reviewer is unreachable" 'could not be reached \(HTTP'
haswf    "sources the canonical function library"    'openai-review/lib.sh'
haswf    "guards on an already-reviewed HEAD"         'already-reviewed|already=true|orl_reviewed_head'

# --- orl_normalize_verdict ---------------------------------------------------
nv() { eq="$1"; got="$(orl_normalize_verdict "$2")"; [ "$got" = "$eq" ] && ok || bad "normalize '$2' — want '$eq' got '$got'"; }
nv PASS                "PASS"
nv "CHANGES REQUIRED"  "CHANGES REQUIRED"
nv "DECISION REQUIRED" "DECISION REQUIRED"
nv "NOT ASSESSED"      "NOT ASSESSED"
nv PASS                "PASS — nothing blocking"          # trailing rationale stripped
nv "CHANGES REQUIRED"  "  CHANGES REQUIRED  "             # surrounding space trimmed
nv "NOT ASSESSED"      ""                                  # empty fails closed
nv "NOT ASSESSED"      "looks good to me"                  # unknown fails closed
nv "NOT ASSESSED"      "pass"                              # wrong case fails closed (never a false PASS)
nv "NOT ASSESSED"      "APPROVED"                          # a star-rating word is not the vocabulary
# stdin form must agree with the argument form
got="$(printf 'PASS: ship it\n' | orl_normalize_verdict)"; [ "$got" = "PASS" ] && ok || bad "normalize via stdin — got '$got'"

# --- orl_closing_issues ------------------------------------------------------
ci() { got="$(printf '%s' "$2" | orl_closing_issues | paste -sd, -)"; [ "$got" = "$1" ] && ok || bad "closing_issues '$2' — want '$1' got '$got'"; }
ci "12"     "closes #12"
ci "7"      "Fixes #7"
ci "9"      "resolves #9"
ci "1,2,3"  "closes #2, fixes #1, resolves #3"
ci "5"      "closes #5 and closes #5"                      # deduped
ci ""       "see #4 and related #8"                        # bare mentions are not a contract
ci ""       "no references here"

# --- orl_marker + orl_reviewed_head (one verdict per HEAD) --------------------
m="$(orl_marker PASS 678 abc123)"
case "$m" in *"spark-openai-review pr=678 head=abc123 verdict=PASS"*) ok ;; *) bad "marker shape wrong: $m" ;; esac

# a comment carrying the marker for HEAD abc123 counts as reviewed…
printf '%s\n' "$m" | orl_reviewed_head abc123 && ok || bad "reviewed HEAD not detected"
# …but a different HEAD (a synchronize push) is NOT deduped — it gets reviewed.
printf '%s\n' "$m" | orl_reviewed_head def456 && bad "a new HEAD was wrongly treated as reviewed" || ok
# an empty head never matches
printf '%s\n' "$m" | orl_reviewed_head "" && bad "empty head matched" || ok
# no reviewer comment at all -> not reviewed
printf 'just a human comment\n' | orl_reviewed_head abc123 && bad "matched with no marker" || ok
# a NOT ASSESSED verdict still marks the HEAD reviewed (it was assessed and failed closed)
printf '%s\n' "$(orl_marker "NOT ASSESSED" 678 abc123)" | orl_reviewed_head abc123 && ok || bad "NOT ASSESSED marker not detected"

# --- orl_route ---------------------------------------------------------------
case "$(orl_route PASS)" in *"READY FOR HUMAN MERGE"*) ok ;; *) bad "PASS route wrong" ;; esac
case "$(orl_route "CHANGES REQUIRED")" in *"@claude"*"do not merge"*) ok ;; *) bad "CHANGES route must hand to @claude and forbid merge" ;; esac
case "$(orl_route "DECISION REQUIRED")" in *"@jwogrady"*) ok ;; *) bad "DECISION route must stop for the human" ;; esac
case "$(orl_route "NOT ASSESSED")" in *"not reviewed"*) ok ;; *) bad "NOT ASSESSED route wrong" ;; esac

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
