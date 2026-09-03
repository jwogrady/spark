#!/usr/bin/env bash
# Regression tests for the commit-msg git hook: conventional-commit rules,
# git-generated subject exemptions, and the AI-attribution ban.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

hook="$WORK/plugin/scripts/hooks/commit-msg"
msg="$WORK/msg.txt"

run_hook() { printf '%s\n' "$1" > "$msg"; local rc=0; bash "$hook" "$msg" >/dev/null 2>&1 || rc=$?; echo "$rc"; }

allow() { assert_rc "$1" 0 "$(run_hook "$2")"; }
deny()  { local rc; rc="$(run_hook "$2")"; if [ "$rc" -ne 0 ]; then ok; else bad "$1 — expected rejection"; fi; }

# --- conventional subjects
allow "feat subject"                "feat: add a thing"
allow "scoped fix"                  "fix(guard): close a bypass"
allow "breaking marker"             "feat!: change the contract"
deny  "no type prefix"              "add a thing"
deny  "unknown type"                "wip: half done"
deny  "trailing period"             "feat: add a thing."
deny  "subject over 72 chars"       "feat: $(printf 'x%.0s' $(seq 1 80))"

# --- git-generated subjects are exempt from style rules
allow "merge branch"                "Merge branch 'feat/x'"
allow "merge pull request"          "Merge pull request #1 from jwogrady/feat-x"
allow "revert"                      'Revert "feat: something"'
allow "autosquash fixup"            "fixup! feat: earlier thing"
allow "autosquash squash"           "squash! feat: earlier thing"
deny  "hand-written merge prose"    "Merged some stuff by hand"

# --- AI attribution is banned everywhere, git-generated or not
deny  "co-author trailer"           "feat: x

Co-authored-by: Claude <noreply@anthropic.com>"
deny  "generated-with line"         "feat: x

Generated with Claude Code"
deny  "attribution on a merge"      "Merge branch 'x'

Co-authored-by: Claude <noreply@anthropic.com>"

# --- #710 governance provenance -----------------------------------------------
# A repo governed by INSTALLED Spark records which RELEASED governor produced the
# work — provenance, not authorship, never an AI/worker credit. The value comes
# from the installed governor's own `spark version` (the single version authority),
# never the target repo's unreleased manifest.

# make_governor <dir> <version> — a real Spark plugin copy whose manifest advertises
# <version>; its bin/spark is the installed governor the hook asks for a version.
make_governor() {
  cp -r "$WORK/plugin" "$1"
  sed -i 's/"version": "[^"]*"/"version": "'"$2"'"/' "$1/.claude-plugin/plugin.json"
}
make_governor "$WORK/gov" "0.23.0"
GOVBIN="$WORK/gov/bin/spark"

# The working repository advertises a LATER, unreleased version — the exact Spark
# self-development shape: an installed v0.23 governor developing a v0.24 checkout.
make_repo "$WORK/proj"
mkdir -p "$WORK/proj/.claude-plugin"
printf '{\n  "name": "spark",\n  "version": "0.24.0"\n}\n' > "$WORK/proj/.claude-plugin/plugin.json"

gmsg="$WORK/gmsg.txt"
gov_count() { grep -icE '^Spark-Governed-By:' "$gmsg" || true; }
# gov_hook runs the hook AS the governor, from inside the working repo.
gov_hook() { ( cd "$WORK/proj" && SPARK_GOVERNOR_BIN="$GOVBIN" bash "$hook" "$gmsg" >/dev/null 2>&1 ); }

# 1. the installed v0.23 governor stamps the v0.24 working tree with v0.23.0 — the
#    resolved value is the installed governor's, never the working manifest's.
printf 'feat: implement a thing\n\nwhy it matters\n' > "$gmsg"; gov_hook
[ "$(gov_count)" = 1 ] && ok || bad "#710: a governed commit gets exactly one Spark-Governed-By (got $(gov_count))"
assert_contains "#710: the stamp is the installed governor v0.23.0" "Spark-Governed-By: v0.23.0" "$(cat "$gmsg")"
case "$(cat "$gmsg")" in
  *v0.24.0*) bad "#710: the working tree's unreleased v0.24.0 must never be stamped" ;;
  *) ok ;;
