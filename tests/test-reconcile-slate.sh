#!/usr/bin/env bash
# Behavioral suite for `spark reconcile` (#468): the reconciliation slate.
#
# The property this whole design turns on is that EVIDENCE and DISPOSITION are
# two axes, not one. `unknown` is a statement about what Spark could read;
# `decision required` is a statement about whose authority is needed. Collapsing
# them is how missing evidence becomes a guessed decision, so a row whose
# evidence is `unread` carries NO disposition at all — the column is empty, and
# several assertions below exist only to keep it that way.
#
# The second property is that the slate PROPOSES. It never applies, and the
# read-only case snapshots the tree, the refs and the object store to prove it.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

# field <rows> <id> <n> — column n of the row with that id
field() { printf '%s\n' "$1" | awk -F'\t' -v i="$2" -v n="$3" '$4 == i { print $n; exit }'; }

nogh="$WORK/nogh"; mkdir -p "$nogh"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$nogh/$t" 2>/dev/null || true
done

mk_repo() {
  local d="$1"
  mkdir -p "$d/src" "$d/.spark" "$d/.github/ISSUE_TEMPLATE"
  git -C "$d" init -q
  git -C "$d" config user.email t@e.invalid
  git -C "$d" config user.name T
  echo 'x = 1' > "$d/src/app.py"
  echo 'name: Bug' > "$d/.github/ISSUE_TEMPLATE/bug.yml"
  echo '## What' > "$d/.github/pull_request_template.md"
  echo '{}' > "$d/release-please-config.json"
  printf '{\n  "project.classification": "existing",\n  "project.classified": "2026-01-01"\n}\n' \
    > "$d/.spark/preferences.json"
  printf '{\n  "next_action": "finish #4242",\n  "blockers": "",\n  "updated": "2026-01-02"\n}\n' \
    > "$d/.spark/state.json"
  git -C "$d" add -A
  git -C "$d" commit -qm "chore: seed"
}

r="$WORK/repo"
mk_repo "$r"
rows="$(cd "$r" && env PATH="$nogh" bash -c '. '"$SPARK"'; rec_rows "'"$r"'"')"

# ============ 1. the two axes never collapse ==============================
# Without gh the milestone surface cannot be read. It must be `unread` with NO
# disposition — not DECISION-REQUIRED, which is a claim about authority, and not
# KEEP, which is a claim about the artifact.
assert_eq "an unreadable surface is unread evidence" "unread" "$(field "$rows" all 2)"
assert_eq "and carries no disposition at all"             "-" "$(field "$rows" all 3)"

# The invariant stated directly over every row: unread implies no disposition,
# and any disposition implies known evidence. A single row breaking either half
# is the collapse this suite exists to catch.
bad_unread="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "unread" && $3 != "-" && NF' | wc -l | tr -d ' ')"
assert_eq "no unread row proposes a disposition" "0" "$bad_unread"
bad_known="$(printf '%s\n' "$rows" | awk -F'\t' '$3 != "-" && $2 != "known" && NF' | wc -l | tr -d ' ')"
assert_eq "no disposition rests on unread evidence" "0" "$bad_known"

# And in particular unread must never be reported as an owed decision.
und="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "unread" && $3 == "DECISION-REQUIRED"' | wc -l | tr -d ' ')"
assert_eq "unread evidence is never DECISION-REQUIRED" "0" "$und"

# ============ 2. the vocabulary is closed =================================
# #476 in the next milestone consumes these names. An unrecognised value would
# drift that contract silently, so the set is asserted rather than assumed.
badvocab="$(printf '%s\n' "$rows" | awk -F'\t' 'NF && $3 != "KEEP" && $3 != "REWRITE-COLLAPSE" \
  && $3 != "DROP-ARCHIVE" && $3 != "DECISION-REQUIRED" && $3 != "-" { print $3 }' | sort -u)"
assert_eq "only the four dispositions are emitted" "" "$badvocab"
badauth="$(printf '%s\n' "$rows" | awk -F'\t' 'NF && $9 != "deterministic" && $9 != "human" { print $9 }' | sort -u)"
assert_eq "authority is deterministic or human, nothing else" "" "$badauth"

