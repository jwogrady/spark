#!/usr/bin/env bash
# Behavioral suite for `spark reconcile --approve` (#468): the approval-gated
# mutation half.
#
# The slate proposes; this is the part that can do damage, so the properties
# asserted here are the ones that make a mistake survivable:
#
#   - nothing is applied without --yes, and nothing destructive without saying
#     so a second time;
#   - a DECISION-REQUIRED finding is never applicable, with ANY flags — that is
#     the boundary, not a default;
#   - one approved group is exactly one commit, so reverting the middle of a run
#     leaves the rest applied;
#   - every group is validated by RE-DERIVING the slate, not by trusting that
#     the command exited zero.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

nogh="$WORK/nogh"; mkdir -p "$nogh"
for t in git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$nogh/$t" 2>/dev/null || true
done
R() { ( cd "$1" && env PATH="$nogh" "$SPARK" reconcile "${@:2}" 2>&1 ); }

# A repository with THREE stale release records: each states a disposition its
# published tag contradicts. Three separate findings, so three groups, so the
# middle one can be reverted.
r="$WORK/repo"
mkdir -p "$r/docs/releases" "$r/.spark" "$r/.github/ISSUE_TEMPLATE"
git -C "$r" init -q
git -C "$r" config user.email t@e.invalid
git -C "$r" config user.name T
echo 'name: Bug' > "$r/.github/ISSUE_TEMPLATE/bug.yml"
echo '## What' > "$r/.github/pull_request_template.md"
echo '{}' > "$r/release-please-config.json"
printf '{\n  "project.classification": "existing",\n  "project.classified": "2026-01-01"\n}\n' \
  > "$r/.spark/preferences.json"
for v in 0.1 0.2 0.3; do
  printf '# Release record v%s\n\n> **Disposition: `Blocked`.** Something went wrong once.\n\nHistory: this record was Blocked and that is deliberately kept.\n' \
    "$v" > "$r/docs/releases/v$v.md"
done
git -C "$r" add -A
git -C "$r" commit -qm "chore: seed"
for v in 0.1 0.2 0.3; do git -C "$r" tag "v$v.0"; done

# ============ 1. the slate sees all three =================================
rows="$(cd "$r" && env PATH="$nogh" bash -c '. '"$SPARK"'; rec_rows "'"$r"'"')"
n="$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "release" && $3 == "REWRITE-COLLAPSE"' | wc -l | tr -d ' ')"
assert_eq "three contradicted release records are found" "3" "$n"
assert_contains "citing the tag that contradicts the claim" "tag v0.2.0 is published" \
  "$(printf '%s\n' "$rows" | awk -F'\t' '$4 == "v0.2.md" { print $5 }')"

# ============ 2. nothing applies without --yes ============================
before="$(git -C "$r" rev-parse HEAD)"
out="$(R "$r" --approve release:v0.1.md)" || true
assert_contains "a preview says it is a preview" "Preview only" "$out"
assert_contains "and says what it would do" "would:" "$out"
assert_eq "no commit is made in preview" "$before" "$(git -C "$r" rev-parse HEAD)"
assert_contains "the record is untouched" "Blocked" "$(cat "$r/docs/releases/v0.1.md")"

# ============ 3. DECISION-REQUIRED is never applicable ====================
# Not with --yes, not with --allow-destructive, not with both. A judgment is not
# a stronger permission away from being Spark's to make.
printf '{\n  "next_action": "finish #4242",\n  "blockers": "",\n  "updated": "2026-01-02"\n}\n' \
  > "$r/.spark/state.json"
