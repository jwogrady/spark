#!/usr/bin/env bash
# Behavioural suite for #484 — docs-truth as a required release-readiness check.
#
# A release could previously go green while current-state documentation was
# stale, because documentation was a human checkbox and the three binding gates
# said nothing about it.
#
# The properties that carry the design, and that a plausible implementation gets
# wrong while still looking right:
#
#   * NOT ASSESSED is never green. A gate that cannot tell "passed" from "could
#     not look" is not a gate, so an unreadable layer must never exit 0 — and the
#     report must name which layer went unassessed and why.
#   * A verdict is bound to an exact HEAD SHA. When the release PR moves, the
#     previous verdict describes an earlier tree and is stale by arithmetic.
#   * The verdict lives in GitHub evidence and is never written into the tree.
#     Committing it would put change-over-time evidence into a current-state
#     surface — the very thing the ownership contract forbids. A gate that
#     forces its own violation is worthless.
#   * The semantic layer's whole value is NARROWING: a bounded per-issue claim
#     list, never "review the docs".
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "docs-truth release readiness (#484)"
sandbox_init

DT="$repo_root/.github/scripts/docs-truth.sh"
[ -x "$DT" ] && ok || bad "docs-truth.sh must exist and be executable"

PROJ="$WORK/proj"
make_repo "$PROJ"
mkdir -p "$PROJ/plugins/spark/bin" "$WORK/bin"
printf '# Roadmap\n\n## v0.23\n\nplanned outcomes\n' > "$PROJ/ROADMAP.md"

# A stub doctor, so the structural layer is exercised deterministically rather
# than depending on the real repository's health.
cat > "$PROJ/plugins/spark/bin/spark" <<'DOC'
#!/usr/bin/env bash
exit "${DOCTOR_RC:-0}"
DOC
chmod +x "$PROJ/plugins/spark/bin/spark"

# The gh stub returns already-projected output, because the real gh applies the
# --jq filter itself.
export GH_MILESTONES="$WORK/milestones" GH_ISSUES="$WORK/issues" GH_COMMENTS="$WORK/comments"
printf 'v0.23 — Execution efficiency\n' > "$GH_MILESTONES"
: > "$GH_ISSUES"; : > "$GH_COMMENTS"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
# GH_FAIL simulates a read that could not be performed, which is a different
# fact from a read that legitimately returned nothing.
[ -n "${GH_FAIL:-}" ] && exit 1
case "${1:-}" in
  api)   [ -s "$GH_MILESTONES" ] && cat "$GH_MILESTONES"; exit 0 ;;
  issue) [ -s "$GH_ISSUES" ] && cat "$GH_ISSUES"; exit 0 ;;
  pr)    [ -s "$GH_COMMENTS" ] && cat "$GH_COMMENTS"; exit 0 ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh"

MS="v0.23 — Execution efficiency"
# The capture helper must not propagate docs-truth's verdict code: a non-zero
# exit inside a command substitution is fatal under `set -e`, and here the
# non-zero verdict is the thing under test.
run_dt() { ( cd "$PROJ" && PATH="$WORK/bin:$PATH" bash "$DT" "$@" 2>&1 ) || true; }
rc_dt()  { ( cd "$PROJ" && PATH="$WORK/bin:$PATH" bash "$DT" "$@" >/dev/null 2>&1 ); }

rc() {
  local want="$1" desc="$2" got=0; shift 2
  rc_dt "$@" || got=$?
  if [ "$got" = "$want" ]; then ok; else bad "$desc (wanted rc $want, got $got)"; fi
}

# --- NOT ASSESSED is never green ---------------------------------------------
printf '480\tdocs-impact:none\n' > "$GH_ISSUES"
rc 3 "no milestone leaves the release scope unknown" --pr 1
OUT="$(run_dt --pr 1)"
assert_contains "and it names the unassessed layer" "dispositions — no milestone given" "$OUT"
assert_contains "and says so in the verdict"        "never green" "$OUT"
case "$OUT" in *"PASS — the repository"*) bad "an unassessed run must not report overall PASS" ;; *) ok ;; esac

# A GitHub read that fails is an unknown, never an implicit pass. (Emptying PATH
# entirely would remove bash and prove nothing but that 127 exists.)
export GH_FAIL=1
NOGH="$(run_dt --milestone "$MS")"
rc 3 "an unreadable milestone list is NOT ASSESSED" --milestone "$MS"
assert_contains "and names what could not be read" "milestone list could not be read" "$NOGH"
case "$NOGH" in *"PASS — the repository"*) bad "an unreadable GitHub read must not pass" ;; *) ok ;; esac
unset GH_FAIL

# An empty result is a different fact: no open milestone genuinely needs a
# section, and that is a pass rather than an unknown.
: > "$GH_MILESTONES"
assert_contains "an empty milestone list is a complete answer" "no open milestone requires a section" \
  "$(run_dt --milestone "$MS")"
printf 'v0.23 — Execution efficiency\n' > "$GH_MILESTONES"

# --- the structural layer composes doctor ------------------------------------
rc 0 "a clean release with no claims passes" --milestone "$MS"
assert_contains "structural truth is doctor's verdict, not a reimplementation" \
  "structural — spark doctor reports no errors" "$(run_dt --milestone "$MS")"

DOCTOR_RC=1
export DOCTOR_RC
rc 1 "a failing doctor fails the gate" --milestone "$MS"
assert_contains "and attributes it to doctor" "spark doctor reports errors" "$(run_dt --milestone "$MS")"
DOCTOR_RC=0

