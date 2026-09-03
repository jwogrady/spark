#!/usr/bin/env bash
# End-to-end #710: `spark install-git-hooks` wires governance provenance so a REAL
# governed commit carries Spark-Governed-By from the INSTALLED governor — not the
# target repo's own unreleased manifest — without touching author identity.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# The installed governor: a Spark plugin whose manifest advertises 0.23.0.
cp -r "$WORK/plugin" "$WORK/gov"
sed -i 's/"version": "[^"]*"/"version": "0.23.0"/' "$WORK/gov/.claude-plugin/plugin.json"
GOV="$WORK/gov/bin/spark"

make_repo "$WORK/proj"
cd "$WORK/proj"
# The working tree advertises a LATER, unreleased version — the self-development
# shape: installed v0.23 governs a v0.24 checkout.
mkdir -p .claude-plugin
printf '{\n  "name": "spark",\n  "version": "0.24.0"\n}\n' > .claude-plugin/plugin.json

# Install hooks AS the governor (bin/spark resolves its own SPARK_ROOT).
"$GOV" install-git-hooks >/dev/null 2>&1

# The governor that installed the hooks is pinned in git config.
[ "$(git config --get spark.governorBin)" = "$GOV" ] && ok \
  || bad "#710: install-git-hooks must pin the installed governor bin (got '$(git config --get spark.governorBin)')"

# A real governed commit on a feature branch (pre-commit blocks master).
git checkout -q -b feat/x
printf 'hi\n' > f.txt
git add f.txt
git commit -q -m "feat: add a real governed thing" -m "why this matters"
msg="$(git log -1 --format='%B')"

case "$msg" in
  *"Spark-Governed-By: v0.23.0"*) ok ;;
  *) bad "#710: a real governed commit must carry Spark-Governed-By: v0.23.0 (got: $msg)" ;;
esac
case "$msg" in
  *v0.24.0*) bad "#710: the working tree's unreleased v0.24.0 must never be stamped" ;;
  *) ok ;;
esac
n="$(printf '%s\n' "$msg" | grep -c '^Spark-Governed-By:' || true)"
[ "$n" = 1 ] && ok || bad "#710: exactly one Spark-Governed-By trailer on a real commit (got $n)"

# Attribution must not change author/committer identity, nor add any AI co-author.
[ "$(git log -1 --format='%an')" = "Spark Tests" ] && ok \
  || bad "#710: the Git author identity must be unchanged ($(git log -1 --format='%an'))"
case "$msg" in
  *[Cc]o-[Aa]uthored-[Bb]y*) bad "#710: no co-author trailer may be created" ;;
  *) ok ;;
esac

# A second commit does not accumulate a second trailer, and stays governed.
printf 'more\n' >> f.txt
git add f.txt
git commit -q -m "fix: refine the governed thing"
msg2="$(git log -1 --format='%B')"
n2="$(printf '%s\n' "$msg2" | grep -c '^Spark-Governed-By:' || true)"
[ "$n2" = 1 ] && ok || bad "#710: each governed commit carries exactly one trailer (got $n2)"

# Once the governor is PINNED, the canonical pin wins: an override pointing at a
# DIFFERENT binary must fail closed, never silently stamp a foreign version.
cp -r "$WORK/plugin" "$WORK/other"
sed -i 's/"version": "[^"]*"/"version": "9.9.9"/' "$WORK/other/.claude-plugin/plugin.json"
printf 'again\n' >> f.txt; git add f.txt
orc=0
SPARK_GOVERNOR_BIN="$WORK/other/bin/spark" git commit -q -m "feat: overridden" 2>"$WORK/oerr.txt" || orc=$?
[ "$orc" -ne 0 ] && ok || bad "#710: an override disagreeing with the pinned governor must fail closed"
case "$(cat "$WORK/oerr.txt")" in *disagrees*) ok ;; *) bad "#710: the override-conflict diagnostic must name the disagreement" ;; esac

# A governed repo whose pinned governor is broken must STOP the commit, not fall
# through to another binary or silently omit provenance.
git config spark.governorBin "$WORK/nonexistent/bin/spark"
brc=0
git commit -q -m "feat: broken governor" 2>"$WORK/berr.txt" || brc=$?
[ "$brc" -ne 0 ] && ok || bad "#710: a governed repo with a broken pinned governor must fail closed"
# restore the good pin so the tree is left consistent
git config spark.governorBin "$GOV"

finish