# ============ 3. every proposal cites evidence ============================
# A removal or rewrite with an empty finding is an instruction without a reason.
noev="$(printf '%s\n' "$rows" | awk -F'\t' '
  ($3 == "DROP-ARCHIVE" || $3 == "REWRITE-COLLAPSE") && (length($5) < 10) && NF' | wc -l | tr -d ' ')"
assert_eq "every proposed removal or rewrite cites evidence" "0" "$noev"
noval="$(printf '%s\n' "$rows" | awk -F'\t' '$3 != "-" && NF && (length($8) < 3)' | wc -l | tr -d ' ')"
assert_eq "and every disposition names how to validate it" "0" "$noval"

# ============ 4. branch residue, and what must never be proposed ==========
git -C "$r" checkout -q -b spent-work
echo 'y = 2' > "$r/src/b.py"
git -C "$r" add -A; git -C "$r" commit -qm "feat: work"
git -C "$r" checkout -q master
git -C "$r" merge -q --no-ff -m "merge" spent-work
git -C "$r" checkout -q -b unmerged-work
echo 'z = 3' > "$r/src/c.py"
git -C "$r" add -A; git -C "$r" commit -qm "feat: ongoing"
git -C "$r" checkout -q master
rows2="$(cd "$r" && env PATH="$nogh" bash -c '. '"$SPARK"'; rec_rows "'"$r"'"')"

assert_eq "a merged branch is DROP-ARCHIVE" "DROP-ARCHIVE" "$(field "$rows2" spent-work 3)"
assert_contains "citing that its commits are in trunk" "commits are in trunk" \
  "$(field "$rows2" spent-work 5)"
assert_contains "and stating no history is lost" "no history is lost" \
  "$(field "$rows2" spent-work 7)"
assert_eq "dropping a branch stays the human's" "human" "$(field "$rows2" spent-work 9)"
# Work that is NOT merged is not residue. Proposing it would be the slate
# recommending the loss of the only copy.
assert_eq "an unmerged branch is not proposed at all" "" "$(field "$rows2" unmerged-work 3)"
# Trunk and release lines are never proposed, whatever the merge graph says.
for prot in master main release gh-pages; do
  assert_eq "$prot is never proposed for removal" "" "$(field "$rows2" "$prot" 3)"
done

# ============ 5. an intentional historical artifact is KEPT ===============
# An old record that is still TRUE is not residue. With the referenced issue
# open, the slate must leave the intent alone — and it takes a reader that can
# answer to establish that, so this case supplies one.
oghd="$WORK/ogh"; mkdir -p "$oghd"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$oghd/$t" 2>/dev/null || true
done
printf '#!/usr/bin/env bash\ncase "${1:-}" in auth) exit 0 ;; esac\necho open\n' > "$oghd/gh"
chmod +x "$oghd/gh"
rows3="$(cd "$r" && env PATH="$oghd" bash -c '. '"$SPARK"'; rec_rows "'"$r"'"')"
assert_eq "a live recorded intent is KEEP" "KEEP" "$(field "$rows3" state.json 3)"
assert_eq "and needs no human authority" "deterministic" "$(field "$rows3" state.json 9)"

# Whereas an intent whose issues have all closed is a DECISION, not a rewrite
# Spark may perform: what the next action should be is the human's to say.
cghd="$WORK/cgh"; mkdir -p "$cghd"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$cghd/$t" 2>/dev/null || true
done
printf '#!/usr/bin/env bash\ncase "${1:-}" in auth) exit 1 ;; esac\necho closed\n' > "$cghd/gh"
chmod +x "$cghd/gh"
rows4="$(cd "$r" && env PATH="$cghd" bash -c '. '"$SPARK"'; rec_rows "'"$r"'"')"
assert_eq "a spent recorded intent is DECISION-REQUIRED" "DECISION-REQUIRED" \
  "$(field "$rows4" state.json 3)"
assert_eq "and it is the human's call" "human" "$(field "$rows4" state.json 9)"
case "$(field "$rows4" state.json 6)" in
  *"spark state --set"*) ok ;;
  *) bad "the proposed action must name the command that records the decision" ;;
esac

