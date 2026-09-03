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

# Positive parity: the bounded framing must be present, so the guard cannot pass
# merely because the benchmark sentence was deleted.
case "$norm" in
  *"lower bound"*) ok ;;
  *) bad "#666: AGENTS.md must describe the shimmed count as a lower bound, not a total" ;;
esac
case "$norm" in
  *"HTTP request"*) ok ;;
  *) bad "#666: AGENTS.md must describe gh invocations as not a count of HTTP requests" ;;
esac

# Cross-surface parity: bench.sh remains the source of the bounded vocabulary,
# so the guidance and the instrument keep claiming the same thing.
bench="$root/tests/bench.sh"
bnorm="$(tr -s '[:space:]' ' ' < "$bench")"
case "$bnorm" in
  *"lower bound"*) ok ;;
  *) bad "#666: bench.sh must retain its bounded 'lower bound' framing" ;;
esac
case "$bnorm" in
  *"HTTP request"*) ok ;;
  *) bad "#666: bench.sh must retain its 'not HTTP requests' framing" ;;
esac

finish
