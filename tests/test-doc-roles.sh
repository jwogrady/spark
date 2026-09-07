#!/usr/bin/env bash
# Behavioral suite for the documentation role register and the canonical-truth map (#741): every documentation surface of
# the repository is registered exactly once with one role from the closed vocabulary; no surface is left in a finding
# state; a surface registered as superseded or banner-marked says so in its first lines; every governed concept has one
# operative source (the map's row, or exactly one operative-authority surface); every locator the map names resolves,
# and every projection it names is registered as a projection, an explanation or an operative contract.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REG="$ROOT/docs/ops/doc-roles.tsv"; MAP="$ROOT/docs/ops/canonical-truth.tsv"
[ -f "$REG" ] && ok || bad "docs/ops/doc-roles.tsv is present"
[ -f "$MAP" ] && ok || bad "docs/ops/canonical-truth.tsv is present"

rows() { grep -v '^#' "$REG" | grep -v '^$'; }
# every documentation surface of the covered roots (Markdown, and the YAML issue forms) is registered exactly once
tree="$(cd "$ROOT" && git ls-files -- AGENTS.md CLAUDE.md README.md ROADMAP.md 'docs/*.md' 'docs/**/*.md' 'plugins/*/docs/**' 'plugins/*/skills/*/SKILL.md' 'plugins/*/skills/*/references/*.md' '.github/*.md' '.github/**/*.md' '.github/ISSUE_TEMPLATE/*.yml' | grep -E '\.(md|yml)$' | sort)"
reg="$(rows | cut -f1 | sort)"
assert_eq "every surface is registered and nothing else is" "" "$(comm -3 <(printf '%s\n' "$tree") <(printf '%s\n' "$reg") | tr '\n' ' ' | sed 's/ $//')"
assert_eq "no surface is registered twice" "" "$(rows | cut -f1 | sort | uniq -d | tr '\n' ' ')"
assert_eq "every row has four columns" "" "$(rows | awk -F'\t' 'NF != 4 {print NR}' | tr '\n' ' ')"
assert_eq "every role is in the closed vocabulary" "" "$(rows | cut -f2 | grep -vE '^(operative-authority|current-projection|explanation|historical-evidence|superseded)$' | sort -u | tr '\n' ' ')"
assert_eq "no surface is left in a finding state (duplicate, false-stale)" "" "$(rows | awk -F'\t' '$2 == "duplicate" || $2 == "false-stale" {print $1}' | tr '\n' ' ')"
# a surface marked superseded, or noted as carrying a banner, says so in its first lines
while IFS=$'\t' read -r p role concepts note; do
  case "$role" in superseded) head -12 "$ROOT/$p" | grep -qi "superseded" && ok || bad "$p is registered superseded but does not say so in its first lines" ;; esac
  case "$note" in banner:*) head -12 "$ROOT/$p" | grep -q "Historical record" && ok || bad "$p is noted as banner-marked but carries no 'Historical record' line" ;; esac
done < <(rows)

# ---- the canonical-truth map
mrows() { grep -v '^#' "$MAP" | grep -v '^$'; }
assert_eq "every map row has six columns" "" "$(mrows | awk -F'\t' 'NF != 6 {print NR}' | tr '\n' ' ')"
assert_eq "every concept has exactly one map row" "" "$(mrows | cut -f1 | sort | uniq -d | tr '\n' ' ')"
role_of() { rows | awk -F'\t' -v p="$1" '$1 == p {print $2}'; }
while IFS=$'\t' read -r concept sources projections historical risk treatment; do
  [ -n "$risk" ] && [ -n "$treatment" ] && ok || bad "$concept: drift risk and treatment are stated"
  IFS=';' read -ra srcs <<<"$sources"
  [ "${#srcs[@]}" -ge 1 ] && ok || bad "$concept names an operative source"
  # one operative source, or a declared composite (which aspect each source owns), or an explicit exception
  if [ "${#srcs[@]}" -gt 1 ]; then
    case "$treatment" in COMPOSITE:*|EXCEPTION:*) ok ;; *) bad "$concept names ${#srcs[@]} operative sources without declaring a composite or an exception" ;; esac
  fi
  for s in "${srcs[@]}"; do
    case "$s" in
      github:*) printf '%s' "$s" | grep -qE '^github:[a-z0-9.-]+/[a-z0-9_.-]+(#[1-9][0-9]*|/milestones)$' && ok || bad "$concept: $s is not a canonical GitHub locator (a decision record or the milestone list)" ;;
      ci:*) [ -f "$ROOT/${s#ci:}" ] && ok || bad "$concept: CI surface ${s#ci:} does not exist" ;;
      code:*) [ -f "$ROOT/${s#code:}" ] && ok || bad "$concept: runtime surface ${s#code:} does not exist" ;;
      *) [ -f "$ROOT/$s" ] && ok || bad "$concept: operative source $s does not exist"
         case "$s" in
           *.tsv|*.json) ok ;;   # machine-readable authorities are data, not registered prose
           *) [ "$(role_of "$s")" = "operative-authority" ] && ok || bad "$concept: prose source $s is not registered as operative-authority (role: $(role_of "$s"))" ;;
         esac ;;
    esac
  done
  if [ "$projections" != "-" ]; then
    IFS=';' read -ra prj <<<"$projections"
    for p in "${prj[@]}"; do
      [ -f "$ROOT/$p" ] && ok || bad "$concept: projection $p does not exist"
      case "$(role_of "$p")" in current-projection|explanation|operative-authority) ok ;; *) bad "$concept: projection $p is registered as '$(role_of "$p")', not as a projection, an explanation or an operative contract" ;; esac
    done
  fi
  if [ "$historical" != "-" ]; then
    IFS=';' read -ra hst <<<"$historical"
    for h in "${hst[@]}"; do [ -f "$ROOT/$h" ] && ok || bad "$concept: historical surface $h does not exist"; [ -n "$(role_of "$h")" ] && ok || bad "$concept: historical surface $h is not registered"; done
  fi
  case "$treatment" in *EXCEPTION*|*"DECISION REQUIRED"*) printf '%s' "$risk$treatment" | grep -q "#" && ok || bad "$concept: an exception or open decision names the record or PR it rests on" ;; esac
