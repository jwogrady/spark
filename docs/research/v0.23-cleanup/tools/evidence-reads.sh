#!/usr/bin/env bash
# evidence-reads.sh [commit] — observed default reads of the evidence corpus (#742).
#
# Runs the read-only, network-free spark verbs under strace and records every evidence-root path each one opens
# successfully: observed default-read behaviour in the #730 sense — what the runtime actually touches when a session
# runs its ordinary verbs, not what a directory listing contains and not what a grep finds cited.
#
# Two observation hazards are neutralized, because both would attribute git's work to Spark:
#   * a dirty working tree — `git status` reads every modified file, so the verbs run against a pristine clone
#     checked out at <commit> (default HEAD), never against the tree the author is editing;
#   * a cold index — after a fresh checkout every file's stat data is unknown to git, and entries written in the
#     same second as the index are "racily clean", so the next `git status` re-hashes the whole tree. Measured
#     here, that alone attributed 144 extra evidence-file reads to `spark brief`, nondeterministically. The tool
#     therefore warms the index and then *verifies* it by tracing a bare `git status`: until that opens nothing
#     under the evidence roots, no verb is measured.
# A directory open (traversal, as when a footprint is counted) is recorded as such and never counted as a file read.
#
# Output (TSV to stdout): header comments naming the observed commit, the tracer, the roots and each verb's exit
# status, then verb <TAB> kind <TAB> path <TAB> opens, kind being file, dir, or none for a verb that opened nothing.
# Fail-closed: a missing strace, a failed clone, an unrefreshed index, an untraceable verb, or a verb that exits
# non-zero aborts without writing a capture.
set -euo pipefail
command -v strace >/dev/null 2>&1 || { echo "strace is required to observe reads" >&2; exit 2; }
src="$PWD"; sha="$(git rev-parse "${1:-HEAD}")"
obs="$(mktemp -d)"; trace="$(mktemp)"; rows="$(mktemp)"; body="$(mktemp)"; status="$(mktemp)"
trap 'rm -rf "$obs" "$trace" "$rows" "$body" "$status"' EXIT
git clone -q --shared --no-checkout "$src" "$obs/tree"
git -C "$obs/tree" checkout -q --detach "$sha"
cd "$obs/tree"
[ -z "$(git status --porcelain)" ] || { echo "the observed checkout is not clean" >&2; exit 2; }
evidence_file_opens() { # evidence_file_opens <trace> — evidence-root FILES a trace opened (a directory is traversal)
  grep -v 'ENOENT' "$1" | grep -oE 'openat\([^"]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/' | sed -E "s|^$PWD/||" \
    | grep -E '^(docs/research|docs/releases|docs/governance|docs/ops|evaluations|\.spark)/' | grep -cve '/$' || true
}
# Warm the index, then prove it: a bare `git status` must open no evidence *file*. Entries written in the same
# second as the index are racily clean, so the sleep is not optional and `--really-refresh` is what rewrites the
# stat data. (`git status` still traverses directories to find untracked files; traversal is not a read.)
warm=0
for attempt in 1 2 3; do
  git status --porcelain >/dev/null
  sleep 1.2
  git update-index --really-refresh >/dev/null 2>&1 || true
  strace -f -qq -e trace=openat -o "$trace" git status --porcelain >/dev/null 2>&1 || true
  if [ "$(evidence_file_opens "$trace")" -eq 0 ]; then warm=1; break; fi
done
[ "$warm" -eq 1 ] || { echo "the observed checkout's index stays cold: git itself is reading the corpus" >&2; exit 2; }
# A fresh clone has no git hooks, and `spark doctor` exits non-zero when it finds that — a verdict about the
# observation environment, not about the corpus. Arming the disposable clone the way a developer's tree is armed
# lets every verb below be required to exit 0, so an incomplete run can never be mistaken for a capture.
bash plugins/spark/bin/spark install-git-hooks >/dev/null 2>&1 || { echo "could not arm the observed checkout" >&2; exit 2; }
[ -z "$(git status --porcelain)" ] || { echo "arming the checkout changed the tree" >&2; exit 2; }
for verb in doctor brief footprint preferences profiles list-skills; do
  : > "$trace"
  rc=0
  strace -f -qq -e trace=openat -o "$trace" bash plugins/spark/bin/spark "$verb" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { echo "spark $verb exited $rc: an incomplete run cannot be a capture" >&2; exit 2; }
  [ -s "$trace" ] || { echo "no trace for $verb" >&2; exit 2; }
  printf '# %s exit %s\n' "$verb" "$rc" >> "$status"
  # successful opens only (an ENOENT probe is not a read); paths made repository-relative; one row per path
  set +o pipefail
  grep -v 'ENOENT' "$trace" | grep -oE 'openat\([^"]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/' \
    | sed -E "s|^$PWD/||" | grep -E '^(docs/research|docs/releases|docs/governance|docs/ops|evaluations|\.spark)/' \
    | sort | uniq -c > "$rows"
  set -o pipefail
  if [ -s "$rows" ]; then
    while read -r n p; do
      kind=file; case "$p" in */) kind=dir ;; esac
      printf '%s\t%s\t%s\t%s\n' "$verb" "$kind" "$p" "$n" >> "$body"
    done < "$rows"
  else
    printf '%s\tnone\t-\t0\n' "$verb" >> "$body"
  fi
done
printf '# observed default reads — clean checkout of %s — %s — %s\n' "$sha" "$(strace -V | head -1)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '# roots: docs/research docs/releases docs/governance docs/ops evaluations .spark\n'
printf '# git index verified warm before tracing (a bare git status opened no evidence path), so no read below is git re-hashing a fresh checkout\n'
cat "$status"
printf 'verb\tkind\tpath\topens\n'
cat "$body"
