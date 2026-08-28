#!/usr/bin/env bash
# Behavioural suite for #512: an evidence layer that did not answer is not an
# answer that there was nothing there.
#
# `docs-impact --branch` aggregates the branch diff with every already-linked
# implementation PR. The linked-PR lookup's failure and its empty success both
# arrived as an empty string, so a transient GraphQL error silently reduced the
# evidence set to the branch diff and graded that as complete — turning a FAIL
# into a PASS with exit 0. Validate runs this verb, so the lifecycle proceeded.
#
# Each case below is a different ANSWER from the same layer, and the suite's
# whole point is that they must not be confused:
#
#   lookup fails          -> NOT ASSESSED, exit 3      (nothing is known)
#   lookup returns none   -> grade the branch alone    (a complete answer)
#   lookup returns a PR   -> union it in, then grade   (a complete answer)
#   the PR's files fail   -> NOT ASSESSED, exit 3      (partial is not whole)
#
# Measured discrimination, not asserted. Of the 30 assertions: restoring the
# branch-mode conflation turns 8 red — including the reported symptom exactly,
# PASS with exit 0 where a FAIL was due; restoring the default mode's half turns
# 2 red; restoring the duplicated human-mode line turns 1 red; and stopping the
# aggregate after the first linked PR turns 3 red.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

# ---------------------------------------------------------------- fixture
# A repo with a real remote-tracking ref, because di_trunk resolves the trunk
# from refs/remotes/origin/* and a branch diff against a fabricated ref would
# test the fixture rather than the verb. The ref is written directly rather than
# published: a suite that publishes to a trunk is a pattern the trunk guard
# exists to stop, and it reads as one even when the remote is a throwaway bare
# repo.
origin="$WORK/origin.git"; git init -q --bare "$origin"
repo="$WORK/r"; make_repo "$repo"
git -C "$repo" remote add origin "$origin"
git -C "$repo" update-ref refs/remotes/origin/master "$(git -C "$repo" rev-parse HEAD)"

# The branch changes CODE only. On its own it satisfies `docs-impact:none`.
git -C "$repo" checkout -q -b fix/77-code-only
mkdir -p "$repo/plugins/spark/bin"
echo 'echo hi' > "$repo/plugins/spark/bin/thing"
git -C "$repo" add -A
git -C "$repo" -c user.email=t@e.invalid -c user.name=T commit -qm "fix: code only"

# The earlier linked PR changed governed REFERENCE documentation. Unioned in,
# `docs-impact:none` must fail; dropped, it silently passes. That gap is the bug.
GOVERNED_PATH="plugins/spark/docs/reference/cli.md"

# ---------------------------------------------------------------- fake gh
# Authenticated throughout: #512 is not about an offline operator. The
# declaration lookup and repo identification always succeed, so the ONLY thing
# varying is the evidence layer under test.
shim="$WORK/shim"; mkdir -p "$shim"
for t in bash sh git grep sed awk cat cut tr sort head tail wc env printf mktemp \
         rm mkdir basename dirname date ls chmod touch find readlink uname; do
  src="$(command -v "$t" 2>/dev/null || true)"; [ -n "$src" ] && ln -sf "$src" "$shim/$t"