git -C "$r" add -A; git -C "$r" commit -qm "chore: record intent"
cgh="$WORK/cgh"; mkdir -p "$cgh"
for t in git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$cgh/$t" 2>/dev/null || true
done
printf '#!/usr/bin/env bash\ncase "${1:-}" in auth) exit 1 ;; esac\necho closed\n' > "$cgh/gh"
chmod +x "$cgh/gh"
head_before="$(git -C "$r" rev-parse HEAD)"
out="$(cd "$r" && env PATH="$cgh" "$SPARK" reconcile --approve intent:state.json --yes 2>&1)" || true
assert_contains "a decision is refused when approved" "not Spark's to carry out" "$out"
assert_contains "and says no flag changes that" "No flag makes it applicable" "$out"
assert_eq "and nothing was committed for it" "$head_before" "$(git -C "$r" rev-parse HEAD)"
assert_contains "the recorded intent is unchanged" "finish #4242" "$(cat "$r/.spark/state.json")"

# NO FLAG COMBINATION promotes a non-revertible finding into an applied group.
# The escape hatch that used to exist is gone, and an invented one is rejected
# rather than ignored — an unknown flag that is silently dropped is how a
# caller comes to believe it did something.
for flag in --allow-destructive --force --allow-remote; do
  out="$(cd "$r" && env PATH="$cgh" "$SPARK" reconcile --approve intent:state.json --yes "$flag" 2>&1)" || true
  assert_contains "$flag is rejected, not ignored" "unknown option" "$out"
done
assert_eq "and still nothing was committed" "$head_before" "$(git -C "$r" rev-parse HEAD)"

# ============ 4. destructive work needs saying so twice ===================
git -C "$r" checkout -q -b merged-thing
echo x > "$r/x.txt"; git -C "$r" add -A; git -C "$r" commit -qm "feat: x"
git -C "$r" checkout -q master
git -C "$r" merge -q --no-ff -m merge merged-thing
out="$(R "$r" --approve branch:merged-thing --yes)" || true
assert_contains "a ref deletion is reported, not performed" "reconcile does not carry this out" "$out"
assert_contains "and names the command to run yourself" "run yourself: git branch -d merged-thing" "$out"
assert_contains "and says why it is not automated" "one revertible commit" "$out"
if git -C "$r" rev-parse --verify --quiet merged-thing >/dev/null; then ok
else bad "the branch was deleted despite being a manual finding"; fi
# --yes is not a licence: a finding that cannot land as one revertible commit
# is not applied by any means this verb offers.
h_ref="$(git -C "$r" rev-parse HEAD)"
R "$r" --approve branch:merged-thing --yes >/dev/null 2>&1 || true
assert_eq "and no commit was manufactured for it" "$h_ref" "$(git -C "$r" rev-parse HEAD)"

# ============ 4b. one governance approval cannot mutate another ===========
# Approving a single governance finding once called `governance apply --yes`,
# which provisions the whole family. It could create labels the operator never
# approved, and re-deriving the slate would not notice: the approved finding
# would be gone and so would the others, which reads as success.
#
# The guard is that reconciliation never invokes that command at all. Proven by
# giving it a gh that RECORDS every call: approving a governance finding must
# leave the log empty.
ggh="$WORK/ggh"; mkdir -p "$ggh"
for t in git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$ggh/$t" 2>/dev/null || true
done
# The stub answers the LABEL surface with one real label, so the rest of the
# governed families resolve as missing and the slate carries actual governance
# findings. An earlier version of this fixture let gh answer nothing: every
# governance surface came back unread, no finding had a disposition, and the
# assertions below silently skipped — they passed while the defect they exist
# for was reintroduced.
cat > "$ggh/gh" <<'GHEOF'
#!/usr/bin/env bash
echo "CALL $*" >> "$GLOG"
case "${1:-}" in auth) exit 0 ;; esac
for a in "$@"; do
  case "$a" in
    *labels*) printf 'feature	0e8a16	New capability or user-visible behaviour
'; exit 0 ;;
  esac
done
exit 0
GHEOF
chmod +x "$ggh/gh"
export GLOG="$WORK/gh-calls.log"

# No `exit` in this awk: rec_rows emits far more after the first governance row,
# and closing the pipe early SIGPIPEs the producer, which pipefail turns into a
# suite abort rather than a result.
grows="$(cd "$r" && env PATH="$ggh" GLOG="$GLOG" bash -c '. '"$SPARK"'; rec_rows "'"$r"'"' \
  | awk -F'\t' '$1 == "governance" && $3 != "-" && !seen { print $4; seen = 1 }')"
