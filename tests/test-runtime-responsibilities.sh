#!/usr/bin/env bash
# The dispatcher's responsibility map is held to the tree (#743): every function classified exactly once, no name
# that does not exist, every figure on the manifest recomputed here, and the canonical primitives still canonical —
# one definition each, and no duplicate body left behind.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib.sh"

MAP="$ROOT/docs/research/v0.23-cleanup/743-responsibilities.tsv"
MAN="$ROOT/docs/research/v0.23-cleanup/743-runtime-surface.md"
SPARK="$ROOT/plugins/spark/bin/spark"
[ -f "$MAP" ] && ok || bad "the responsibility map is committed"
[ -f "$MAN" ] && ok || bad "the manifest is committed"
rows() { grep -v '^#' "$MAP" | grep -v '^$'; }

# --- the map's vocabulary is closed, and its shape is fixed
assert_eq "every responsibility is in the closed vocabulary" "" \
  "$(rows | cut -f2 | grep -vE '^(argument-parsing|routing-dispatch|source-collection|canonicalization|domain-semantics|evidence-authority|formatting-reporting|compatibility-fallback)$' | sort -u | tr '\n' ' ')"
assert_eq "every row has five fields" "" "$(rows | awk -F'\t' 'NF != 5 {print $1}' | tr '\n' ' ')"
assert_eq "no function is classified twice" "" "$(rows | cut -f1 | sort | uniq -d | tr '\n' ' ')"

# --- the map is the tree's: same functions, same body lengths, same verb references
raw="$(cd "$ROOT" && bash tests/structure.sh --raw)"
tree_fns="$(printf '%s\n' "$raw" | awk -F'\t' '$1 == "FUNC" {print $2}' | sort)"
map_fns="$(rows | cut -f1 | sort)"
assert_eq "the map names exactly the dispatcher's functions" "$tree_fns" "$map_fns"
mismatched=""
while IFS=$'\t' read -r fn resp body nverbs verbs; do
  want="$(printf '%s\n' "$raw" | awk -F'\t' -v f="$fn" '$1 == "FUNC" && $2 == f {print $3}')"
  [ "$body" = "$want" ] || mismatched="$mismatched $fn($body!=$want)"
  wantv="$(printf '%s\n' "$raw" | awk -F'\t' -v f="$fn" '$1 == "USED" && $2 == f {print $3}')"
  [ -n "$wantv" ] || wantv=0
  [ "$nverbs" = "$wantv" ] || mismatched="$mismatched $fn(verbs $nverbs!=$wantv)"
done < <(rows)
assert_eq "every body length and verb count is the tree's" "" "$(printf '%s' "$mismatched" | sed 's/^ //')"

# --- the manifest's figures are the map's
total_fns="$(rows | grep -c .)"
total_lines="$(rows | awk -F'\t' '{s+=$3} END {print s}')"
for r in argument-parsing routing-dispatch source-collection canonicalization domain-semantics evidence-authority formatting-reporting compatibility-fallback; do
  n="$(rows | awk -F'\t' -v r="$r" '$2 == r {c++} END {print c+0}')"
  l="$(rows | awk -F'\t' -v r="$r" '$2 == r {s+=$3} END {printf "%d", s}')"
  lc="$(printf '%s' "$l" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
  grep -qF -- "| \`$r\` | $n | $lc |" "$MAN" && ok || bad "the manifest's row for $r is not the map's ($n functions, $lc lines)"
done
grep -qF -- "dispatcher's $total_fns functions" "$MAN" && ok || bad "the manifest does not state the function count $total_fns"

# --- the canonicalizations hold: one definition each, and the replaced copies are gone
for fn in intent_liveness di_trunk json_escape; do
  assert_eq "$fn is defined exactly once in the dispatcher" "1" "$(grep -c "^$fn() {" "$SPARK")"
done
assert_eq "no module restates the JSON escaper" "" \
  "$(grep -l 'json_escape_out\|bg_json_escape' "$ROOT"/plugins/spark/lib/*.sh 2>/dev/null | tr '\n' ' ')"
assert_eq "the issue-state read has one caller-independent reader" "1" \
  "$(grep -c 'gh api "repos/{owner}/{repo}/issues/\$n" --jq .state' "$SPARK")"
# two readers, two facts: di_trunk answers the REMOTE trunk ref, repo_trunk the LOCAL trunk name (network-free,
# on brief's SessionStart path). Comments naming the ref do not count; executable lines do.
assert_eq "the trunk ref is read in exactly two places, one per fact" "2" \
  "$(grep -v '^ *#' "$SPARK" | grep -c 'refs/remotes/origin/HEAD')"
assert_eq "resume no longer carries its own remote-trunk copy" "1" \
  "$(awk '/^cmd_resume\(\) \{/, /^\}/' "$SPARK" | grep -c 'di_trunk "\$root"')"
assert_eq "resume does not resolve the ref itself" "0" \
  "$(awk '/^cmd_resume\(\) \{/, /^\}/' "$SPARK" | grep -v '^ *#' | grep -c 'refs/remotes/origin/HEAD')"

# --- the primitives are used, not merely defined
for fn in intent_liveness di_trunk json_escape; do
  n="$(grep -c "[^a-z_]$fn " "$SPARK" || true)"
  [ "${n:-0}" -ge 2 ] && ok || bad "$fn is defined but not called"
done

# --- the generator is runnable, and the committed map is what it produces
GEN="$ROOT/docs/research/v0.23-cleanup/tools/build-responsibilities.py"
[ -x "$GEN" ] && ok || bad "the map's generator is committed and executable"
[ -f "$ROOT/docs/research/v0.23-cleanup/tools/classification.py" ] && ok || bad "the generator's classification module is committed under an importable name"
gen_out="$(mktemp -d)"
if (cd "$ROOT" && python3 "$GEN" "$ROOT" --map-only "--out=$gen_out" >/dev/null 2>&1); then
  assert_eq "the committed map is what the generator produces" "" \
    "$(diff "$MAP" "$gen_out/docs/research/v0.23-cleanup/743-responsibilities.tsv" | head -5 | tr '\n' ' ')"
else
  bad "the map's generator does not run"
fi
rm -rf "$gen_out"

finish "runtime responsibilities (#743)"