done
cat > "$shim/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view")   printf '%s\n' "o/r"; exit 0 ;;
  "issue view")  printf '%s\n' "docs-impact:none"; exit 0 ;;
  "api graphql")
    # The linked-PR query is PAGINATED, so its --jq output is a header line
    # "hasNextPage<TAB>endCursor" followed by the qualifying PR numbers. A stub
    # that emitted bare numbers could not express "successful but there is more",
    # which is the whole of #530.
    #
    # A successful EMPTY page still emits the header: that is what keeps it
    # distinguishable from a failed lookup, which emits nothing and exits 1.
    case "${EV_LOOKUP:-ok}" in
      fail)  exit 1 ;;
      empty) printf 'false\t\n'; exit 0 ;;
      two)   printf 'false\t\n%s\n%s\n' 11 12; exit 0 ;;
      paged|pagefail|nocursor)
        # Page 2 is requested with after=CUR1.
        case "$*" in
          *CUR1*)
            [ "${EV_LOOKUP}" = "pagefail" ] && exit 1
            printf 'false\t\n%s\n' 151; exit 0 ;;
          *)
            if [ "${EV_LOOKUP}" = "nocursor" ]; then
              # hasNextPage true with no cursor: uncontinuable. Refusing is the
              # only honest answer; continuing from the start would loop.
              printf 'true\t\n'
            else
              printf 'true\tCUR1\n'
            fi
            i=101; while [ "$i" -le 150 ]; do printf '%s\n' "$i"; i=$((i + 1)); done
            exit 0 ;;
        esac ;;
      *)     printf 'false\t\n%s\n' 9; exit 0 ;;
    esac ;;
  "api --paginate")
    case "${EV_FILES:-ok}" in
      fail) exit 1 ;;
      *)
        # Dispatch on the PR NUMBER, extracted rather than glob-matched, and
        # emit NOTHING for a number no fixture defines.
        #
        # The first cut let an unrecognised number fall through to the governed
        # path. Measuring the pre-fix implementation then "passed" for the wrong
        # reason: it read the page header as a node number, asked for that
        # bogus PR's files, and got the governed doc back — so the verdict was
        # right by accident and the assertion could not fail. A fixture whose
        # default answer is the interesting one cannot discriminate.
        pr="${3#*/pulls/}"; pr="${pr%/files}"
        case "$pr" in
          9)   printf '%s\n' "$EV_PATH" ;;
          11)  printf '%s\n' "plugins/spark/bin/spark" ;;
          # The documentation is deliberately in the LAST PR processed. Put it
          # first and a loop that stops after one PR still reaches the right
          # verdict, so the assertion could not fail — the union has to be
          # broken in the direction that changes the answer.
          12)  printf '%s\n' "$EV_PATH" ;;
          # 101-150 are connection page one and carry CODE only; 151 is on page
          # two and is the only governed documentation, so a single-page
          # implementation never sees it.
          151) printf '%s\n' "$EV_PATH" ;;
          1[0-4][0-9]|150) printf '%s\n' "plugins/spark/bin/spark" ;;
          *)   : ;;
        esac
        exit 0 ;;
    esac ;;
esac
exit 1
GH
chmod +x "$shim/gh"

di() { # <EV_LOOKUP> <EV_FILES> -> prints tsv, sets DI_RC
  DI_RC=0
  DI_OUT="$(cd "$repo" && env PATH="$shim" EV_LOOKUP="$1" EV_FILES="$2" \
    EV_PATH="$GOVERNED_PATH" "$SPARK" docs-impact --issue 77 --branch --tsv 2>&1)" \
    || DI_RC=$?
}
verdict() { printf '%s\n' "$DI_OUT" | awk -F'\t' '$1 == "verdict" { print $2 }'; }
note()    { printf '%s\n' "$DI_OUT" | awk -F'\t' '$1 == "evidence-note" { print $2 }'; }

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# ============ the lookup FAILED: nothing is known ==========================
di fail ok
assert_rc "a failed linked-PR lookup is not assessed" 3 "$DI_RC"
assert_eq "and the verdict says so" "NOT ASSESSED" "$(verdict)"
assert_eq "naming the layer that failed, machine-readably" "linked-pr-lookup" "$(note)"
# The falsifying assertion: with the bug, this was PASS/0 — the branch diff
# alone satisfies `docs-impact:none`, and the evidence that contradicted it was
# quietly missing.
case "$(verdict)" in
  PASS) bad "#512: a failed evidence lookup graded the branch alone as complete" ;;
  *) ok ;;
esac

# ============ the lookup ANSWERED "none": grade the branch =================
# This is what must stay distinguishable. A genuinely first branch has complete
# evidence, and turning it into NOT ASSESSED would make the verb unusable before
# the first PR exists.
di empty ok
assert_rc "an empty answer is an answer, and is graded" 0 "$DI_RC"
assert_eq "with a real verdict" "PASS" "$(verdict)"
assert_eq "and no evidence-note, because nothing failed" "" "$(note)"

