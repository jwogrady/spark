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

# --- classification follows behaviour: a family a shipped verb, a suite or a CI script reads is operative now,
# and a *historical* record in that position is a named dependency, not a footnote
DEP_MARK="CURRENT DEPENDENCY ON A HISTORICAL RECORD"
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  case "$readers" in
    *plugins/*|*tests/*|*.github/*)
      assert_eq "family $fam is read by code, so it is operative now" "yes" "$op"
      # a record of closed work that current code reads is a dependency and must say so, whatever class it carries
      case "$cls" in
        do-not-delete|historical-retained)
          case "$fam" in
            .spark/*) ;;   # the runtime's own committed state is current by definition (ADR-0031)
            *) case "$why" in "$DEP_MARK"*) ok ;; *) bad "family $fam is a closed record read by current code but is not marked '$DEP_MARK'" ;; esac ;;
          esac ;;
      esac ;;
  esac
done < <(rows)
ndep="$(rows | awk -F'\t' -v m="$DEP_MARK" 'index($10, m) == 1 {n++} END {print n+0}')"
case "$ndep" in
  1) word=One ;; 2) word=Two ;; 3) word=Three ;; 4) word=Four ;; 5) word=Five ;; *) word="$ndep" ;;
esac
grep -qF -- "## $word current-state dependencies on historical records" "$MAN" && ok || bad "the manifest's dependency heading does not name $ndep"
while IFS=$'\t' read -r fam _c op _f _b _l _cn _fa _r why; do
  case "$why" in "$DEP_MARK"*) assert_eq "the dependency $fam is operative now" "yes" "$op" ;; esac
done < <(rows)
assert_eq "the dependency table has one row per dependency" "$ndep" \
  "$(awk '/^## .* current-state dependencies on historical records$/ {sec=1; next} /^## / {sec=0} sec && /^\| `/ {n++} END {print n+0}' "$MAN")"
while IFS=$'\t' read -r fam _cls _op _f _b _l _c _fact _r why; do
  case "$why" in "$DEP_MARK"*) grep -qF -- "- **\`$fam\`**" "$MAN" && ok || bad "the manifest has no bullet for the dependency $fam" ;; esac
done < <(rows)

# --- the hot-path claim: a shipped surface, test or CI script referencing a non-operative artifact must be a listed reader
while IFS=$'\t' read -r fam cls op files bytes lines concerns fact readers why; do
  [ "$op" = "no" ] || continue
  # A family that carves paths out of a glob must be searched by the paths it covers: its directory fragment also
  # matches the excluded siblings, and their readers would be reported as this family's leak.
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
    refs="$(cd "$ROOT" && git grep -l -F -- "$frag" -- 'plugins/**' 'tests/*.sh' 'tests/lib.sh' 'tests/run.sh' '.github/**' 2>/dev/null | grep -v '^docs/\|^tests/test-evidence-index.sh$' || true)"
    for r in $refs; do
      case ";$readers;" in *";$r;"*) ok ;; *) bad "$r reads or cites non-operative evidence $pat but the index does not list it as a reader (a leak, or an index gap)" ;; esac
    done
  done
done < <(rows)

# --- the observed default reads: a committed capture, validated against HEAD's own tree
CAP="$ROOT/docs/research/v0.23-cleanup/742-default-reads.tsv"
TOOL="docs/research/v0.23-cleanup/tools/evidence-reads.sh"
[ -f "$CAP" ] && ok || bad "the observed default-read capture is committed"
[ -x "$ROOT/$TOOL" ] && ok || bad "the capture's tool is committed and executable"
cap_sha="$(sed -nE 's/^# observed default reads — clean checkout of ([0-9a-f]{40}) — strace.*/\1/p' "$CAP" | head -1)"
[ -n "$cap_sha" ] && ok || bad "the capture's header names the observed commit and the tracer"
# The capture is an observation of one commit; it may stand for HEAD only when HEAD cannot read differently.
# That needs three facts, each checked: the observed commit is in HEAD's history; the runtime that does the
# reading is byte-identical between them; and the corpus's set of paths is identical, so no verb can open a file
# that did not exist when the capture was taken (content may differ — a validator reads the file either way).
ROOTS_LS="docs/research docs/releases docs/governance docs/ops evaluations .spark"
if [ -n "$cap_sha" ]; then
  (cd "$ROOT" && git merge-base --is-ancestor "$cap_sha" HEAD) && ok || bad "the capture's commit $cap_sha is not in HEAD's history"
  assert_eq "the runtime is unchanged between the capture's commit and HEAD" "" \
    "$(cd "$ROOT" && git diff --name-only "$cap_sha" HEAD -- plugins | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "the corpus's paths are unchanged between the capture's commit and HEAD" \
    "$(cd "$ROOT" && git ls-tree -r --name-only "$cap_sha" -- $ROOTS_LS | sort)" \
    "$(cd "$ROOT" && git ls-tree -r --name-only HEAD -- $ROOTS_LS | sort)"
