#!/usr/bin/env bash
# ledger-truth-check.sh — the dogfood ledger and the release record must not
# contradict themselves about how much work they describe.
#
# WHY THIS EXISTS
#
# PR #545 appended repair cycles 13 and 14, updated the certification heading to
# 74 checks and the tally to 14 repair issues — and left "5 of the 75" in the
# discrimination sentence and "the twelve repair cycles" in the summary heading.
# Two numbers were updated and two were not, in one commit, in one file (#546).
#
# The obvious check — grep for today's literals — would be certification theatre:
# it passes because someone typed the right number today, and it says nothing
# about tomorrow. So every figure here is DERIVED from the documents' own
# structure and compared against what their prose claims. Append a cycle without
# updating the summary and this fails, because the derived count moved and the
# claim did not.
#
# THE VOCABULARY IT ENFORCES
#
#   repair issue   one GitHub issue admitted to the milestone after certification
#                  was withdrawn, and closed by the run. Includes reopened owner
#                  issues, whose repair is a behavioural re-audit rather than a
#                  code change.
#   repair cycle   one pass of the loop for one repair issue: operator selection,
#                  implementation, PR, CI, merge commit.
#
# They are NOT 1:1. An earlier version of this script asserted they were, "by
# definition", and it was wrong: an issue reopened twice gets two cycles. #483 is
# the case — re-audited once after #512, and again after #530 and #524 — and this
# check caught its own model being false when the second row was added.
#
# So the two numbers are derived from different things and compared to different
# claims: CYCLES from the cycle headings and the repairs table's row count,
# ISSUES from the distinct issue numbers in that table. A stale summary still
# fails, which is the point; what no longer fails is an issue legitimately
# appearing twice.
#
# Exit 0 when the documents agree, 1 when they do not. Read-only.
set -uo pipefail

usage="usage: ledger-truth-check.sh [--ledger FILE] [--record FILE]"
ledger="" record=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ledger) shift; ledger="${1:-}" ;;
    --record) shift; record="${1:-}" ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) echo "unknown option: $1" >&2; echo "$usage" >&2; exit 2 ;;
  esac
  shift
done
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -n "$ledger" ] || ledger="$root/docs/ops/v0.21-dogfood-evaluation.md"
[ -n "$record" ] || record="$root/docs/releases/v0.21.md"

gaps=0
gap() { echo "GAP: $1"; gaps=$((gaps + 1)); }

for f in "$ledger" "$record"; do
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 2; }
done

# --- number words, so the prose can stay prose --------------------------------
# A summary heading reads better as "the fourteen repair cycles" than as a
# numeral, and a check that forced numerals would be a check dictating style.
# One word, or a hyphenated compound like "twenty-one": the tens and the units are
# resolved separately and added, so prose does not have to stop at twenty.
num_of() { # <token> -> integer, or empty
  local t="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$t" in
    *-*)
      local tens units
      tens="$(num_word "${t%%-*}")"; units="$(num_word "${t#*-}")"
      if [ -n "$tens" ] && [ -n "$units" ]; then echo "$((tens + units))"; else echo ""; fi
      return 0 ;;
  esac
  num_word "$t"
}

num_word() { # <single word or digits> -> integer, or empty
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    one) echo 1 ;; two) echo 2 ;; three) echo 3 ;; four) echo 4 ;; five) echo 5 ;;
    six) echo 6 ;; seven) echo 7 ;; eight) echo 8 ;; nine) echo 9 ;; ten) echo 10 ;;
    eleven) echo 11 ;; twelve) echo 12 ;; thirteen) echo 13 ;; fourteen) echo 14 ;;
    fifteen) echo 15 ;; sixteen) echo 16 ;; seventeen) echo 17 ;; eighteen) echo 18 ;;
    nineteen) echo 19 ;; twenty) echo 20 ;;
    thirty) echo 30 ;; forty) echo 40 ;; fifty) echo 50 ;;
    ''|*[!0-9]*) echo "" ;;
    *) printf '%s' "$1" ;;
  esac
}

# --- 1. the cycle numbers the ledger actually records ------------------------
# Every integer in a cycle heading, so a combined heading — "Repair cycles 13 and
# 14" — contributes both. Cycles arrive in pairs sometimes; the count must not
# depend on how they were paragraphed.
cycle_nums="$(awk '
  /^### Repair cycles? / {
    line = $0
    sub(/^### Repair cycles? /, "", line)
    while (match(line, /[0-9]+/)) {
      print substr(line, RSTART, RLENGTH)
      line = substr(line, RSTART + RLENGTH)
      if (line ~ /^[^0-9]*—/) break   # stop at the em dash: the title may carry issue numbers
    }
  }' "$ledger" | LC_ALL=C sort -n -u)"
n_cycles="$(printf '%s\n' "$cycle_nums" | grep -c . || true)"

if [ "$n_cycles" -eq 0 ]; then
  gap "the ledger records no '### Repair cycle N' headings, so nothing can be cross-checked"