# The fixture must actually produce one, or everything below proves nothing.
if [ -n "$grows" ]; then ok; else bad "the fixture produced no governance finding, so the delegation is untested"; fi

: > "$GLOG"
h_gov="$(git -C "$r" rev-parse HEAD)"
out="$(cd "$r" && env PATH="$ggh" GLOG="$GLOG" "$SPARK" reconcile --approve "governance:$grows" --yes 2>&1)" || true
assert_contains "a governance finding is delegated, not performed" \
  "reconcile does not carry this out" "$out"
assert_contains "and names the governance command to run" "run yourself: spark governance apply" "$out"
# The load-bearing assertion: approving ONE finding must not drive the
# family-wide command. Any label-writing call in the log means it did.
case "$(cat "$GLOG" 2>/dev/null)" in
  *"--method"*|*"-f "*|*"-F "*) bad "reconciliation mutated governance state itself" ;;
  *) ok ;;
esac
assert_eq "and manufactured no commit" "$h_gov" "$(git -C "$r" rev-parse HEAD)"

# ============ 5. one group, one commit, and it validates ==================
h0="$(git -C "$r" rev-parse HEAD)"
out="$(R "$r" --approve release:v0.1.md --yes)" || true
assert_contains "the group reports what it did" "set the current-state disposition" "$out"
assert_contains "and that it committed" "committed" "$out"
assert_contains "and that it re-derived the slate to check" "freshly derived slate" "$out"
assert_eq "exactly one commit was made" "1" \
  "$(git -C "$r" rev-list --count "$h0"..HEAD | tr -d ' ')"
assert_contains "the record now reads Shipped" "Disposition: \`Shipped\`" "$(cat "$r/docs/releases/v0.1.md")"
# Provenance is preserved: correcting the current-state claim must not delete
# the record's own history of having been Blocked.
assert_contains "and its history is kept" "this record was Blocked" "$(cat "$r/docs/releases/v0.1.md")"

# ============ 6. THE MIDDLE GROUP REVERTS CLEANLY =========================
# Three groups applied in order; revert the middle; the other two stay applied.
# This is the property that makes an approval mistake recoverable.
R "$r" --approve release:v0.2.md --yes >/dev/null || true
c2="$(git -C "$r" rev-parse HEAD)"
R "$r" --approve release:v0.3.md --yes >/dev/null || true
c3="$(git -C "$r" rev-parse HEAD)"
assert_eq "the three groups are three distinct commits" "3" \
  "$(git -C "$r" rev-list --count "$h0"..HEAD | tr -d ' ')"

rc=0
git -C "$r" revert --no-edit "$c2" >/dev/null 2>&1 || rc=$?
assert_rc "the middle group reverts without conflict" 0 "$rc"
assert_contains "the reverted record is Blocked again" "Disposition: \`Blocked\`" \
  "$(cat "$r/docs/releases/v0.2.md")"
assert_contains "the first group stays applied" "Disposition: \`Shipped\`" \
  "$(cat "$r/docs/releases/v0.1.md")"
assert_contains "and so does the third" "Disposition: \`Shipped\`" \
  "$(cat "$r/docs/releases/v0.3.md")"
# And the slate agrees: exactly the reverted one is a finding again.
rows2="$(cd "$r" && env PATH="$nogh" bash -c '. '"$SPARK"'; rec_rows "'"$r"'"')"
assert_eq "the slate reports exactly the reverted finding" "1" \
  "$(printf '%s\n' "$rows2" | awk -F'\t' '$1 == "release" && $3 == "REWRITE-COLLAPSE"' | wc -l | tr -d ' ')"
assert_eq "and names the right record" "v0.2.md" \
  "$(printf '%s\n' "$rows2" | awk -F'\t' '$1 == "release" { print $4; exit }')"