fi
grep -q '^# git index verified warm before tracing' "$CAP" && ok || bad "the capture does not state that the index was refreshed (a cold checkout attributes git's re-hashing to the verb)"
for v in doctor brief footprint preferences profiles list-skills; do
  grep -qxF "# $v exit 0" "$CAP" && ok || bad "the capture does not record verb $v exiting 0 (an incomplete run is not a capture)"
  assert_eq "the capture traces verb $v" "1" "$([ "$(awk -F'\t' -v v="$v" '$1 == v {print "y"; exit}' "$CAP")" = y ] && echo 1 || echo 0)"
done

# Exact-HEAD validity without a tracer. `doctor`'s Doc-links check reads every Markdown file it can find, so the
# Markdown files under the evidence roots are exactly the ones it opens; deriving that set from HEAD's tree proves
# the committed rows still describe HEAD, whatever commit they were observed at, and fails the moment a Markdown
# surface is added or removed under those roots.
md_tree="$(cd "$ROOT" && git ls-files -- 'docs/research/*.md' 'docs/research/**/*.md' 'docs/releases/*.md' 'docs/releases/**/*.md' 'docs/governance/*.md' 'docs/governance/**/*.md' 'docs/ops/*.md' 'docs/ops/**/*.md' 'evaluations/*.md' 'evaluations/**/*.md' | sort)"
md_cap="$(awk -F'\t' '$1 == "doctor" && $2 == "file" && $3 ~ /\.md$/ {print $3}' "$CAP" | sort)"
assert_eq "the capture's doctor rows are HEAD's Markdown surfaces under the evidence roots" "$md_tree" "$md_cap"

# The session path's claim, machine-checked: no verb but `doctor` opens a file under the evidence roots other than
# the two committed state files the runtime owns.
assert_eq "only doctor opens evidence files, and only .spark state otherwise" "" \
  "$(awk -F'\t' '$2 == "file" && $1 != "doctor" && $3 !~ /^\.spark\// {print $1 ":" $3}' "$CAP" | sort | tr '\n' ' ' | sed 's/ $//')"

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
      # a path under an evidence root that the index does not cover is outside the corpus (a current-truth doc)
      if printf '%s\n' "$tree" | grep -qxF "$p"; then
        [ -n "$(awk -F'\t' -v k="$p" '$1 == k {print $2}' "$CLSMAP")" ] && ok || bad "observed corpus file $p is not indexed"
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
# the page's prose figures, each computed from the capture and the index — one sentence, four numbers
doc_n="$(awk -F'\t' 'NR == FNR { cls[$1] = $2; next } $1 == "doctor" && $2 == "file" && $3 in cls { n++ } END { print n+0 }' "$CLSMAP" "$CAP")"
doc_nonop="$(awk -F'\t' 'NR == FNR { cls[$1] = $2; next } $1 == "doctor" && $2 == "file" && (cls[$3] == "historical-retained" || cls[$3] == "do-not-delete") { n++ } END { print n+0 }' "$CLSMAP" "$CAP")"
sess="$(awk -F'\t' 'NR == FNR { cls[$1] = $2; next } $2 == "file" && $1 != "doctor" && $3 in cls { seen[$3] = 1 } END { print length(seen) }' "$CLSMAP" "$CAP")"
nonop="$(awk -F'\t' 'NR == FNR { cls[$1] = $2; next } $2 == "file" && (cls[$3] == "historical-retained" || cls[$3] == "do-not-delete") { seen[$3] = 1 } END { print length(seen) }' "$CLSMAP" "$CAP")"
claim="\`spark doctor\` opens **$doc_n** indexed corpus artifacts, **$doc_nonop** of them non-operative. The session path opens **$sess** corpus files, both the runtime's own committed state. Across the six read-only verbs, **$nonop** non-operative evidence files are opened by default."
grep -qF -- "$claim" "$MAN" && ok || bad "the manifest's observed-read sentence is not the capture's: expected $claim"
# Re-observation is required wherever it is possible: a machine with a tracer re-runs the tool at HEAD and the
# committed rows must come back identical. SPARK_SKIP_OBSERVE=1 exists for sandboxes that forbid ptrace, and the
# suite says so out loud rather than passing silently.
if ! command -v strace >/dev/null 2>&1; then
  echo "  · re-observation skipped: no strace on this machine (the capture's structural checks still ran)"
