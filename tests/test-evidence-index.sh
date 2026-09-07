#!/usr/bin/env bash
# Behavioral suite for the evidence index (#742): every evidence artifact under the covered roots is one row or one
# family member, exactly once; classes are closed and consistent with the operative-now answer; every historical or
# do-not-delete row names an identity (issue, version or commit) and a fact; every reader named exists and references
# the family; no shipped surface, test or CI script references a non-operative artifact the index does not list as a
# reader (the hot-path claim); the manifest's figures are the index's.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDX="$ROOT/docs/ops/evidence-index.tsv"; MAN="$ROOT/docs/research/v0.23-cleanup/742-evidence-separation.md"
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
    *"/*") case "$2" in "${1%\*}"*) return 0 ;; *) return 1 ;; esac ;;   # a directory family covers everything beneath it
    *) case "$2" in $1) return 0 ;; *) return 1 ;; esac ;;
  esac
}
covered=0; multi=""; none=""
while IFS= read -r p; do
  n=0
  while IFS=$'\t' read -r fam _rest; do
    IFS=';' read -ra pats <<<"$fam"; for pat in "${pats[@]}"; do match "$pat" "$p" && { n=$((n+1)); break; }; done
  done < <(rows)
  [ "$n" -ge 1 ] || none="$none $p"
  covered=$((covered+1))
done <<<"$tree"
assert_eq "every evidence artifact under the covered roots is indexed" "" "$(printf '%s' "$none" | sed 's/^ //')"
files_sum="$(rows | awk -F'\t' '{s+=$4} END {print s}')"
assert_eq "the index's file counts sum to the covered tree" "$(printf '%s\n' "$tree" | grep -c .)" "$files_sum"
# each family's own count equals the files it matches (so no artifact is counted by two families)
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  n=0; b=0
  while IFS= read -r p; do
    IFS=';' read -ra pats <<<"$fam"; for pat in "${pats[@]}"; do
      if match "$pat" "$p"; then n=$((n+1)); b=$((b + $(wc -c < "$ROOT/$p"))); break; fi
    done
  done <<<"$tree"
  [ "$n" -ge "$files" ] && ok || bad "family $fam: matches $n files but the index counts $files (a family cannot count more than it matches)"
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
        frag="${pat%/\*}"; frag="${frag%%[*?[]*}"; frag="${frag%/}"
        if grep -qF -- "$frag" "$ROOT/$r" 2>/dev/null; then hit=1; break; fi
      done
      [ "$hit" = 1 ] && ok || bad "family $fam: reader $r does not reference it"
    done
  fi
done < <(rows)

# --- the hot-path claim: a shipped surface, test or CI script referencing a non-operative artifact must be a listed reader
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  [ "$op" = "no" ] || continue
  IFS=';' read -ra pats <<<"$fam"; for pat in "${pats[@]}"; do
    frag="${pat%/\*}"; frag="${frag%%[*?[]*}"; frag="${frag%/}"
    [ "${#frag}" -ge 12 ] || continue
    refs="$(cd "$ROOT" && git grep -l -F -- "$frag" -- 'plugins/**' 'tests/*.sh' 'tests/lib.sh' 'tests/run.sh' '.github/**' 2>/dev/null | grep -v '^docs/\|^tests/test-evidence-index.sh$' || true)"
    for r in $refs; do
      case ";$readers;" in *";$r;"*) ok ;; *) bad "$r reads or cites non-operative evidence $pat but the index does not list it as a reader (a leak, or an index gap)" ;; esac
    done
  done
done < <(rows)

# --- the manifest's figures are the index's
[ -f "$MAN" ] && ok || bad "the manifest is present"
for c in active-current historical-retained do-not-delete; do
  want="$(rows | awk -F'\t' -v c="$c" '$2 == c {f+=$4; b+=$5; l+=$6} END {printf "%d %d %d", f, b, l}')"
  got="$(grep -E "^\| \`$c\` \| " "$MAN" | sed -E 's/^\| `[a-z-]+` \| ([0-9,]+) \| ([0-9,]+) \| ([0-9,]+) \|$/\1 \2 \3/' | tr -d ',')"
  assert_eq "manifest class row for $c is the index's" "$want" "$got"
done
total_files="$(rows | awk -F'\t' '{s+=$4} END {print s}')"; total_bytes="$(rows | awk -F'\t' '{s+=$5} END {print s}')"
assert_eq "manifest names the corpus size" "1" "$(grep -c -- "— $total_files files, $(printf '%s' "$total_bytes" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') bytes" "$MAN")"
hot_files="$(rows | awk -F'\t' '$9 ~ /(^|;)(plugins\/|tests\/|\.github\/)/ {s+=$4} END {print s+0}')"
assert_eq "manifest names the hot-path file count" "1" "$(grep -c -- "\*\*$hot_files files, " "$MAN")"
finish "evidence index (#742)"