# --- roadmap coverage --------------------------------------------------------
printf 'v0.23 — Execution efficiency\nv0.99 — Unwritten\n' > "$GH_MILESTONES"
rc 1 "an open milestone with no ROADMAP section fails" --milestone "$MS"
assert_contains "and names the milestone" "v0.99" "$(run_dt --milestone "$MS")"
printf 'v0.23 — Execution efficiency\n' > "$GH_MILESTONES"

# --- dispositions ------------------------------------------------------------
# A release is blocked solely by an issue that never declared its documentation
# impact, with every other layer green.
printf '480\tdocs-impact:none\n491\t\n' > "$GH_ISSUES"
rc 1 "an undeclared documentation impact blocks the release" --milestone "$MS"
BLOCK="$(run_dt --milestone "$MS")"
assert_contains "and names the offending issue" "#491" "$BLOCK"
assert_contains "while the other layers still pass" "PASS          structural" "$BLOCK"

# `none` is a complete answer, not an omission.
printf '480\tdocs-impact:none\n481\tdocs-impact:none\n' > "$GH_ISSUES"
rc 0 "a release where nothing changed documentation passes" --milestone "$MS"
assert_contains "and says no issue changed documentation" "no issue in this release changed documentation" \
  "$(run_dt --milestone "$MS")"

# --- the semantic layer narrows ----------------------------------------------
printf '480\tdocs-impact:none\n436\tdocs-impact:reference\n437\tdocs-impact:operator\n' > "$GH_ISSUES"
: > "$GH_COMMENTS"
rc 3 "claims with no verdict are NOT ASSESSED" --milestone "$MS" --pr 618
CLAIMS="$(run_dt --milestone "$MS" --pr 618)"
assert_contains "the claim list is bounded and per-issue" "Claims requiring review:" "$CLAIMS"
assert_contains "naming the first claim"  "#436" "$CLAIMS"
assert_contains "naming the second claim" "#437" "$CLAIMS"
case "$CLAIMS" in *"#480"*) bad "an issue declaring docs-impact:none is not a claim" ;; *) ok ;; esac

# --- staleness is arithmetic --------------------------------------------------
printf 'reviewer-one:::docs-truth: aaaaaaa\n#436 PASS\n#437 PASS\n' > "$GH_COMMENTS"
rc 0 "a verdict covering every claim at the reviewed head passes" \
  --milestone "$MS" --pr 618 --head aaaaaaa
assert_contains "and credits the GitHub reviewer identity" "by @reviewer-one" \
  "$(run_dt --milestone "$MS" --pr 618 --head aaaaaaa)"

rc 1 "the same verdict is stale once the PR head moves" \
  --milestone "$MS" --pr 618 --head bbbbbbb
STALE="$(run_dt --milestone "$MS" --pr 618 --head bbbbbbb)"
assert_contains "and names the verdict's head" "aaaaaaa" "$STALE"
assert_contains "and the current head"         "bbbbbbb" "$STALE"

# --- a verdict must cover every claim, and PASS every one --------------------
printf 'reviewer-one:::docs-truth: aaaaaaa\n#436 PASS\n' > "$GH_COMMENTS"
rc 1 "a claim the verdict never mentions fails" --milestone "$MS" --pr 618 --head aaaaaaa
assert_contains "and names the unverified claim" "#437" \
  "$(run_dt --milestone "$MS" --pr 618 --head aaaaaaa)"

printf 'reviewer-one:::docs-truth: aaaaaaa\n#436 PASS\n#437 FAIL\n' > "$GH_COMMENTS"
rc 1 "a failing claim fails the gate" --milestone "$MS" --pr 618 --head aaaaaaa
assert_contains "and marks it as failing" "#437(FAIL)" \
  "$(run_dt --milestone "$MS" --pr 618 --head aaaaaaa)"

# --- the verdict is never written into the tree -------------------------------
printf 'reviewer-one:::docs-truth: aaaaaaa\n#436 PASS\n#437 PASS\n' > "$GH_COMMENTS"
before="$( (cd "$PROJ" && git status --porcelain) )"
rc_dt --milestone "$MS" --pr 618 --head aaaaaaa
after="$( (cd "$PROJ" && git status --porcelain) )"
if [ "$before" = "$after" ]; then ok
else bad "docs-truth must not write its verdict into the tree (tree changed: $after)"; fi

# --- the three verdicts are distinct ------------------------------------------
# PASS / FAIL / NOT ASSESSED must be three answers, not two plus a synonym.
assert_contains "PASS is stated plainly" "PASS — the repository describes" \
  "$(run_dt --milestone "$MS" --pr 618 --head aaaaaaa)"
DOCTOR_RC=1; export DOCTOR_RC
assert_contains "FAIL is stated plainly" "FAIL — documentation truth is not established" \
  "$(run_dt --milestone "$MS" --pr 618 --head aaaaaaa)"
DOCTOR_RC=0

# --- MUTATION CONTROL ---------------------------------------------------------
# Let NOT ASSESSED exit 0 — the single change that turns "we could not look"
# into "everything is fine". Every unassessed fixture must go red.
MUT="$WORK/docs-truth-mutant.sh"
sed 's|^  exit 3$|  exit 0|' "$DT" > "$MUT"
chmod +x "$MUT"
if ! cmp -s "$DT" "$MUT"; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

: > "$GH_COMMENTS"
mgot=0
( cd "$PROJ" && PATH="$WORK/bin:$PATH" bash "$MUT" --milestone "$MS" --pr 618 >/dev/null 2>&1 ) || mgot=$?
if [ "$mgot" = "3" ]; then
  bad "MUTATION control — NOT ASSESSED still exited 3; the fixture does not discriminate"
else ok; fi

finish
