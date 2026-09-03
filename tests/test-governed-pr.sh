#!/usr/bin/env bash
# #710 — the durable PR-level governor projection. The canonical `Governed by
# Spark vX.Y.Z` PR fact is derived from the SAME repository-local governor
# authority as the commit trailer, created/validated mechanically, idempotent,
# fails closed on conflict/duplicate, and stays queryable through the GitHub API
# surface after merge independent of commit topology. Governor identity only —
# no #711 execution provenance.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

GP="$WORK/plugin/skills/ship/scripts/governed-pr.sh"
[ -x "$GP" ] && ok || bad "#710: the governed-pr helper must be executable"

# A governor pinned repository-local at v0.23.0 (its bin/spark reports the version).
cp -r "$WORK/plugin" "$WORK/gov"
sed -i 's/"version": "[^"]*"/"version": "0.23.0"/' "$WORK/gov/.claude-plugin/plugin.json"
make_repo "$WORK/proj"
cd "$WORK/proj"
git config --local spark.governorBin "$WORK/gov/bin/spark"

# --- version + line derive from the repository-local canonical governor ---------
[ "$(bash "$GP" version)" = "v0.23.0" ] && ok || bad "#710: version resolves the repo-local governor (got '$(bash "$GP" version 2>&1)')"
[ "$(bash "$GP" line)" = "Governed by Spark v0.23.0" ] && ok || bad "#710: line prints the canonical fact"

# --- repository-local resolution: a GLOBAL pin must never govern -----------------
make_repo "$WORK/bare"
git -C "$WORK/bare" config --local --unset spark.governorBin 2>/dev/null || true
git config --global spark.governorBin "$WORK/gov/bin/spark"
vrc=0; ( cd "$WORK/bare" && bash "$GP" version >/dev/null 2>&1 ) || vrc=$?
[ "$vrc" = 3 ] && ok || bad "#710: a global pin must not make an unconfigured repo governed (got rc $vrc)"
git config --global --unset spark.governorBin

# --- canonical PR emission on a body that lacks the fact -------------------------
printf '## What\n\nCloses #710.\n' > "$WORK/body.md"
out="$(bash "$GP" ensure "$WORK/body.md")"
printf '%s\n' "$out" | grep -qxE 'Governed by Spark v0.23.0' && ok || bad "#710: ensure emits the canonical fact"
[ "$(printf '%s\n' "$out" | grep -cE '^Governed by Spark')" = 1 ] && ok || bad "#710: exactly one fact emitted"

# --- idempotent second application ----------------------------------------------
printf '%s' "$out" > "$WORK/body2.md"
out2="$(bash "$GP" ensure "$WORK/body2.md")"
[ "$out2" = "$out" ] && ok || bad "#710: ensure is idempotent when already correct"

# --- duplicate handling ---------------------------------------------------------
printf 'body\n\nGoverned by Spark v0.23.0\n\nGoverned by Spark v0.23.0\n' > "$WORK/dup.md"
drc=0; bash "$GP" ensure "$WORK/dup.md" >/dev/null 2>&1 || drc=$?
[ "$drc" -ne 0 ] && ok || bad "#710: a duplicate governor claim must fail closed"

# --- conflicting governor refusal -----------------------------------------------
printf 'body\n\nGoverned by Spark v9.9.9\n' > "$WORK/conflict.md"
crc=0; bash "$GP" ensure "$WORK/conflict.md" 2>"$WORK/cerr.txt" >/dev/null || crc=$?
[ "$crc" -ne 0 ] && ok || bad "#710: a conflicting governor claim must fail closed"
assert_contains "#710: the conflict diagnostic names the governor" "v0.23.0" "$(cat "$WORK/cerr.txt")"

# --- noncanonical form refusal --------------------------------------------------
printf 'body\n\ngoverned by spark v0.23.0\n' > "$WORK/nc.md"
nrc=0; bash "$GP" ensure "$WORK/nc.md" >/dev/null 2>&1 || nrc=$?
[ "$nrc" -ne 0 ] && ok || bad "#710: a noncanonical governor line must be rejected"

# --- commit / PR governor agreement ---------------------------------------------
# The commit trailer and the PR fact both derive from the pin, so they agree.
printf '%s' "$out" > "$WORK/agree.md"
bash "$GP" agree "v0.23.0" "$WORK/agree.md" && ok || bad "#710: matching commit/PR governors must agree"
arc=0; bash "$GP" agree "v0.24.0" "$WORK/agree.md" >/dev/null 2>&1 || arc=$?
[ "$arc" -ne 0 ] && ok || bad "#710: disagreeing commit/PR governors must fail"

# --- apply through the GitHub API surface, durable across commit topology --------
# A stub gh persists the PR body OUT OF BAND from git commits, exactly as GitHub
# does. Applying writes the fact into that PR body; changing commit topology
# (amend/rebase) does not touch it; re-reading via gh still returns the fact.
PRBODY="$WORK/pr-body.txt"
printf '## What\n\nCloses #710.\n' > "$PRBODY"
mkdir -p "$WORK/stub"
cat > "$WORK/stub/gh" <<STUB
#!/usr/bin/env bash
set -eu
if [ "\$1" = "pr" ] && [ "\$2" = "view" ]; then cat "$PRBODY"; exit 0; fi
if [ "\$1" = "pr" ] && [ "\$2" = "edit" ]; then cat > "$PRBODY"; exit 0; fi
exit 0
STUB
chmod +x "$WORK/stub/gh"

PATH="$WORK/stub:$PATH" bash "$GP" apply 999 >/dev/null 2>&1 && ok || bad "#710: apply must project and validate the PR fact"
grep -qxE 'Governed by Spark v0.23.0' "$PRBODY" && ok || bad "#710: the PR body must carry the canonical fact after apply"
[ "$(grep -cE '^Governed by Spark' "$PRBODY")" = 1 ] && ok || bad "#710: exactly one fact in the PR body"

# Idempotent second apply — no duplication.
PATH="$WORK/stub:$PATH" bash "$GP" apply 999 >/dev/null 2>&1 && ok || bad "#710: second apply must stay green"
[ "$(grep -cE '^Governed by Spark' "$PRBODY")" = 1 ] && ok || bad "#710: apply is idempotent (no duplicate)"

# Topology independence: rewrite commit history entirely; the PR body is unchanged
# and the fact is still retrievable through gh.
git commit -q --allow-empty -m "chore: unrelated commit"
git commit -q --allow-empty --amend -m "chore: amended, new sha"
retrieved="$(PATH="$WORK/stub:$PATH" gh pr view 999 --json body -q .body)"
printf '%s\n' "$retrieved" | grep -qxE 'Governed by Spark v0.23.0' && ok \
  || bad "#710: the PR governor fact must remain retrievable via gh independent of commit topology"

# An ungoverned repository projects nothing (no fabrication).
git config --local --unset spark.governorBin
urc=0; bash "$GP" apply 999 >/dev/null 2>&1 || urc=$?
[ "$urc" -ne 0 ] && ok || bad "#710: apply on an ungoverned repo must not fabricate a projection"

finish
