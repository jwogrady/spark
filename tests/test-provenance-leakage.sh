#!/usr/bin/env bash
# Behavioural suite for #476 — provenance leakage as a classified finding.
#
# The producer under test is the REAL one, invoked as a command against sandbox
# repositories built here. Nothing re-implements its rule: a replica passes while
# the original is wrong, which is the failure that made #611's order defect
# survive a suite claiming its consumers agreed.
#
# ADVERSARIAL PAIRS, NOT KEYWORDS. Every positive fixture has a negative twin
# carrying the SAME versions, the SAME dates and the SAME historical vocabulary,
# differing only in what the surface owns or whether the passage anchors to
# provenance. A detector that passed by recognising words would fail these pairs,
# and a detector tuned to the exact strings #475 removed would fail them too —
# none of those strings appears here.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

SCAN="$repo_root/plugins/spark-audit/skills/audit/scripts/provenance-scan.sh"

# fixture_repo <name> — a sandbox with two owning release records. The owner
# index is derived from the repo, so the fixtures must supply it rather than
# leaning on Spark's own docs/releases/.
fixture_repo() {
  local r="$WORK/$1"
  mkdir -p "$r/docs/releases" "$r/docs/adr" "$r/docs/ops" "$r/docs/architecture" "$r/plugins/x/docs"
  printf '# v1.2\n\nThe v1.2 release record.\n' > "$r/docs/releases/v1.2.md"
  printf '# v1.3\n\nThe v1.3 release record.\n' > "$r/docs/releases/v1.3.md"
  printf '%s' "$r"
}

# class_of <root> <path> — the class the real producer assigns.
#
# `|| true`: the producer exits 3 for NOT-ASSESSED, which is a RESULT, not a
# failure of the run. Under `set -e` an unguarded substitution would abort the
# suite at the first unread fixture — and those fixtures are the point.
class_of() { bash "$SCAN" scan "$2" "$1" 2>/dev/null | awk -F'\t' 'NR==1 { print $2 }' || true; }
disp_of()  { bash "$SCAN" scan "$2" "$1" 2>/dev/null | awk -F'\t' 'NR==1 { print $3 }' || true; }
mclass()   { bash "$1" scan "$3" "$2" 2>/dev/null | awk -F'\t' 'NR==1 { print $2 }' || true; }

expect_class() {
  local label="$1" root="$2" path="$3" want="$4" got
  got="$(class_of "$root" "$path")"
  if [ "$got" = "$want" ]; then ok; else bad "$label — want $want, got '$got'"; fi
}

R="$(fixture_repo main)"

# --- POSITIVE: provenance leakage --------------------------------------------
# A current-state surface carrying an account across two owned subjects, with no
# anchor to any authority. This is the shape #475 removed from ROADMAP.md.
cat > "$R/ROADMAP.md" <<'EOF'
# Roadmap

Current phase: beta.

The v1.2 publication was withdrawn after the tag was cut, and the work was
replanned and shipped inside v1.3 instead. The baseline moved back until the
catch-up tag existed.
EOF
expect_class "a current-state surface retelling an owned account leaks" \
  "$R" ROADMAP.md PROVENANCE-ONLY
if [ "$(disp_of "$R" ROADMAP.md)" = "REWRITE-COLLAPSE" ]; then ok
else bad "leakage must propose REWRITE-COLLAPSE, got '$(disp_of "$R" ROADMAP.md)'"; fi

# --- NEGATIVE TWIN: same words, anchored to provenance -----------------------
# Identical versions, identical vocabulary, one difference: it cites the record
# that owns the account. Citation carries evidence; the tree carries conclusion.
cat > "$R/docs/architecture/map.md" <<'EOF'
# Map

The v1.2 publication was withdrawn and the work shipped inside v1.3 instead.
The account is docs/releases/v1.3.md, which owns it.
EOF
expect_class "the same account, citing its owner, is not leakage" \
  "$R" docs/architecture/map.md CURRENT-STATE

# --- NEGATIVE TWIN: same words, anchored by issue/PR -------------------------
cat > "$R/docs/ops/runbook.md" <<'EOF'
# Runbook

Always cut the tag from trunk.

Observed when v1.2 and v1.3 were published: the branch merged after the tag
existed, so the commit shipped a release later than intended. See PR #464.
EOF
expect_class "a runbook citing the incident that justifies its rule is not leakage" \
  "$R" docs/ops/runbook.md CURRENT-STATE

# --- NEGATIVE: durable rationale in a decision record ------------------------
# Names one owned subject and explains a rejected alternative. Required to
# understand the current shape; must never be flagged.
cat > "$R/docs/adr/0001-thing.md" <<'EOF'
# ADR: the thing

## Decision

Use a single writer.

## Alternatives Considered

- **Two writers.** Rejected: it violates the one-writer invariant, which is why
  v1.2 could not be reconciled without a manual pass.
EOF
expect_class "a rejected alternative is durable rationale, not leakage" \
  "$R" docs/adr/0001-thing.md DURABLE-RATIONALE