else
  # Contiguous from 1: a gap means a cycle was renumbered or dropped, and the
  # maximum would then overstate the count.
  expected=1
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    if [ "$c" -ne "$expected" ]; then
      gap "ledger cycle numbers are not contiguous: expected $expected, found $c"
      break
    fi
    expected=$((expected + 1))
  done <<EOF_C
$cycle_nums
EOF_C
fi

# --- 2. the summary heading's claim -----------------------------------------
sum_line="$(grep -m1 '^### What the .* repair cycles' "$ledger" || true)"
if [ -z "$sum_line" ]; then
  gap "the ledger has no '### What the <n> repair cycles' summary heading to check"
else
  tok="$(printf '%s' "$sum_line" | sed -n 's/^### What the \([^ ]*\) repair cycles.*/\1/p')"
  claim="$(num_of "$tok")"
  if [ -z "$claim" ]; then
    gap "the summary heading's count '$tok' is not a number or a number word"
  elif [ "$claim" -ne "$n_cycles" ]; then
    gap "the summary heading claims $claim repair cycles ('$tok'), but the ledger records $n_cycles"
  fi
fi

# --- 3. the tally row -------------------------------------------------------
tally="$(grep -m1 '^| repair issues closed |' "$ledger" || true)"
if [ -z "$tally" ]; then
  gap "the ledger tally has no 'repair issues closed' row"
else
  t_n="$(printf '%s' "$tally" | sed -n 's/^| repair issues closed | *\([0-9]\{1,\}\).*/\1/p')"
  if [ -z "$t_n" ]; then
    gap "the 'repair issues closed' tally row carries no leading count"
  fi
  # The parenthetical breakdown must add up to the same number, or the
  # categories quietly stop covering the population.
  parts="$(printf '%s' "$tally" | sed -n 's/.*(\(.*\)).*/\1/p' \
    | grep -oE '[0-9]+' | awk '{ s += $1 } END { print s + 0 }')"
  if [ -n "$parts" ] && [ "$parts" -ne 0 ] && [ -n "$t_n" ] && [ "$parts" -ne "$t_n" ]; then
    gap "the tally's breakdown sums to $parts but the row claims $t_n"
  fi
fi

# --- 4. the 'All N repair issues are closed' sentence -----------------------
allline="$(grep -m1 -oE 'All [0-9]+ repair issues are closed' "$ledger" || true)"
if [ -n "$allline" ]; then
  a_n="$(printf '%s' "$allline" | grep -oE '[0-9]+')"
  if [ -n "${t_n:-}" ] && [ "$a_n" -ne "$t_n" ]; then
    gap "the result section says 'All $a_n repair issues are closed', but the tally claims $t_n"
  fi
fi

# --- 5. the release record's repairs table ---------------------------------
# Scoped to the repairs table, because the record also carries the original
# five-issue scope table and counting both would compare the wrong populations.
rec_rows="$(awk '
  /^\*\*The repairs\*\*/ { inrep = 1; next }
  inrep && /^## / { exit }
  inrep && /^\| #[0-9]+ \|/ { print }
' "$record" | grep -c . || true)"
if [ "$rec_rows" -eq 0 ]; then
  gap "the release record has no '**The repairs**' table rows to check"
elif [ "$rec_rows" -ne "$n_cycles" ]; then
  gap "the release record lists $rec_rows repairs, but the ledger records $n_cycles repair cycles (one row per cycle)"
fi
# DISTINCT issues in that table are what the tally counts. An issue may appear
# twice — a second reopening is a second cycle — but an accidental duplicate row
# still fails, because it adds a row without adding a cycle heading.
rec_issues="$(awk '
  /^\*\*The repairs\*\*/ { inrep = 1; next }
  inrep && /^## / { exit }
  inrep && /^\| #[0-9]+ \|/ { print $2 }
' "$record" | LC_ALL=C sort -u | grep -c . || true)"
if [ -n "${t_n:-}" ] && [ "$rec_issues" -ne 0 ] && [ "$t_n" -ne "$rec_issues" ]; then
  gap "the tally claims $t_n repair issues, but the release record names $rec_issues distinct ones"
fi

# --- 5b. the suite counts ---------------------------------------------------
# The ledger summarised "new behavioural suites | 6" and "suites total | 47 → 56"
# while the tree held 57, and this check said the record agreed — because it
# derived cycles, the repairs table and the denominator, and simply did not look
# at these two rows. A guard that emits "record agrees" beside a stale figure
# teaches its reader to trust a signal that does not cover the claim (#549).
#
# Both rows are derived. The definition is stated in the row itself so the count
# is reproducible: a "behavioural suite" is a `tests/test-*.sh` file, and the
# baseline is a named commit.
suites_now="$(find "$root/tests" -maxdepth 1 -name 'test-*.sh' 2>/dev/null | grep -c . || true)"
tot_row="$(grep -m1 '^| suites total |' "$ledger" || true)"
if [ -z "$tot_row" ]; then
  gap "the ledger tally has no 'suites total' row"