# ============ the lookup ANSWERED with a PR: union, then grade =============
di ok ok
assert_rc "linked evidence contradicting the declaration fails" 1 "$DI_RC"
assert_eq "as a FAIL, not a NOT ASSESSED" "FAIL" "$(verdict)"
assert_contains "and the evidence names the PR it unioned in" \
  "$(printf 'evidence\t')" "$DI_OUT"
assert_contains "including the PR number" "PR #9" "$DI_OUT"

# ============ the PR's files FAILED: partial is not whole ==================
di ok fail
assert_rc "an unreadable linked PR is not assessed" 3 "$DI_RC"
assert_eq "rather than graded on what did arrive" "NOT ASSESSED" "$(verdict)"
assert_eq "and the layer is named separately" "pr-files" "$(note)"

# ============ the two failures are DIFFERENT findings ======================
# Reporting "no implementation PR exists" when the lookup failed sent authors to
# open a PR that was already open. The layer names must not collapse.
di fail ok; a="$(note)"
di ok fail; b="$(note)"
if [ "$a" != "$b" ]; then ok; else bad "both evidence failures report the same layer '$a'"; fi

# ============ the default (non-branch) mode tells them apart too ===========
# It was safe by accident: the empty value fell into a NOT ASSESSED return whose
# message asserted a fact — "no implementation PR" — that the failed query had
# not established.
d_rc=0
d_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=fail EV_PATH="$GOVERNED_PATH" \
  "$SPARK" docs-impact --issue 77 --tsv 2>&1)" || d_rc=$?
assert_rc "a failed lookup is not assessed in the default mode" 3 "$d_rc"
case "$d_out" in
  *"has no merged or open implementation PR"*)
    bad "a failed lookup was reported as a proven absence of any PR" ;;
  *) ok ;;
esac
assert_contains "the layer is named instead" "linked-pr-lookup" "$d_out"
d_rc=0
d_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=empty EV_PATH="$GOVERNED_PATH" \
  "$SPARK" docs-impact --issue 77 --tsv 2>&1)" || d_rc=$?
assert_rc "and a genuine absence is still not assessed" 3 "$d_rc"
assert_contains "with the message that fits it" \
  "no merged or open implementation PR" "$d_out"

# ============ the aggregate is across ALL linked PRs =======================
# #483 requires the evidence set to be the union across every linked
# implementation PR, so documentation that landed in an EARLIER PR does not
# false-fail a later code-only branch. The existing coverage models that as the
# path set handed to the classifier; this drives the verb, which is where the
# union is actually built — and where a second linked PR could be dropped
# without any classifier test noticing.
a_rc=0
a_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=two EV_FILES=ok \
  EV_PATH="$GOVERNED_PATH" "$SPARK" docs-impact --issue 77 --branch --tsv 2>&1)" || a_rc=$?
assert_contains "both linked PRs appear in the evidence description" "PR #11" "$a_out"
assert_contains "not just the first" "PR #12" "$a_out"
# `docs-impact:none` is declared, and PR #11 changed governed reference docs.
# The aggregate must therefore FAIL — dropping PR #11 would PASS.
assert_rc "the aggregate is judged, not the branch alone" 1 "$a_rc"
assert_contains "and the governed class comes from a linked PR, not the branch" \
  "docs-impact:reference" "$a_out"

# ============ the connection is EXHAUSTED, not sampled ====================
# #483's criterion is that the evidence set "aggregates across ALL linked
# implementation PRs". The query asked for `first: 50` and read `nodes[]` only —
# no pageInfo, no cursor, no continuation — so a successful first page was
# treated as the complete answer.
#
# Here 51 references are linked. PRs 101-150 (page one) carry code only; PR 151
# (page two) is the only governed documentation. `docs-impact:none` is declared,
# so the full set must FAIL and a truncated set PASSes — the verdict-changing
# evidence exists ONLY beyond the first page, which is the one arrangement that
# can tell the two implementations apart.
p_rc=0
p_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=paged EV_FILES=ok \
  EV_PATH="$GOVERNED_PATH" "$SPARK" docs-impact --issue 77 --branch --tsv 2>&1)" || p_rc=$?
assert_rc "51 linked PRs are all read, so the aggregate FAILs" 1 "$p_rc"
assert_eq "with a FAIL verdict" "FAIL" \
  "$(printf '%s\n' "$p_out" | awk -F'\t' '$1=="verdict"{print $2}')"