elif [ "${SPARK_SKIP_OBSERVE:-0}" = 1 ]; then
  echo "  · re-observation skipped by SPARK_SKIP_OBSERVE=1 (the capture's structural checks still ran)"
else
  fresh="$(mktemp)"
  (cd "$ROOT" && bash "$TOOL" HEAD) > "$fresh" 2>/dev/null || bad "re-observation of HEAD failed"
  [ -s "$fresh" ] && ok || bad "re-observation of HEAD produced no capture"
  assert_eq "re-observing HEAD reproduces the committed rows" "$(grep -v '^#' "$CAP" | sort)" "$(grep -v '^#' "$fresh" | sort)"
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
base_sha="$(sed -nE 's/^Physical, over the same roots, against `([0-9a-f]{7})` .*/\1/p' "$MAN" | head -1)"
[ -n "$base_sha" ] && ok || bad "the manifest does not name the commit it measures against"
# --- the exclusions this metric depends on, stated and true
for m in docs/ops/evidence-index.tsv tests/test-evidence-index.sh docs/research/v0.23-cleanup/tools/evidence-reads.sh docs/research/v0.23-cleanup/742-default-reads.tsv docs/research/v0.23-cleanup/742-evidence-separation.md; do
  grep -qF -- "\`$m\`" "$MAN" && ok || bad "the manifest does not name $m as this unit's own machinery"
done
assert_eq "the index is not a member of the corpus it indexes" "" "$(printf '%s\n' "$tree" | grep -x 'docs/ops/evidence-index.tsv' || true)"
assert_eq "the suite is not a member of the corpus it checks" "" "$(printf '%s\n' "$tree" | grep -x 'tests/test-evidence-index.sh' || true)"
assert_eq "no readers column names this unit's own machinery" "" \
  "$(rows | awk -F'\t' '$9 ~ /(^|;)(docs\/ops\/evidence-index\.tsv|tests\/test-evidence-index\.sh|docs\/research\/v0\.23-cleanup\/742-evidence-separation\.md|docs\/research\/v0\.23-cleanup\/742-default-reads\.tsv|docs\/research\/v0\.23-cleanup\/tools\/evidence-reads\.sh)(;|$)/ {print $1}' | tr '\n' ' ' | sed 's/ $//')"
# --- the hot path, before and after, measured against the base commit when it is here
md_after_n="$(awk -F'\t' '$1 == "doctor" && $2 == "file" && $3 ~ /\.md$/ {n++} END {print n+0}' "$CAP")"
grep -qF -- "$md_after_n after**" "$MAN" && ok || bad "the manifest does not state the validator's current read count $md_after_n"
if [ -n "$base_sha" ] && (cd "$ROOT" && git cat-file -e "$base_sha^{commit}" 2>/dev/null); then
  # the capture's roots, so both sides of the delta count the same question
  md_before_n="$(cd "$ROOT" && git ls-tree -r --name-only "$base_sha" -- docs/research docs/releases docs/governance docs/ops evaluations .spark | grep -c '\.md$')"
  grep -qF -- "**$md_before_n files before this" "$MAN" && ok || bad "the manifest does not state the validator's earlier read count $md_before_n"
  printf -v want "%+d" "$((md_after_n - md_before_n))"
  grep -qF -- "delta of **$want**" "$MAN" && ok || bad "the manifest does not state the hot-path delta $want"
else
  echo "  · hot-path before/after check skipped: the base commit is not in this checkout"
fi
# --- before/after: the after figures are the tree's, and the before figures are the base commit's when it is here

assert_eq "the manifest's after row is the tree's" "1" "$(grep -c "^| after | $total_files | $(printf '%s' "$total_bytes" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') | " "$MAN")"
if [ -n "$base_sha" ] && (cd "$ROOT" && git cat-file -e "$base_sha^{commit}" 2>/dev/null); then
  bf="$(cd "$ROOT" && git ls-tree -r --name-only "$base_sha" -- docs/research docs/releases docs/governance docs/ops/v0.21-dogfood-evaluation.md docs/ops/telemetry-baseline.md docs/ops/evaluation.md evaluations .spark | grep -c .)"
  assert_eq "the manifest's before row is the base commit's file count" "1" "$(grep -c "^| before | $bf | " "$MAN")"
else
  echo "  · before-figure check skipped: the base commit is not in this checkout"
fi
finish "evidence index (#742)"
