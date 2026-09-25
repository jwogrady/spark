#!/usr/bin/env bash
# Behavioral suite for the evidence index (#742): every evidence artifact under the covered roots is one row or one
# family member, exactly once; classes are closed and consistent with the operative-now answer; every historical or
# do-not-delete row names an identity (issue, version or commit) and a fact; every reader named exists and references
# the family; no shipped surface, test or CI script references a non-operative artifact the index does not list as a
# reader (the hot-path claim). Historical measurement artifacts remain pointable evidence, never current runtime authority.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDX="$ROOT/docs/ops/evidence-index.tsv"
[ -f "$IDX" ] && ok || bad "docs/ops/evidence-index.tsv is present"
rows() { grep -v '^#' "$IDX" | grep -v '^$'; }
assert_eq "every row has ten columns" "" "$(rows | awk -F'\t' 'NF != 10 {print NR}' | tr '\n' ' ')"
assert_eq "every class is in the closed vocabulary" "" "$(rows | cut -f2 | grep -vE '^(active-current|historical-retained|redundant|do-not-delete)$' | sort -u | tr '\n' ' ')"
assert_eq "operative-now is yes or no" "" "$(rows | cut -f3 | grep -vE '^(yes|no)$' | sort -u | tr '\n' ' ')"
assert_eq "historical-retained rows are never operative" "" "$(rows | awk -F'\t' '$2 == "historical-retained" && $3 != "no" {print $1}' | tr '\n' ' ')"
assert_eq "active-current rows are operative" "" "$(rows | awk -F'\t' '$2 == "active-current" && $3 != "yes" {print $1}' | tr '\n' ' ')"
assert_eq "no row is classified redundant without saying what duplicates it" "" "$(rows | awk -F'\t' '$2 == "redundant" && $10 !~ /duplicate/ {print $1}' | tr '\n' ' ')"