# --- NEGATIVE: the account on the surface that owns it -----------------------
# The SAME narrative as the positive fixture, on a release record. Its role is
# the account, so it is retained evidence.
cat > "$R/docs/releases/v1.3.md" <<'EOF'
# v1.3

The v1.2 publication was withdrawn after the tag was cut, and the work was
replanned and shipped inside v1.3 instead. The baseline moved back until the
catch-up tag existed.
EOF
expect_class "chronology on the surface that owns it is retained evidence" \
  "$R" docs/releases/v1.3.md RETAINED-EVIDENCE

# --- NEGATIVE: generated projection ------------------------------------------
cat > "$R/CHANGELOG.md" <<'EOF'
# Changelog

## v1.3

* thing ([abc1234](https://example.invalid/abc1234))

## v1.2

* other thing
EOF
expect_class "a generated changelog is a projection, not hand-authored leakage" \
  "$R" CHANGELOG.md GENERATED-PROJECTION

# --- NOT ASSESSED is never PASS ----------------------------------------------
expect_class "an undeclared surface is not assessed" "$R" src/thing.py NOT-ASSESSED
expect_class "a missing file is not assessed"        "$R" README.md    NOT-ASSESSED

# NOT-ASSESSED carries NO disposition — core's two-axis rule. A disposition here
# would be a guessed decision over evidence nobody read.
if [ -z "$(disp_of "$R" src/thing.py)" ]; then ok
else bad "NOT-ASSESSED must carry no disposition, got '$(disp_of "$R" src/thing.py)'"; fi

# An unreadable owner index is not "no owners": it is unread.
RB="$(fixture_repo broken)"
printf '# Roadmap\n\nv1.2 and v1.3 both moved.\n' > "$RB/ROADMAP.md"
rm -rf "$RB/docs/releases"
expect_class "an unreadable owner index is not assessed" "$RB" ROADMAP.md NOT-ASSESSED

# --- a single mention is a status line, not an account -----------------------
cat > "$R/docs/architecture/status.md" <<'EOF'
# Status

The v1.2 line is complete and no further work is planned against it.
EOF
expect_class "naming one owned subject is not an account" \
  "$R" docs/architecture/status.md CURRENT-STATE

# --- MUTATION CONTROLS -------------------------------------------------------
#
# Each disables one clause of the REAL producer, on a copy, and requires a
# fixture to change verdict. A control that cannot fail proves nothing.

mutant() { sed "$1" "$SCAN" > "$WORK/$2"; printf '%s' "$WORK/$2"; }

# 1. Bypass the classification entirely: treat EVERY surface as one that owns
#    chronology, so no current-state surface can ever produce a finding. The
#    positive fixture must stop being detected.
M1="$(mutant 's/\*) return 1 ;; esac/*) return 0 ;; esac/' m1.sh)"
if ! cmp -s "$SCAN" "$M1"; then ok; else bad "MUTATION 1 changed nothing — the control proves nothing"; fi
if [ "$(mclass "$M1" "$R" ROADMAP.md)" != "PROVENANCE-ONLY" ]; then ok
else bad "MUTATION 1 — bypassing the ownership clause still reported leakage; the positive fixture does not discriminate"; fi

# 2. Weaken the boundary to "contains historical references" by dropping the
#    two-subject requirement. The single-mention status line must then be
#    misclassified, proving that clause is what protects it.
M2="$(mutant 's/if (hits >= 2 \&\& !cited)/if (hits >= 1 \&\& !cited)/' m2.sh)"
if [ "$(mclass "$M2" "$R" docs/architecture/status.md)" = "PROVENANCE-ONLY" ]; then ok
else bad "MUTATION 2 — relaxing the two-subject clause did not misclassify a status line; that clause is untested"; fi

# 3. Remove the citation clause. The anchored negative twins must then be
#    misclassified, proving citation is what exonerates them.
M3="$(mutant 's/      if (anchored(block)) cited = 1//' m3.sh)"
if [ "$(mclass "$M3" "$R" docs/ops/runbook.md)" = "PROVENANCE-ONLY" ]; then ok
else bad "MUTATION 3 — removing the anchor clause did not misclassify the cited runbook; that clause is untested"; fi

# 4. Generated projection must not be reachable as hand-authored leakage even
#    when the chronology clause is relaxed: its surface owns the account.
if [ "$(mclass "$M2" "$R" CHANGELOG.md)" = "GENERATED-PROJECTION" ]; then ok
else bad "a relaxed chronology clause reclassified the generated changelog"; fi

# 5. And a release record stays retained evidence under the same relaxation.
if [ "$(mclass "$M2" "$R" docs/releases/v1.3.md)" = "RETAINED-EVIDENCE" ]; then ok
else bad "a relaxed chronology clause reclassified a release record"; fi

# --- the producer is read-only ------------------------------------------------
before="$(find "$R" -type f -exec md5sum {} + | sort)"
bash "$SCAN" scan ROADMAP.md "$R" >/dev/null 2>&1 || true
bash "$SCAN" scan docs/releases/v1.3.md "$R" >/dev/null 2>&1 || true
after="$(find "$R" -type f -exec md5sum {} + | sort)"
if [ "$before" = "$after" ]; then ok; else bad "the producer mutated the tree it scanned"; fi

finish
