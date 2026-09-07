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

# --- the hot-path claim: a shipped surface, test or CI script referencing a non-operative artifact must be a listed reader
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  [ "$op" = "no" ] || continue
  IFS=';' read -ra pats <<<"$fam"; for pat in "${pats[@]}"; do
    frag="${pat%/\*\*}"; frag="${frag%/\*}"; frag="${frag%%[*?[]*}"; frag="${frag%/}"
    [ "${#frag}" -ge 12 ] || continue
    refs="$(cd "$ROOT" && git grep -l -F -- "$frag" -- 'plugins/**' 'tests/*.sh' 'tests/lib.sh' 'tests/run.sh' '.github/**' 2>/dev/null | grep -v '^docs/\|^tests/test-evidence-index.sh$' || true)"
    for r in $refs; do
      case ";$readers;" in *";$r;"*) ok ;; *) bad "$r reads or cites non-operative evidence $pat but the index does not list it as a reader (a leak, or an index gap)" ;; esac
    done
  done
done < <(rows)

# --- the observed default reads: the committed capture names the tree and the tracer, and opens no historical evidence
CAP="$ROOT/docs/research/v0.23-cleanup/742-default-reads.tsv"
[ -f "$CAP" ] && ok || bad "the observed default-read capture is committed"
cap_sha="$(head -1 "$CAP" | sed -nE 's/^# observed default reads — clean checkout of ([0-9a-f]{40}) — strace.*/\1/p')"
[ -n "$cap_sha" ] && ok || bad "the capture's header names the observed commit and the tracer"
if [ -n "$cap_sha" ]; then
  (cd "$ROOT" && git merge-base --is-ancestor "$cap_sha" HEAD) && ok || bad "the capture's commit $cap_sha is not an ancestor of HEAD (a capture must observe this history)"
fi
[ -x "$ROOT/docs/research/v0.23-cleanup/tools/evidence-reads.sh" ] && ok || bad "the capture's tool is committed and executable"
for v in doctor brief footprint preferences profiles list-skills; do
  assert_eq "the capture traces verb $v" "1" "$([ "$(awk -F'\t' -v v="$v" '$1 == v {print "y"; exit}' "$CAP")" = y ] && echo 1 || echo 0)"
done
# every corpus artifact's class, by path — the join key between the capture and the index
CLSMAP="$(mktemp)"; trap 'rm -f "$CLSMAP"' EXIT
while IFS= read -r p; do
  while IFS=$'\t' read -r fam c _rest; do
    if family_covers "$fam" "$p"; then printf '%s\t%s\n' "$p" "$c" >> "$CLSMAP"; break; fi
  done < <(rows)
done <<<"$tree"
nfile=0
while IFS=$'\t' read -r v kind p n; do
  [ "$v" = "verb" ] && continue
  case "$kind" in
    file)
      nfile=$((nfile+1))
      [ -f "$ROOT/$p" ] && ok || bad "observed file $p does not exist in the tree"
      # a path under an evidence root that the index does not cover must be outside the corpus by construction
      if printf '%s\n' "$tree" | grep -qxF "$p"; then
        grep -qxF "$p	$(awk -F'\t' -v k="$p" '$1 == k {print $2}' "$CLSMAP")" "$CLSMAP" && ok || bad "observed corpus file $p is not indexed"
      fi
      ;;
    dir) [ -d "$ROOT/${p%/}" ] && ok || bad "observed directory $p does not exist in the tree" ;;
    none) assert_eq "verb $v opened nothing, recorded as such" "-	0" "$p	$n" ;;
    *) bad "unknown observed kind $kind" ;;
  esac
done < <(grep -v '^#' "$CAP")
[ "$nfile" -ge 1 ] && ok || bad "the capture observes at least one file read (an empty capture proves nothing)"
# the manifest's per-verb observed figures are the capture's, joined to the index by class
for v in doctor brief footprint preferences profiles list-skills; do
  row="$(awk -F'\t' -v v="$v" '
    NR == FNR { cls[$1] = $2; next }
    $1 == v && $2 == "file" { if ($3 in cls) { inside++; per[cls[$3]]++ } else { outside++ } }
    $1 == v && $2 == "dir" { dirs++ }
    END { printf "| `%s` | %d | %d | %d | %d | %d | %d |", v, inside+0, per["historical-retained"]+0, per["do-not-delete"]+0, per["active-current"]+0, dirs+0, outside+0 }
  ' "$CLSMAP" "$CAP")"
  grep -qxF -- "$row" "$MAN" && ok || bad "the manifest's observed row for $v is not the capture's: expected $row"
done
# the count of non-operative history the default path opens, as the page states it
nonop="$(awk -F'\t' 'NR == FNR { cls[$1] = $2; next } $2 == "file" && (cls[$3] == "historical-retained" || cls[$3] == "do-not-delete") { seen[$3] = 1 } END { print length(seen) }' "$CLSMAP" "$CAP")"
grep -qF -- "**$nonop are non-operative history**" "$MAN" && ok || bad "the manifest does not state the observed non-operative count $nonop"
[ "$nonop" -gt 0 ] && { grep -q "^## Three leaks" "$MAN" && ok || bad "history is on the default path but the manifest does not record it as a leak"; }
# opt-in re-observation: on a machine with strace, re-run the tool at the capture's own commit and compare
if [ "${SPARK_OBSERVE_READS:-0}" = 1 ] && command -v strace >/dev/null 2>&1 && [ -n "$cap_sha" ]; then
  fresh="$(mktemp)"; (cd "$ROOT" && bash docs/research/v0.23-cleanup/tools/evidence-reads.sh "$cap_sha") > "$fresh" 2>/dev/null || bad "re-observation failed"
  assert_eq "re-observing $cap_sha reproduces the committed rows" "$(grep -v '^#' "$CAP" | sort)" "$(grep -v '^#' "$fresh" | sort)"
  rm -f "$fresh"
fi
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
assert_eq "manifest names the reference-footprint file count" "1" "$(grep -c -- "\*\*$hot_files files, " "$MAN")"
grep -q "labelled as references, not loads" "$MAN" && ok || bad "the manifest labels the static footprint as references"
finish "evidence index (#742)"