# ============ 6. a judgment gap stops; drift does not =====================
# Driven through the mapper directly, so the property is about classification
# rather than about what this fixture's remote happens to hold.
jrow="$(printf 'metadata\t!\t#558\tno release disposition: neither a milestone nor a disposition decision\n')"
assert_eq "a judgment governance row is a judgment row" "1" \
  "$(printf '%s\n' "$(gov_judgment_rows "$jrow")" | awk 'NF' | wc -l | tr -d ' ')"
drow="$(printf 'label\t~\tfeature\tcolour differs from the model\n')"
assert_eq "drift is neither judgment nor mechanical" "0" \
  "$(printf '%s%s\n' "$(gov_judgment_rows "$drow")" "$(gov_mechanical_rows "$drow")" | awk 'NF' | wc -l | tr -d ' ')"

# ============ 7. READ-ONLY ================================================
snap() {
  ( cd "$1" && find . -path ./.git -prune -o -type f -print0 2>/dev/null \
      | LC_ALL=C sort -z | xargs -0 -r cksum
    echo "--refs--";   git -C "$1" show-ref 2>/dev/null || true
    echo "--status--"; git -C "$1" status --porcelain 2>/dev/null || true
    echo "--objs--";   find "$1/.git/objects" -type f 2>/dev/null | LC_ALL=C sort )
}
before="$(snap "$r")"
rc=0; out="$(cd "$r" && env PATH="$nogh" "$SPARK" reconcile 2>&1)" || rc=$?
after="$(snap "$r")"
assert_eq "reconcile changes nothing on disk" "$before" "$after"
assert_contains "and says so" "Read-only" "$out"
assert_contains "and names what it did not do" "Nothing was deleted" "$out"
# The merged branch it proposed dropping must still be there.
if git -C "$r" rev-parse --verify --quiet spent-work >/dev/null; then ok
else bad "reconcile deleted the branch it merely proposed dropping"; fi

# A gh stub that records any write-shaped call: the log must stay empty.
wgh="$WORK/wgh"; mkdir -p "$wgh"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$wgh/$t" 2>/dev/null || true
done
stub_gh "$wgh/gh" <<'GHEOF'
for a in "$@"; do
  case "$a" in
    --method|-X|-f|-F|edit|create|close|delete|merge|label) echo "WRITE $*" >> "$SENTINEL"; exit 0 ;;
  esac
done
exit 0
GHEOF
export SENTINEL="$WORK/writes.log"; : > "$SENTINEL"
( cd "$r" && env PATH="$wgh" SENTINEL="$SENTINEL" "$SPARK" reconcile >/dev/null 2>&1 ) || true
assert_eq "reconcile makes no write-shaped gh call" "" "$(cat "$SENTINEL")"

# ============ 8. the verdict and its exit codes ===========================
# An owed decision outranks unread evidence, and neither is a pass.
rc=0; ( cd "$r" && env PATH="$nogh" "$SPARK" reconcile >/dev/null 2>&1 ) || rc=$?
assert_rc "unread evidence alone exits 3" 3 "$rc"

tsv="$(cd "$r" && env PATH="$nogh" "$SPARK" reconcile --tsv 2>&1)" || true
assert_contains "tsv carries a header naming both axes" \
  "$(printf 'area\tevidence\tdisposition')" "$tsv"
assert_contains "and a summary line separating the counts" "summary" "$tsv"
# The summary must not fold decisions into proposals: they are different asks.
assert_contains "counting proposals and decisions apart" "decisions" "$tsv"

# Outside a git repo it refuses rather than inventing a slate.
rc=0; ( cd "$WORK" && "$SPARK" reconcile >/dev/null 2>&1 ) || rc=$?
assert_rc "outside a git repo reconcile refuses" 1 "$rc"

# ============ 9. core owns this, not the companion ========================
# The sandbox copies only plugins/spark, so spark-audit is genuinely absent and
# the slate still works — the boundary D3 fixed.
if [ -d "$WORK/plugin/../spark-audit" ]; then bad "the audit companion leaked into the sandbox"; else ok; fi
rc=0; ( cd "$r" && env PATH="$nogh" "$SPARK" reconcile >/dev/null 2>&1 ) || rc=$?
if [ "$rc" -le 5 ]; then ok; else bad "reconcile failed with the audit companion absent (rc=$rc)"; fi

finish
