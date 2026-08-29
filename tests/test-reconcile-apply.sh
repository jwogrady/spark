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

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

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
out="$(cd "$r" && env PATH="$cgh" "$SPARK" reconcile --approve intent:state.json --yes --allow-destructive 2>&1)" || true
assert_contains "a decision is refused however it is approved" "not Spark's to carry out" "$out"
assert_contains "and says no flag changes that" "No flag makes it applicable" "$out"
assert_eq "and nothing was committed for it" "$head_before" "$(git -C "$r" rev-parse HEAD)"
assert_contains "the recorded intent is unchanged" "finish #4242" "$(cat "$r/.spark/state.json")"

# ============ 4. destructive work needs saying so twice ===================
git -C "$r" checkout -q -b merged-thing
echo x > "$r/x.txt"; git -C "$r" add -A; git -C "$r" commit -qm "feat: x"
git -C "$r" checkout -q master
git -C "$r" merge -q --no-ff -m merge merged-thing
out="$(R "$r" --approve branch:merged-thing --yes)" || true
assert_contains "a ref deletion is refused without the flag" "needs --allow-destructive" "$out"
if git -C "$r" rev-parse --verify --quiet merged-thing >/dev/null; then ok
else bad "the branch was deleted without --allow-destructive"; fi

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
assert_contains "and explains that the slate is re-derived" "re-derived every run" "$out"

finish