# ============ 6b. a stale row must never authorise a mutation (#590) ======
# Every selector is resolved against a FRESHLY derived slate immediately before
# acting. Resolving against the snapshot taken at the start of the run let an
# already-cleared finding authorise a second "application": the edit rewrote a
# value to itself, produced no commit, passed validation because the finding was
# already gone, and still counted. One commit, two groups reported — which makes
# both the machine result and the operator's recovery contract false.

# --- the exact duplicate from the report
h_dup="$(git -C "$r" rev-parse HEAD)"
out="$(R "$r" --approve release:v0.2.md --approve release:v0.2.md --yes)" || true
n_commits="$(git -C "$r" rev-list --count "$h_dup"..HEAD | tr -d ' ')"
assert_eq "a duplicate approval produces one commit" "1" "$n_commits"
assert_contains "and the refusal covers both shapes" "an earlier group" "$out"
assert_contains "and the count matches the commits" "Applied 1 group(s)" "$out"
case "$out" in
  *"Applied 2 group(s)"*) bad "a duplicate approval was counted as a second group" ;;
  *) ok ;;
esac

# THE INVARIANT, asserted as a relationship rather than a literal: whatever
# number the run reports, that many commits must exist. A message assertion
# alone would pass on a different wrong number.
reported="$(printf '%s\n' "$out" | sed -n 's/^Applied \([0-9][0-9]*\) group(s).*/\1/p' | head -1)"
assert_eq "the reported count equals the commits made" "$reported" "$n_commits"

# --- the GENERAL case: an earlier group clears a later selected finding.
# Not a duplicate selector — two different ids, where applying the first makes
# the second disappear. The snapshot would still have authorised it.
git -C "$r" checkout -q -- . 2>/dev/null || true
cat > "$r/docs/releases/v0.4.md" <<'RECEOF'
# Release record v0.4

> **Disposition: `Blocked`.** Something went wrong once.

History: this record was Blocked and that is deliberately kept.
RECEOF
git -C "$r" add -A; git -C "$r" commit -qm "chore: add v0.4 record"
git -C "$r" tag v0.4.0
# Applying v0.4 first; then approve it again under its own id after it has gone.
h_gen="$(git -C "$r" rev-parse HEAD)"
out="$(R "$r" --approve release:v0.4.md --approve release:v0.4.md --yes)" || true
assert_eq "a cleared finding cannot be re-applied" "1" \
  "$(git -C "$r" rev-list --count "$h_gen"..HEAD | tr -d ' ')"
reported="$(printf '%s\n' "$out" | sed -n 's/^Applied \([0-9][0-9]*\) group(s).*/\1/p' | head -1)"
assert_eq "and the count still matches the commits" "1" "$reported"

# --- a finding that is present but whose application changes nothing is NOT
# an applied group. Simulated by pointing a selector at a record already
# correct: the slate would not list it, so this asserts the refusal path holds
# for an id that names nothing rather than silently counting.
out="$(R "$r" --approve release:v0.4.md --yes)" || true
assert_contains "an already-corrected record is refused, not counted" "no such finding" "$out"
case "$out" in
  *"Applied 1 group(s)"*) bad "a no-op was counted as an applied group" ;;
  *) ok ;;
esac

# ============ 7. a dirty tree refuses ====================================
# "Exactly one commit per group" would be a lie if unrelated work rode along.
echo "unrelated" > "$r/scratch.txt"
out="$(R "$r" --approve release:v0.2.md --yes)" || true
assert_contains "a dirty tree refuses to apply" "uncommitted change" "$out"
assert_contains "and says why it matters" "reverts on its own" "$out"
rm -f "$r/scratch.txt"

# ============ 8. an id that no longer names a finding is refused ==========
out="$(R "$r" --approve release:v9.9.md --yes)" || true
assert_contains "an unknown finding is refused" "no such finding" "$out"
assert_contains "and explains that the slate is re-derived" "re-derived before every group" "$out"

finish
