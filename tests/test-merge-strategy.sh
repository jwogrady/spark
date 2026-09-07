#!/usr/bin/env bash
# Behavioral suite for the governed merge strategy (#763): merge.strategy ships with default `merge`, resolves through
# the preference tiers, renders into the seeded CONVENTIONS.md with its marker, is held there by doctor's
# standards-boundary check, fails closed outside `merge | squash | rebase`, and the surfaces that state the rule
# (the reference vocabulary, the ship skill, this repository's convention, the canonical-truth map) name it.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
sandbox_init
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$(cd "$(dirname "$SPARK")/.." && pwd)"

# --- the shipped default
assert_contains "defaults.json ships merge.strategy=merge" '"merge.strategy": "merge"' "$(cat "$PLUGIN/preferences/defaults.json")"
repo="$WORK/seeded"; make_repo "$repo"
( cd "$repo" && "$SPARK" setup --yes >/dev/null 2>&1 )
assert_contains "seeded CONVENTIONS.md carries the strategy marker" "<!-- spark:pref merge.strategy=merge -->" "$(cat "$repo/CONVENTIONS.md")"
assert_contains "seeded CONVENTIONS.md states how to title the pull request" "plainly for" "$(cat "$repo/CONVENTIONS.md")"
case "$(cat "$repo/CONVENTIONS.md")" in *'{{'*) bad "an unrendered placeholder survived in CONVENTIONS.md" ;; *) ok ;; esac
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_rc "doctor is green on a freshly seeded project" 0 "$rc"
assert_contains "doctor names the resolved strategy and points at the one statement of its guarantee" "✓ merge.strategy=merge — the governed strategy; its exact-HEAD/provenance guarantee is stated in reference/engineering-preferences.md" "$out"

# --- a project selects squash: the marker follows, doctor stays green and names squash's guarantee
repo="$WORK/squash"; make_repo "$repo"; mkdir -p "$repo/.spark"
printf '{"merge.strategy":"squash"}\n' > "$repo/.spark/preferences.json"
( cd "$repo" && "$SPARK" setup --yes >/dev/null 2>&1 )
assert_contains "project override renders into the marker" "<!-- spark:pref merge.strategy=squash -->" "$(cat "$repo/CONVENTIONS.md")"
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_rc "doctor is green with squash selected" 0 "$rc"
assert_contains "doctor names the selected strategy, squash" "✓ merge.strategy=squash — the governed strategy" "$out"
case "$out" in *"conventional subject"*) bad "doctor restates the squash guarantee instead of pointing at the reference" ;; *) ok ;; esac

# --- an operator selects rebase: the operator tier resolves, doctor names rebase's guarantee
repo="$WORK/rebase"; make_repo "$repo"; mkdir -p "$XDG_CONFIG_HOME/spark"
printf '{"merge.strategy":"rebase"}\n' > "$XDG_CONFIG_HOME/spark/preferences.json"
( cd "$repo" && "$SPARK" setup --yes >/dev/null 2>&1 )
assert_contains "operator override renders into the marker" "<!-- spark:pref merge.strategy=rebase -->" "$(cat "$repo/CONVENTIONS.md")"
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_rc "doctor is green with rebase selected" 0 "$rc"
assert_contains "doctor names the selected strategy, rebase" "✓ merge.strategy=rebase — the governed strategy" "$out"
rm -f "$XDG_CONFIG_HOME/spark/preferences.json"

# --- drift: the seeded marker no longer matches the resolved preference
repo="$WORK/drift"; make_repo "$repo"
( cd "$repo" && "$SPARK" setup --yes >/dev/null 2>&1 )
sed -i 's/merge.strategy=merge -->/merge.strategy=squash -->/' "$repo/CONVENTIONS.md"
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_contains "doctor names the drifted key" "'merge.strategy' drifted" "$out"
[ "$rc" -ne 0 ] && ok || bad "a drifted merge-strategy marker must fail doctor"

# --- a value outside the vocabulary fails closed
repo="$WORK/invalid"; make_repo "$repo"; mkdir -p "$repo/.spark"
printf '{"merge.strategy":"fast-forward"}\n' > "$repo/.spark/preferences.json"
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
[ "$rc" -ne 0 ] && ok || bad "a merge strategy outside the vocabulary must fail doctor"
assert_contains "doctor names the vocabulary" "is not one of: merge squash rebase" "$out"

# --- the rule is stated once and pointed at
ref="$(cat "$PLUGIN/docs/reference/engineering-preferences.md")"
assert_contains "the vocabulary documents the key" '`merge.strategy`' "$ref"
for v in merge squash rebase; do assert_contains "the vocabulary states the $v guarantee" "\`$v\` —" "$ref"; done
assert_contains "the squash guarantee names the governor trailer" "Spark-Governed-By" "$ref"
assert_contains "the vocabulary records the default" "default \`merge\`" "$ref"
assert_contains "the ship skill reads the preference" 'merge.strategy' "$(cat "$PLUGIN/skills/ship/SKILL.md")"
assert_contains "the ship skill's Release Please reference reads the preference, never GitHub's allowed methods" "never guess it from GitHub's" "$(cat "$PLUGIN/skills/ship/references/release-please.md")"
assert_contains "this repository's convention names the preference" '`merge.strategy`' "$(cat "$ROOT/docs/ops/release-merge-convention.md")"
assert_contains "the convention points at the one statement of the guarantees" "which this document does not restate" "$(cat "$ROOT/docs/ops/release-merge-convention.md")"
[ "$(grep -c "governor trailer" "$PLUGIN/bin/spark" "$ROOT/docs/ops/release-merge-convention.md" | awk -F: '{s+=$2} END {print s}')" = 0 ] && ok || bad "the guarantees are restated outside the reference vocabulary"
assert_contains "the canonical-truth map names defaults.json as the governed strategy's source" $'merge-method\tplugins/spark/preferences/defaults.json' "$(cat "$ROOT/docs/ops/canonical-truth.tsv")"
[ "$(wc -l < "$PLUGIN/skills/ship/SKILL.md")" -le 100 ] && ok || bad "the ship skill stays within doctor's 100-line budget"
finish "merge strategy preference (#763)"