done < <(mrows)
# every surface a map row names carries that concept in the register (map/register consistency)
while IFS=$'\t' read -r concept sources projections historical _r _t; do
  for p in $(printf '%s;%s;%s' "$sources" "$projections" "$historical" | tr ';' '\n' | grep -vE '^(-|ci:.*|code:.*|github:.*|.*\.tsv|.*\.json)$'); do
    cs="$(rows | awk -F'\t' -v p="$p" '$1 == p {print $3}')"
    case ",$cs," in *",$concept,"*) ok ;; *) bad "$p is named by the $concept row but its register concepts are '$cs'" ;; esac
  done
done < <(mrows)
# one operative source per governed concept: the map's row, or exactly one operative-authority surface
mapped="$(mrows | cut -f1 | sort -u)"
for c in $(rows | cut -f3 | tr ',' '\n' | grep -v '^-$' | sort -u); do
  if printf '%s\n' "$mapped" | grep -qx "$c"; then ok; else
    n="$(rows | awk -F'\t' -v c="$c" '$2 == "operative-authority" && ("," $3 ",") ~ ("," c ",") {n++} END {print n+0}')"
    [ "$n" = 1 ] && ok || bad "concept $c has no map row and $n operative-authority surfaces (needs exactly one)"
  fi
done
# the register's operative concepts that the map covers are the map's prose sources or contracts the map names as such
for c in $mapped; do
  ops="$(rows | awk -F'\t' -v c="$c" '$2 == "operative-authority" && ("," $3 ",") ~ ("," c ",") {print $1}')"
  srcs="$(mrows | awk -F'\t' -v c="$c" '$1 == c {print $2 ";" $3 ";" $4}' | tr ';' '\n')"
  for o in $ops; do printf '%s\n' "$srcs" | grep -qx "$o" && ok || bad "concept $c: $o is registered operative-authority but the map does not name it as a source, a projection or a historical surface of the concept"; done
done
# the manifest's figures are the data's: role counts and the after-column are recomputed and compared
MAN="$ROOT/docs/research/v0.23-cleanup/741-canonical-truth.md"
[ -f "$MAN" ] && ok || bad "the manifest is present"
for role in operative-authority current-projection explanation historical-evidence superseded; do
  want="$(rows | awk -F'\t' -v r="$role" '$2 == r {n++} END {print n+0}')"
  got="$(grep -E "^\| \`$role\` \| [0-9]+ \|$" "$MAN" | sed -E 's/^\| `[a-z-]+` \| ([0-9]+) \|$/\1/')"
  assert_eq "manifest role count for $role is the register's" "$want" "$got"
done
while IFS=$'\t' read -r concept sources _p _h _r _t; do
  prose="$(printf '%s' "$sources" | tr ';' '\n' | grep -cvE '^(ci|github|code):' || true)"; other="$(printf '%s' "$sources" | tr ';' '\n' | grep -cE '^(ci|github|code):' || true)"
  want="$prose"; [ "$other" -gt 0 ] && want="$prose + $other non-prose"
  got="$(grep -E "^\| \`$concept\` \| [^|]+ \| [^|]+ \|$" "$MAN" | sed -E 's/^\| `[a-z-]+` \| [^|]+ \| ([^|]+) \|$/\1/')"
  assert_eq "manifest after-count for $concept is the map's" "$want" "$got"
  before="$(grep -E "^\| \`$concept\` \| [^|]+ \| [^|]+ \|$" "$MAN" | sed -E 's/^\| `[a-z-]+` \| ([^|]+) \| [^|]+ \|$/\1/')"
  printf '%s' "$before" | grep -qE '^[0-9]+$' && ok || bad "manifest before-count for $concept is a number, not '$before'"
done < <(mrows)
assert_eq "the manifest names the register's row count" "1" "$(grep -c -- "— $(rows | grep -c .) files:" "$MAN")"
finish "documentation roles and canonical truth (#741)"