assert_contains "and the governed class comes from the second page" \
  "docs-impact:reference" "$p_out"
assert_contains "the second page's PR is named in the evidence" "PR #151" "$p_out"
assert_contains "and a first-page PR too, so both pages were unioned" "PR #101" "$p_out"

# ============ a continuation-page failure is NOT ASSESSED =================
# The first page succeeded, so nothing looks wrong. Grading what did arrive is
# exactly the partial-set failure #512 fixed one layer up, and it must not
# reappear because the truncation is now on page two rather than in the whole
# lookup.
p_rc=0
p_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=pagefail EV_FILES=ok \
  EV_PATH="$GOVERNED_PATH" "$SPARK" docs-impact --issue 77 --branch --tsv 2>&1)" || p_rc=$?
assert_rc "a failed continuation page is not assessed" 3 "$p_rc"
assert_eq "rather than graded on page one" "NOT ASSESSED" \
  "$(printf '%s\n' "$p_out" | awk -F'\t' '$1=="verdict"{print $2}')"
assert_eq "and it is reported at the linked-pr-lookup layer" "linked-pr-lookup" \
  "$(printf '%s\n' "$p_out" | awk -F'\t' '$1=="evidence-note"{print $2}')"
case "$(printf '%s\n' "$p_out" | awk -F'\t' '$1=="verdict"{print $2}')" in
  PASS) bad "#530: a partial evidence set was graded as complete" ;;
  *) ok ;;
esac

# ...and hasNextPage true with no cursor is uncontinuable, so it is also a
# failure rather than a silent stop. Continuing from the start would loop.
p_rc=0
p_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=nocursor EV_FILES=ok \
  EV_PATH="$GOVERNED_PATH" "$SPARK" docs-impact --issue 77 --branch --tsv 2>&1)" || p_rc=$?
assert_rc "an uncontinuable page is not assessed" 3 "$p_rc"

# ============ single-page and empty behaviour are UNCHANGED ================
# The pagination must not disturb the cases #512 pinned, or this fix would trade
# one silent failure for another.
di empty ok
assert_rc "a successful empty connection is still graded" 0 "$DI_RC"
assert_eq "and is still distinct from a failed lookup" "" "$(note)"
di ok ok
assert_rc "a single-page connection still behaves as before" 1 "$DI_RC"
di fail ok
assert_rc "and a failed first page is still not assessed" 3 "$DI_RC"

# ============ human mode reports it ONCE ===================================
# Every assertion above reads --tsv. The human surface is a separate renderer,
# and the first cut of this fix printed the finding twice there — once as a note
# and once as the verdict — which reads as two problems. No --tsv assertion could
# have caught that.
h_rc=0
h_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=fail EV_PATH="$GOVERNED_PATH" \
  "$SPARK" docs-impact --issue 77 --branch 2>&1)" || h_rc=$?
assert_rc "human mode exits 3 on a failed lookup too" 3 "$h_rc"
assert_eq "and states the finding exactly once" 1 \
  "$(printf '%s\n' "$h_out" | grep -c 'linked-PR lookup for #77 failed' || true)"
assert_contains "as NOT ASSESSED" "NOT ASSESSED" "$h_out"
# The gradeable case still renders a full report in human mode.
h_rc=0
h_out="$(cd "$repo" && env PATH="$shim" EV_LOOKUP=empty EV_PATH="$GOVERNED_PATH" \
  "$SPARK" docs-impact --issue 77 --branch 2>&1)" || h_rc=$?
assert_rc "and exits 0 when the lookup answered none" 0 "$h_rc"
assert_contains "showing the evidence it judged" "evidence" "$h_out"

# ============ --tsv stays records-only =====================================
# The new row must not break the contract that stdout is parseable: an
# evidence-note carrying prose in a value column is fine, a prose LINE is not.
di fail ok
bad_rows="$(printf '%s\n' "$DI_OUT" \
  | awk -F'\t' 'NF && $1 !~ /^(issue|declared|evidence|evidence-note|governed|verdict)$/ { print }')"
assert_eq "every --tsv row is a known record" "" "$bad_rows"

finish
