#!/usr/bin/env bash
# Behavioural suite for the structural scanner (#614).
#
# The scanner is evidence, and decomposition decisions are argued from it. So a
# defect here is worse than a defect in a verb: it does not break anything
# visibly, it just makes the wrong architecture look justified.
#
# It had exactly that defect. Function end was never detected, so `cur` never
# cleared. Every line after the first function was charged to it, the
# top-level-assignment rule never fired again, and the tool cheerfully reported
# three globals in a file that has twenty. Sizes were inflated and references
# picked up names from comments that belong to no function at all.
#
# This fixture's answers are known by construction, and the pre-fix scanner gets
# every one of them wrong.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "structural scanner (#614)"
sandbox_init

SCAN="$repo_root/tests/structure.sh"
[ -f "$SCAN" ] && ok || bad "tests/structure.sh must exist"

FIX="$WORK/fixture.sh"
cat > "$FIX" <<'FIXTURE'
#!/usr/bin/env bash
BEFORE_G=1

alpha() {
  local x=1
  echo "$x"
}

# This inter-function comment mentions beta and gamma on purpose.
BETWEEN_G=2

beta() { echo one-liner; }

gamma() {
  echo two
}

AFTER_G=3
FIXTURE

RAW="$(bash "$SCAN" --raw "$FIX")"
row() { printf '%s\n' "$RAW" | awk -F'\t' -v k="$1" -v n="$2" '$1==k && $2==n'; }

# --- globals before, between and after functions are all counted -------------
for g in BEFORE_G BETWEEN_G AFTER_G; do
  if printf '%s\n' "$RAW" | awk -F'\t' -v g="$g" '$1=="GLOBAL" && $2==g {f=1} END{exit !f}'; then ok
  else bad "top-level assignment '$g' must be counted as a global"; fi
done
n_glob="$(printf '%s\n' "$RAW" | awk -F'\t' '$1=="GLOBAL"{n++} END{print n+0}')"
[ "$n_glob" = "3" ] && ok || bad "the fixture has exactly 3 top-level globals (got $n_glob)"

# --- function ranges terminate where the file says they do -------------------
# Expectations are derived from the fixture independently, so the assertion is
# scanner-versus-file rather than scanner-versus-itself.
a_start="$(grep -n '^alpha() {' "$FIX" | cut -d: -f1)"
a_end="$(awk -v s="$a_start" 'NR>s && /^}$/ {print NR; exit}' "$FIX")"
assert_contains "alpha's range ends at its closing brace" "RANGE	alpha	$a_start	$a_end" "$RAW"
a_len=$(( a_end - a_start + 1 ))
assert_contains "and its length is exactly its own lines" "FUNC	alpha	$a_len" "$RAW"

g_start="$(grep -n '^gamma() {' "$FIX" | cut -d: -f1)"
g_end="$(awk -v s="$g_start" 'NR>s && /^}$/ {print NR; exit}' "$FIX")"
assert_contains "gamma's range ends at its closing brace" "RANGE	gamma	$g_start	$g_end" "$RAW"

# A one-liner opens and closes on the same line.
b_line="$(grep -n '^beta() {' "$FIX" | cut -d: -f1)"
assert_contains "a one-line function spans one line" "RANGE	beta	$b_line	$b_line" "$RAW"
assert_contains "and is one line long"               "FUNC	beta	1" "$RAW"

# --- text between functions belongs to neither -------------------------------
# The comment naming beta and gamma sits outside every function body. If it were
# attributed to alpha, alpha would appear to reference both — which is exactly
# how the contaminated graph invented coupling that was not there.
a_refs="$(printf '%s\n' "$RAW" | awk -F'\t' '$1=="REFS" && $2=="alpha" {print $3}')"
case " $a_refs " in
  *" beta "*)  bad "inter-function text was attributed to alpha (picked up 'beta')" ;;
  *) ok ;;
esac
case " $a_refs " in
  *" gamma "*) bad "inter-function text was attributed to alpha (picked up 'gamma')" ;;
  *) ok ;;
esac

# --- MUTATION CONTROL --------------------------------------------------------
# Remove end-of-function detection — the original defect. Every assertion above
# must go red, so this fixture genuinely discriminates rather than passing by
# coincidence.
MUT="$WORK/structure-mutant.sh"
sed 's|if ($0 ~ /^\\}\[\[:space:\]\]\*$/) { end\[cur\] = NR; cur = "" }|;|' "$SCAN" > "$MUT"
if ! cmp -s "$SCAN" "$MUT"; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

MRAW="$(bash "$MUT" --raw "$FIX" 2>/dev/null || true)"
m_glob="$(printf '%s\n' "$MRAW" | awk -F'\t' '$1=="GLOBAL"{n++} END{print n+0}')"
if [ "$m_glob" = "3" ]; then
  bad "MUTATION control — the broken scanner still found 3 globals; the fixture does not discriminate"
else ok; fi

m_refs="$(printf '%s\n' "$MRAW" | awk -F'\t' '$1=="REFS" && $2=="alpha" {print $3}')"
case " $m_refs " in
  *" beta "*) ok ;;
  *) bad "MUTATION control — the broken scanner did not mis-attribute inter-function text; the fixture does not discriminate" ;;
esac

finish
