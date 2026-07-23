#!/usr/bin/env bash
# Behavioral suite for the PR-level capability-traceability enforcement (#301).
# Sources the check (main is source-guarded) and drives trace_pr_verdict — the
# pure decision — across title types and body shapes. No network, no gh.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/.github/scripts/pr-traceability-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

bash -n "$script" && ok || bad "bash -n pr-traceability-check.sh"
. "$script"

with_body() { printf '%s\n' "$1" > "$work/body.md"; }

# feat PR with the section -> PASS, exit 0.
with_body '## Summary
stuff
## Capability traceability
- Owned surface: gaps'
rc=0; out="$(trace_pr_verdict 'feat: add thing' "$work/body.md")" || rc=$?
[ "$rc" -eq 0 ] && ok || bad "feat+section — want 0, got $rc"
case "$out" in PASS:*) ok ;; *) bad "feat+section — want PASS ($out)" ;; esac

# every capability-proposing title form is enforced.
with_body '## Summary only'
for t in 'feat: x' 'feat(scope): x' 'feat!: x' 'feat(scope)!: x'; do
  rc=0; out="$(trace_pr_verdict "$t" "$work/body.md")" || rc=$?
  { [ "$rc" -ne 0 ] && case "$out" in FAIL:*missing*) true ;; *) false ;; esac; } \
    && ok || bad "'$t' without section must FAIL ($rc: $out)"
done

# non-feat titles are skipped honestly (never blocked, never claimed assessed).
for t in 'fix: y' 'docs: y' 'chore(scope): y' 'release: harden' 'feature: imposter'; do
  rc=0; out="$(trace_pr_verdict "$t" "$work/body.md")" || rc=$?
  { [ "$rc" -eq 0 ] && case "$out" in SKIP:*) true ;; *) false ;; esac; } \
    && ok || bad "'$t' must SKIP ($rc: $out)"
done

# heading match is a real heading, case-insensitive, tolerant of ###.
with_body '### capability TRACEABILITY
- filled in'
rc=0; out="$(trace_pr_verdict 'feat: z' "$work/body.md")" || rc=$?
[ "$rc" -eq 0 ] && ok || bad "case-insensitive/### heading must PASS ($rc: $out)"

# the phrase buried in prose (not a heading) does not count.
with_body 'we discuss capability traceability in passing here'
rc=0; out="$(trace_pr_verdict 'feat: z' "$work/body.md")" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "prose mention without a heading must FAIL"

# missing body file -> FAIL, not a crash.
rc=0; out="$(trace_pr_verdict 'feat: z' "$work/nosuch.md")" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in FAIL:*unavailable*) true ;; *) false ;; esac; } \
  && ok || bad "missing body file must FAIL cleanly ($rc: $out)"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
