#!/usr/bin/env bash
# Benchmark-vocabulary parity guard (issue #666). AGENTS.md is the canonical
# AI-agent contract. #662 bounded the benchmark's own vocabulary: the shimmed
# count is a lower bound on subprocesses (never a total of "external
# processes"), and the gh count is invocations (never a count of "remote
# requests"/HTTP). The canonical guidance must not drift back to the
# overclaiming accounting terms bench.sh explicitly disavows — the lockstep
# check that #666 found missing.
#
# The match is whitespace-normalized because Markdown prose reflows: a phrase
# split across two wrapped lines is the same claim. bench.sh's own warning is
# out of scope by construction — the guard reads only the canonical guidance,
# which is where a drifting overclaim would actually mislead an agent.

set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"
guide="$root/AGENTS.md"

[ -f "$guide" ] && ok || bad "#666: AGENTS.md (the canonical contract) must exist"

# One whitespace-normalized view of the guidance; reflow cannot hide a phrase.
norm="$(tr -s '[:space:]' ' ' < "$guide")"

# The two accountings bench.sh does not perform must not describe its counts
# here. Fragments are assembled so this guard never matches its own source.
case "$norm" in
  *"external ""process"*) bad "#666: AGENTS.md calls benchmark counts 'external processes' — an overclaim bench.sh disavows" ;;
  *) ok ;;
esac
case "$norm" in
  *"remote ""request"*) bad "#666: AGENTS.md calls benchmark counts 'remote requests' — an overclaim bench.sh disavows" ;;
  *) ok ;;
esac

# Positive parity: the bounded framing must be present AND tied to the count it
# bounds, so an inverted claim ("a total of subprocesses", "a count of HTTP
# requests") fails the guard rather than passing merely because the noun appears
# somewhere. The `[^.]*` windows never cross a sentence boundary, so the tie is
# real: the same clause must both name the count and bound it.
tied_shimmed='shimmed[^.]*invocation[^.]*lower bound'
tied_gh='gh[^.]*invocation[^.]*not a count of HTTP request'

printf '%s\n' "$norm" | grep -qE "$tied_shimmed" \
  && ok || bad "#666: AGENTS.md must tie the shimmed count to 'lower bound' (reject a total/full-accounting claim)"
printf '%s\n' "$norm" | grep -qE "$tied_gh" \
  && ok || bad "#666: AGENTS.md must tie gh invocations to 'not a count of HTTP requests'"

# Discriminating negative controls (#677): prove in-suite that the tied
# assertions REJECT contradictory wording, not merely confirm the nouns appear.
inverted_gh='shimmed-command invocations (a lower bound on subprocesses), and gh invocations (a count of HTTP requests)'
printf '%s\n' "$inverted_gh" | grep -qE "$tied_gh" \
  && bad "#666: the gh tie must reject 'gh invocations (a count of HTTP requests)'" || ok
inverted_shimmed='shimmed-command invocations (a total of subprocesses), and gh invocations (not a count of HTTP requests)'
printf '%s\n' "$inverted_shimmed" | grep -qE "$tied_shimmed" \
  && bad "#666: the shimmed tie must reject a 'total of subprocesses' claim" || ok

# Cross-surface parity: bench.sh remains the source of the bounded vocabulary,
# tying the same counts to the same bounds so guidance and instrument agree.
bench="$root/tests/bench.sh"
bnorm="$(tr -s '[:space:]' ' ' < "$bench")"
printf '%s\n' "$bnorm" | grep -qE 'shimmed[^.]*lower bound' \
  && ok || bad "#666: bench.sh must tie its shimmed count to a 'lower bound'"
printf '%s\n' "$bnorm" | grep -qiE 'gh[^.]*invocation[^.]*not[^.]*HTTP request' \
  && ok || bad "#666: bench.sh must tie gh invocations to 'not ... HTTP requests'"

finish
