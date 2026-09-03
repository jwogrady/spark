#!/usr/bin/env bash
# Spark #710 — the smallest deterministic helper that projects the CANONICAL
# governor fact onto a pull request, derived from the SAME repository-local
# canonical governor authority as the commit `Spark-Governed-By` trailer.
#
# It records ONLY governor identity: `Governed by Spark vX.Y.Z`. The richer
# GitHub provenance card/check and multi-actor execution provenance (writer /
# reviewer / orchestrator, model / provider / surface / run) are #711 — this
# helper deliberately does none of that.
#
# Usage:
#   governed-pr.sh version              -> print vX.Y.Z; exit 3 when ungoverned
#   governed-pr.sh line                 -> print "Governed by Spark vX.Y.Z"
#   governed-pr.sh ensure <body-file>   -> print the body carrying exactly one
#                                          canonical fact; fail on conflict/dup/
#                                          noncanonical; idempotent when correct
#   governed-pr.sh agree <ver> <file>   -> exit 0 iff the body's fact == <ver>
#   governed-pr.sh apply <pr-number>    -> gh: create/update the PR body then
#                                          validate exactly-one canonical fact
set -euo pipefail

FACT_CANON='^Governed by Spark v[0-9]+\.[0-9]+\.[0-9]+$'
# A governor CLAIM is "Governed by Spark <version>" anywhere it is asserted,
# including behind Markdown list/quote/heading prefixes (- * + > #) or an ordered
# list number, so a claim like `- Governed by Spark v9.9.9` cannot hide from the
# conflict/duplicate check and be left contradicting the canonical line. Only the
# bare canonical form (FACT_CANON) is ever accepted; every other match is rejected.
FACT_ANY='^[[:space:]]*([*+>#-][[:space:]]*|[0-9]+\.[[:space:]]*)*Governed by Spark[[:space:]]+v?[0-9]'

gp_die() { echo "governed-pr: $1" >&2; exit "${2:-1}"; }

# The version is the SAME authority the commit-msg hook uses: the REPOSITORY-LOCAL
# pin's own `spark version`, an exact released X.Y.Z. A global/system pin is never
# consulted, and an ungoverned repo returns exit 3 (fact absent, never fabricated).
gp_version() {
  local pin out rc=0 raw
  pin="$(git config --local --get spark.governorBin 2>/dev/null || true)"
  [ -n "$pin" ] || return 3
  [ -x "$pin" ] || gp_die "the pinned governor is not executable: $pin"
  # Capture and check the governor command's STATUS explicitly — a governor that
  # prints a valid-looking version but exits nonzero must NOT be trusted. Do not
  # rely on errexit/pipefail here: this runs inside command substitutions and `||`.
  out="$("$pin" version 2>/dev/null)" || rc=$?
  [ "$rc" -eq 0 ] || gp_die "the pinned governor ($pin) failed (exit $rc); cannot resolve governance"
  raw="$(printf '%s\n' "$out" | awk '{ print $NF }')"
  printf '%s' "$raw" | grep -qxE '[0-9]+\.[0-9]+\.[0-9]+' \
    || gp_die "the pinned governor reported '$raw', not a released vX.Y.Z"
  printf 'v%s' "$raw"
}

# Print the body carrying exactly one canonical fact for $want, or fail closed.
gp_ensure() {
  local file="$1" want="$2" seen line
  seen="$(grep -icE "$FACT_ANY" "$file" 2>/dev/null || true)"
  if [ "${seen:-0}" -gt 1 ]; then
    gp_die "the PR already carries ${seen} 'Governed by Spark' claims; it is recorded exactly once" 2
  fi
  if [ "${seen:-0}" -eq 1 ]; then
    line="$(grep -iE "$FACT_ANY" "$file" | head -n1 | sed -E 's/^[[:space:]]*//')"
    printf '%s' "$line" | grep -qE "$FACT_CANON" \
      || gp_die "the PR governor line must be exactly 'Governed by Spark vX.Y.Z' (got '$line')" 2
    [ "$line" = "Governed by Spark $want" ] \
      || gp_die "the PR claims '$line' but the governor is 'Governed by Spark $want'; remove the conflicting claim" 2
    cat "$file"; return 0
  fi
  # Absent: append the canonical fact as a trailing line, one blank line clear of
  # the body (trailing blank lines trimmed so re-application never drifts).
  local body; body="$(sed -e :a -e '/^[[:space:]]*$/{$d;N;ba}' "$file")"
  if [ -n "$body" ]; then printf '%s\n\nGoverned by Spark %s\n' "$body" "$want"
  else printf 'Governed by Spark %s\n' "$want"; fi
}

case "${1:-}" in
  version) gp_version || exit $? ;;
  line)
    want=""; want="$(gp_version)" || exit $?
    printf 'Governed by Spark %s\n' "$want" ;;
  ensure)
    [ -n "${2:-}" ] && [ -f "$2" ] || gp_die "ensure needs a body file"
    want=""; want="$(gp_version)" || exit $?
    gp_ensure "$2" "$want" ;;
  agree)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] && [ -f "$3" ] || gp_die "agree needs <version> <body-file>"
    seen="$(grep -iE "$FACT_ANY" "$3" | head -n1 | sed -E 's/^[[:space:]]*//')"
    [ -n "$seen" ] || gp_die "the PR carries no governor fact to compare" 2
    [ "$seen" = "Governed by Spark $2" ] \
      || gp_die "commit governor '$2' and PR governor '$seen' disagree" 2 ;;
  apply)
    [ -n "${2:-}" ] || gp_die "apply needs a PR number"
    pr="$2"; want=""; want="$(gp_version)" || exit $?
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    body="$(gh pr view "$pr" --json body -q .body 2>/dev/null)" || gp_die "could not read PR #$pr body via gh"
    printf '%s' "$body" > "$tmp"
    ensured="$(gp_ensure "$tmp" "$want")"
    if [ "$ensured" != "$body" ]; then
      printf '%s' "$ensured" | gh pr edit "$pr" --body-file - >/dev/null \
        || gp_die "could not update PR #$pr body via gh"
      echo "governed-pr: projected 'Governed by Spark $want' onto PR #$pr"
    else
      echo "governed-pr: PR #$pr already carries 'Governed by Spark $want' (idempotent)"
    fi
    # Round-trip validation, independent of commit topology: re-read the PR body
    # from GitHub and confirm exactly one canonical fact for the governor.
    gh pr view "$pr" --json body -q .body > "$tmp" 2>/dev/null || gp_die "could not re-read PR #$pr body"
    gp_ensure "$tmp" "$want" >/dev/null
    n="$(grep -cE "$FACT_CANON" "$tmp" || true)"
    [ "${n:-0}" = 1 ] || gp_die "post-apply validation failed: PR #$pr lacks exactly one canonical governor fact" ;;
  *) gp_die "usage: governed-pr.sh version|line|ensure <file>|agree <ver> <file>|apply <pr>" 2 ;;
esac