else
  claim_from="$(printf '%s' "$tot_row" | sed -n 's/^| suites total | *\([0-9]\{1,\}\) *→.*/\1/p')"
  claim_to="$(printf '%s' "$tot_row" | sed -n 's/^| suites total |.*→ *\([0-9]\{1,\}\).*/\1/p')"
  base_ref="$(printf '%s' "$tot_row" | sed -n 's/.*baseline `\([^`]*\)`.*/\1/p')"
  if [ -z "$claim_from" ] || [ -z "$claim_to" ]; then
    gap "the 'suites total' row is not of the form 'A → B (baseline \`REF\`)'"
  else
    # The CURRENT total is always checkable: it needs only the working tree.
    if [ "$claim_to" -ne "$suites_now" ]; then
      gap "the tally claims $claim_to suites, but the tree holds $suites_now"
    fi
    if [ -z "$base_ref" ]; then
      gap "the 'suites total' row names no baseline commit, so its starting figure cannot be reproduced"
    elif ! git -C "$root" rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null 2>&1; then
      # A shallow clone — CI checks out at depth 1 — genuinely cannot see it.
      # Stated as a limit rather than passed over, and the current total above is
      # still checked, so a new suite with a stale row still fails here.
      echo "note: baseline $base_ref is not in this clone, so the starting figure and the new-suite count were not verified"
    else
      base_n="$(git -C "$root" ls-tree "$base_ref" tests/ --name-only 2>/dev/null \
        | grep -c '^tests/test-.*\.sh$' || true)"
      [ "$claim_from" -eq "$base_n" ] || \
        gap "the tally's baseline says $claim_from suites, but $base_ref holds $base_n"
      # "New" is the set difference, not the arithmetic difference: a suite
      # removed and another added would leave the total unchanged while the new
      # count moved.
      new_n="$(comm -13 \
        <(git -C "$root" ls-tree "$base_ref" tests/ --name-only 2>/dev/null \
          | sed -n 's|^tests/\(test-.*\.sh\)$|\1|p' | LC_ALL=C sort) \
        <(find "$root/tests" -maxdepth 1 -name 'test-*.sh' -printf '%f\n' 2>/dev/null \
          | LC_ALL=C sort) | grep -c . || true)"
      new_row="$(grep -m1 '^| new behavioural suites |' "$ledger" || true)"
      if [ -z "$new_row" ]; then
        gap "the ledger tally has no 'new behavioural suites' row"
      else
        n_claim="$(printf '%s' "$new_row" | sed -n 's/^| new behavioural suites | *\([0-9]\{1,\}\).*/\1/p')"
        if [ -z "$n_claim" ]; then
          gap "the 'new behavioural suites' row carries no count"
        elif [ "$n_claim" -ne "$new_n" ]; then
          gap "the tally claims $n_claim new suites, but $new_n exist that $base_ref did not have"
        fi
      fi
    fi
  fi
fi

# --- 6. the certification denominator, everywhere it appears ---------------
# Scoped to the certification section: the ledger is full of legitimate "N of M"
# figures from individual cycles, and comparing those would be noise.
cert="$(awk '/^### Certification —/ { f = 1 } f && /^### / && !/^### Certification —/ { exit } f' "$ledger")"
if [ -z "$cert" ]; then
  gap "the ledger has no '### Certification —' section"
else
  # Flattened, because these claims wrap across lines.
  flat="$(printf '%s' "$cert" | tr '\n' ' ' | tr -s ' ')"
  d1="$(printf '%s' "$flat" | sed -n 's/^### Certification — \([0-9]\{1,\}\) checks.*/\1/p')"
  d2="$(printf '%s' "$flat" | grep -oE '\*\*[0-9]+ passed' | grep -oE '[0-9]+' | head -1)"
  d3="$(printf '%s' "$flat" | grep -oE '[0-9]+ of the [0-9]+' | sed 's/.* of the //' | LC_ALL=C sort -u)"
  seen="$(printf '%s\n%s\n%s\n' "$d1" "$d2" "$d3" | awk 'NF' | LC_ALL=C sort -u)"
  n_seen="$(printf '%s\n' "$seen" | grep -c . || true)"
  if [ "$n_seen" -eq 0 ]; then
    gap "the certification section states no check count that can be cross-checked"
  elif [ "$n_seen" -gt 1 ]; then
    gap "the certification section uses more than one denominator: $(printf '%s' "$seen" | tr '\n' ' ')— one certification, one total"
  fi
fi

if [ "$gaps" -eq 0 ]; then
  echo "ledger-truth: $n_cycles repair cycle(s) over ${t_n:-?} repair issue(s), ${suites_now:-?} suite(s); the ledger, its tally and the release record agree"
  exit 0
fi
echo "ledger-truth: $gaps contradiction(s) — the record disagrees with itself about how much work it describes"
exit 1
