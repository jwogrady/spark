#!/usr/bin/env bash
# evidence-reads.sh [commit] — observed default reads of the evidence corpus (#742).
#
# Runs the read-only, network-free spark verbs under strace and records every evidence-root path each one opens
# successfully: observed default-read behaviour in the #730 sense — what the runtime actually touches when a session
# runs its ordinary verbs, not what a directory listing contains and not what a grep finds cited.
#
# The verbs run against a pristine clone checked out at <commit> (default HEAD), never against the working tree:
# `brief` shells out to `git status`, which reads every modified or untracked file, so a dirty tree would report the
# author's edits as runtime reads. Observing a commit makes the capture a function of that commit alone — rerun the
# tool at the same commit and the rows are the same. A directory open (traversal, as when a footprint is counted) is
# recorded as such and never counted as reading a file.
#
# Output (TSV to stdout): header comments naming the observed commit, the tracer and the roots, then
# verb <TAB> kind <TAB> path <TAB> opens, kind being file, dir, or none for a verb that opened nothing.
# Fail-closed: a missing strace, a failed clone or an untraceable verb aborts.
set -euo pipefail
command -v strace >/dev/null 2>&1 || { echo "strace is required to observe reads" >&2; exit 2; }
src="$PWD"; sha="$(git rev-parse "${1:-HEAD}")"
obs="$(mktemp -d)"; trace="$(mktemp)"; rows="$(mktemp)"
trap 'rm -rf "$obs" "$trace" "$rows"' EXIT
git clone -q --shared --no-checkout "$src" "$obs/tree"
git -C "$obs/tree" checkout -q --detach "$sha"
cd "$obs/tree"
[ -z "$(git status --porcelain)" ] || { echo "the observed checkout is not clean" >&2; exit 2; }
printf '# observed default reads — clean checkout of %s — %s — %s\n' "$sha" "$(strace -V | head -1)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '# roots: docs/research docs/releases docs/governance docs/ops evaluations .spark\n'
printf 'verb\tkind\tpath\topens\n'
for verb in doctor brief footprint preferences profiles list-skills; do
  : > "$trace"
  strace -f -qq -e trace=openat -o "$trace" bash plugins/spark/bin/spark "$verb" >/dev/null 2>&1 || true
  [ -s "$trace" ] || { echo "no trace for $verb" >&2; exit 2; }
  # successful opens only (an ENOENT probe is not a read); paths made repository-relative; one row per path
  set +o pipefail
  grep -v 'ENOENT' "$trace" | grep -oE 'openat\([^"]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/' \
    | sed -E "s|^$PWD/||" | grep -E '^(docs/research|docs/releases|docs/governance|docs/ops|evaluations|\.spark)/' \
    | sort | uniq -c > "$rows"
  set -o pipefail
  if [ -s "$rows" ]; then
    while read -r n p; do
      kind=file; case "$p" in */) kind=dir ;; esac
      printf '%s\t%s\t%s\t%s\n' "$verb" "$kind" "$p" "$n"
    done < "$rows"
  else
    printf '%s\tnone\t-\t0\n' "$verb"
  fi
done