esac

# 2. re-running / amending never duplicates the trailer.
gov_hook
[ "$(gov_count)" = 1 ] && ok || bad "#710: re-running must not duplicate the trailer (got $(gov_count))"

# 3. a conflicting supplied governor fails closed with a diagnostic naming the resolved one.
printf 'feat: x\n\nbody\n\nSpark-Governed-By: v9.9.9\n' > "$gmsg"
crc=0; ( cd "$WORK/proj" && SPARK_GOVERNOR_BIN="$GOVBIN" bash "$hook" "$gmsg" 2>"$WORK/gerr.txt" >/dev/null ) || crc=$?
[ "$crc" -ne 0 ] && ok || bad "#710: a conflicting Spark-Governed-By must fail closed"
assert_contains "#710: the conflict diagnostic names the resolved governor" "v0.23.0" "$(cat "$WORK/gerr.txt")"

# 4. a duplicate supplied trailer is never canonical — fail closed.
printf 'feat: x\n\nbody\n\nSpark-Governed-By: v0.23.0\nSpark-Governed-By: v0.23.0\n' > "$gmsg"
drc=0; gov_hook || drc=$?
[ "$drc" -ne 0 ] && ok || bad "#710: a duplicate Spark-Governed-By must fail closed"

# 5. a matching supplied trailer is accepted and stays single.
printf 'feat: x\n\nbody\n\nSpark-Governed-By: v0.23.0\n' > "$gmsg"; gov_hook
[ "$(gov_count)" = 1 ] && ok || bad "#710: a matching supplied trailer must stay single (got $(gov_count))"

# 6. optional run identity appears ONLY when a durable one exists — never invented.
printf 'fix: y\n\nbody\n' > "$gmsg"; ( cd "$WORK/proj" && SPARK_GOVERNOR_BIN="$GOVBIN" SPARK_RUN_ID=run-42 bash "$hook" "$gmsg" >/dev/null 2>&1 )
assert_contains "#710: Spark-Run is projected when SPARK_RUN_ID exists" "Spark-Run: run-42" "$(cat "$gmsg")"
printf 'fix: z\n\nbody\n' > "$gmsg"; gov_hook
case "$(cat "$gmsg")" in *Spark-Run:*) bad "#710: no Spark-Run may be invented without SPARK_RUN_ID" ;; *) ok ;; esac

# 7. an unconfigured / non-Spark repository receives NO fabricated attribution.
printf 'feat: plain\n\nbody\n' > "$gmsg"
( cd "$WORK/proj" && env -u SPARK_GOVERNOR_BIN -u SPARK_ROOT PATH=/usr/bin:/bin bash "$hook" "$gmsg" >/dev/null 2>&1 )
case "$(cat "$gmsg")" in *Spark-Governed-By:*) bad "#710: an ungoverned repo must not be stamped" ;; *) ok ;; esac

# 8. governance provenance SURVIVES while an AI Co-Authored-By is still rejected.
printf 'feat: q\n\nbody\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' > "$gmsg"
arc=0; gov_hook || arc=$?
[ "$arc" -ne 0 ] && ok || bad "#710: an AI co-author must remain rejected even under governance"
printf 'feat: q\n\nbody\n' > "$gmsg"; gov_hook
assert_contains "#710: a clean governed commit is still stamped" "Spark-Governed-By: v0.23.0" "$(cat "$gmsg")"

# CONTROL: the stamp tracks the governor's REPORTED version, not a constant — a
# different governor yields a different stamp, so the value is genuinely resolved.
make_governor "$WORK/gov2" "1.5.0"
printf 'feat: w\n\nbody\n' > "$gmsg"; ( cd "$WORK/proj" && SPARK_GOVERNOR_BIN="$WORK/gov2/bin/spark" bash "$hook" "$gmsg" >/dev/null 2>&1 )
assert_contains "#710 control: the stamp follows the governor's reported version" "Spark-Governed-By: v1.5.0" "$(cat "$gmsg")"

finish