# --- coverage: every artifact under the covered roots matches exactly one family (a family's own file list)
tree="$(cd "$ROOT" && git ls-files -- docs/research docs/releases docs/governance docs/ops/v0.21-dogfood-evaluation.md docs/ops/telemetry-baseline.md docs/ops/evaluation.md evaluations .spark | sort)"
match() { # match <pattern> <path>
  case "$1" in
    *"/**") case "$2" in "${1%\*\*}"*) return 0 ;; *) return 1 ;; esac ;;                     # everything beneath the directory
    *"/*") case "$2" in "${1%\*}"*) case "${2#${1%\*}}" in */*) return 1 ;; *) return 0 ;; esac ;; *) return 1 ;; esac ;;   # direct children only
    *) case "$2" in $1) return 0 ;; *) return 1 ;; esac ;;
  esac
}
family_covers() { # family_covers <pattern list> <path> — a positive pattern matches and no `!` exclusion does
  local pat pats
  IFS=';' read -ra pats <<<"$1"
  for pat in "${pats[@]}"; do case "$pat" in "!"*) if match "${pat#!}" "$2"; then return 1; fi ;; esac; done
  for pat in "${pats[@]}"; do case "$pat" in "!"*) ;; *) if match "$pat" "$2"; then return 0; fi ;; esac; done
  return 1
}
covered=0; multi=""; none=""
while IFS= read -r p; do
  n=0
  while IFS=$'\t' read -r fam _rest; do
    family_covers "$fam" "$p" && n=$((n+1))
  done < <(rows)
  [ "$n" -ge 1 ] || none="$none $p"
  [ "$n" -le 1 ] || multi="$multi $p"
  covered=$((covered+1))
done <<<"$tree"
assert_eq "every evidence artifact under the covered roots is indexed" "" "$(printf '%s' "$none" | sed 's/^ //')"
assert_eq "no artifact belongs to two families" "" "$(printf '%s' "$multi" | sed 's/^ //')"
files_sum="$(rows | awk -F'\t' '{s+=$4} END {print s}')"
assert_eq "the index's file counts sum to the covered tree" "$(printf '%s\n' "$tree" | grep -c .)" "$files_sum"
# each family's own count equals the files it matches (so no artifact is counted by two families)
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  n=0; b=0; l=0
  while IFS= read -r p; do
    if family_covers "$fam" "$p"; then n=$((n+1)); b=$((b + $(wc -c < "$ROOT/$p"))); l=$((l + $(wc -l < "$ROOT/$p"))); fi
  done <<<"$tree"
  assert_eq "family $fam: file count is the tree's" "$n" "$files"
  assert_eq "family $fam: bytes are the tree's" "$b" "$bytes"
  assert_eq "family $fam: lines are the tree's" "$l" "$lines"
  [ "$files" -ge 1 ] && ok || bad "family $fam matches no file"
  # identity and fact for anything kept for the record
  case "$cls" in historical-retained|do-not-delete)
    printf '%s' "$concerns" | grep -qE '#[0-9]+|v0\.[0-9]+|[0-9a-f]{40}|ADR-[0-9]{4}' && ok || bad "family $fam: concerns names no issue, version, ADR or commit: '$concerns'"
    [ -n "$fact" ] && [ "$fact" != "-" ] && ok || bad "family $fam: the fact it supported is not stated" ;;
  esac
  # readers exist and reference the family (its first path component that is a file, or the directory of a glob)
  if [ "$readers" != "-" ]; then
    IFS=';' read -ra rds <<<"$readers"; for r in "${rds[@]}"; do
      [ -f "$ROOT/$r" ] && ok || bad "family $fam: reader $r does not exist"
      hit=0
      IFS=';' read -ra pats <<<"$fam"; for pat in "${pats[@]}"; do
        case "$pat" in "!"*) continue ;; esac
        frag="${pat%/\*\*}"; frag="${frag%/\*}"; frag="${frag%%[*?[]*}"; frag="${frag%/}"
        if grep -qF -- "$frag" "$ROOT/$r" 2>/dev/null; then hit=1; break; fi
      done
      [ "$hit" = 1 ] && ok || bad "family $fam: reader $r does not reference it"
    done
  fi
done < <(rows)

# --- classification follows current behaviour -------------------------------
# A shipped runtime, current suite or CI script that reads a family makes that
# family operative. This suite itself is an AUDITOR of the index, not a reason
# historical evidence becomes operative; counting self-observation as product
# dependency was the #768 coupling.
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  external_current=0
  if [ "$readers" != "-" ]; then
    IFS=';' read -ra rds <<<"$readers"
    for r in "${rds[@]}"; do
      [ "$r" = "tests/test-evidence-index.sh" ] && continue
      case "$r" in
        plugins/*|tests/*|.github/*) external_current=1 ;;
      esac
    done
  fi
  if [ "$external_current" = 1 ]; then
    assert_eq "family $fam is read by a current executable surface, so it is operative" "yes" "$op"
  fi
done < <(rows)

# #768 closes the historical-input exception. The literal marker remains useful
# as a regression sentinel: adding another current dependency to historical
# evidence must fail this suite rather than silently becoming accepted debt.
DEP_MARK="CURRENT DEPENDENCY ON A HISTORICAL RECORD"
assert_eq "no historical evidence remains a declared current dependency" "0" \
  "$(rows | awk -F'\t' -v m="$DEP_MARK" 'index($10, m) == 1 {n++} END {print n+0}')"

# --- current hot-path leak check --------------------------------------------
# A non-operative family may be mentioned by docs/evidence, but current runtime,
# tests or CI must not read/cite it unless the index explicitly says so.
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  [ "$op" = "no" ] || continue
  case "$fam" in
    *'!'*)
      scan=""
      while IFS= read -r p; do family_covers "$fam" "$p" && scan="$scan $p"; done <<<"$tree"
      ;;
    *) scan="$(printf '%s' "$fam" | tr ';' ' ')" ;;
  esac
  for pat in $scan; do
    frag="${pat%/\*\*}"; frag="${frag%/\*}"; frag="${frag%%[*?[]*}"; frag="${frag%/}"
    [ "${#frag}" -ge 12 ] || continue
    refs="$(cd "$ROOT" && git grep -l -F -- "$frag" -- 'plugins/**' 'tests/*.sh' 'tests/lib.sh' 'tests/run.sh' '.github/**' 2>/dev/null \
      | grep -v '^tests/test-evidence-index.sh$' || true)"
    for r in $refs; do
      case ";$readers;" in
        *";$r;"*) ok ;;
        *) bad "$r reads or cites non-operative evidence $pat but the index does not list it as a reader" ;;
      esac
    done
  done
done < <(rows)

# --- reader claims are backed by actual references ---------------------------
# If a family lists readers, each member must be reachable by at least one of
# them. This remains a live invariant derived from the current tree, not from a
# dated measurement report.
unbacked=""
while IFS=$'\t' read -r fam _cls _op _f _b _l _c _fact readers _why; do
  [ "$readers" != "-" ] || continue
  IFS=';' read -ra rds <<<"$readers"
  while IFS= read -r p; do
    family_covers "$fam" "$p" || continue
    hit=0
    for r in "${rds[@]}"; do
      [ -f "$ROOT/$r" ] || continue
      probe="$p"
      while [ "$probe" != "." ] && [ "$probe" != "/" ]; do
        if grep -qF -- "$probe" "$ROOT/$r" 2>/dev/null; then hit=1; break; fi
        probe="$(dirname "$probe")"
      done
      [ "$hit" = 1 ] && break
    done
    [ "$hit" = 1 ] || unbacked="$unbacked $p"
  done <<<"$tree"
done < <(rows)
assert_eq "every member of a family with readers is referenced by one of them" "" \
  "$(printf '%s' "$unbacked" | sed 's/^ //')"

# A rationale cannot contradict the readers column it accompanies.
contradictory=""
while IFS=$'\t' read -r fam _cls _op _f _b _l _c _fact readers why; do
  n=0
  [ "$readers" = "-" ] || { IFS=';' read -ra _rs <<<"$readers"; n=${#_rs[@]}; }
  case "$why" in
    *"no reader"*|*"listed with no reader"*) [ "$n" -eq 0 ] || contradictory="$contradictory $fam(says-none-has-$n)" ;;
  esac
  case "$why" in
    *"only reader"*) [ "$n" -le 1 ] || contradictory="$contradictory $fam(says-one-has-$n)" ;;
  esac
done < <(rows)
assert_eq "no rationale contradicts its own readers column" "" \
  "$(printf '%s' "$contradictory" | sed 's/^ //')"

# #742's capture, tool and report remain durable historical evidence. Their
# existence is checked so they stay pointable/auditable; their old measurements
# are deliberately NOT compared with HEAD and never gate runtime evolution.
for artifact in \
  docs/research/v0.23-cleanup/742-default-reads.tsv \
  docs/research/v0.23-cleanup/tools/evidence-reads.sh \
  docs/research/v0.23-cleanup/742-evidence-separation.md; do
  [ -e "$ROOT/$artifact" ] && ok || bad "historical #742 evidence is missing: $artifact"
done

assert_eq "the index is not a member of the corpus it indexes" "" \
  "$(printf '%s\n' "$tree" | grep -x 'docs/ops/evidence-index.tsv' || true)"
assert_eq "the suite is not a member of the corpus it checks" "" \
  "$(printf '%s\n' "$tree" | grep -x 'tests/test-evidence-index.sh' || true)"

finish "evidence index (#742)"
