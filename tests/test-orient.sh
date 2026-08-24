#!/usr/bin/env bash
# Behavioral tests for spark orient (issue #183): the three-band verdict per
# repo shape, the inspect-only guarantee (nothing written before --set), the
# create-only recording of the classification fact, a sane re-set, and the
# graceful skip when no JSON parser is available.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# verdict <dir> — the classifier's one-word verdict for a fixture, read from
# the Verdict section of `spark orient` run inside the directory.
verdict() {
  ( cd "$1" && "$SPARK" orient 2>/dev/null ) | awk '$1=="classification"{print $2}'
}

# --- one verdict per fixture shape
d="$WORK/clean"; fixture_clean_dir "$d"
v="$(verdict "$d")"; [ "$v" = "new" ] && ok || bad "clean dir: want new, got '$v'"

d="$WORK/emptygit"; fixture_empty_git "$d"
v="$(verdict "$d")"; [ "$v" = "new" ] && ok || bad "empty git repo: want new, got '$v'"

d="$WORK/mature"; fixture_mature_repo "$d"
v="$(verdict "$d")"; [ "$v" = "existing" ] && ok || bad "mature repo: want existing, got '$v'"

d="$WORK/imported"; fixture_imported_repo "$d"
v="$(verdict "$d")"; [ "$v" = "existing" ] && ok || bad "imported repo: want existing, got '$v'"

d="$WORK/ambig"; fixture_ambiguous_repo "$d"
v="$(verdict "$d")"; [ "$v" = "ambiguous" ] && ok || bad "ambiguous repo: want ambiguous, got '$v'"

# --- #242: unversioned source nested below the old depth-2 cutoff is still
# real content — ambiguous (stop and ask), never a high-confidence "new".
d="$WORK/nested-src"; mkdir -p "$d/src/app"
printf 'print("existing app")\n' > "$d/src/app/main.py"
v="$(verdict "$d")"; [ "$v" = "ambiguous" ] && ok || bad "#242 nested source: want ambiguous, got '$v'"
( cd "$d" && "$SPARK" orient ) >/dev/null 2>&1
[ ! -e "$d/.spark" ] && ok || bad "#242 nested-source orient wrote state (must stay read-only)"

# --- #242: a vendored/build tree alone must not establish a project — those
# dirs are pruned, so an empty scratch dir with only node_modules reads as new.
d="$WORK/vendored"; mkdir -p "$d/node_modules/pkg" "$d/dist"
printf 'x\n' > "$d/node_modules/pkg/index.js"; printf 'y\n' > "$d/dist/bundle.js"
v="$(verdict "$d")"; [ "$v" = "new" ] && ok || bad "#242 vendored-only: want new (pruned), got '$v'"

# confidence <dir> — the classifier's confidence word for a fixture.
confidence() {
  ( cd "$1" && "$SPARK" orient 2>/dev/null ) \
    | awk '$1=="classification"{gsub(/[()]/,"",$3); print $3}'
}

# --- #398: a README is present in virtually every repository — GitHub writes
# one at `repo create` — so it establishes nothing. A greenfield repo whose
# only tracked file is a README must not read as a high-confidence "existing"
# project, because that verdict instructs onboard to skip profile selection
# and the operator then has to override it by hand.
d="$WORK/readme-only"; mkdir -p "$d"; git -C "$d" init -q
echo "# proj" > "$d/README.md"
( cd "$d" && git add . && git commit -qm "chore: initial commit" ) >/dev/null 2>&1
v="$(verdict "$d")"; [ "$v" = "ambiguous" ] && ok || bad "#398 lone README: want ambiguous, got '$v'"
out="$(cd "$d" && "$SPARK" orient 2>&1)"
assert_contains "#398 evidence says the README was not counted" "not counted" "$out"
assert_contains "#398 evidence publishes the source-file count" "source" "$out"
[ ! -e "$d/.spark" ] && ok || bad "#398 orient wrote state (must stay read-only)"

# The same repo plus the boilerplate a repo is *created* with is still not a
# project — LICENSE and .gitignore establish no more than the README does.
d="$WORK/boilerplate"; mkdir -p "$d"; git -C "$d" init -q
echo "# proj" > "$d/README.md"; echo "MIT" > "$d/LICENSE"; echo "*.log" > "$d/.gitignore"
( cd "$d" && git add . && git commit -qm "chore: initial commit" ) >/dev/null 2>&1
v="$(verdict "$d")"; [ "$v" = "ambiguous" ] && ok || bad "#398 boilerplate-only: want ambiguous, got '$v'"

# One real source file is content, so the verdict becomes existing — but with
# no manifest, CI, docs tree, or contract it is thin, and must say so.
d="$WORK/thin-src"; mkdir -p "$d"; git -C "$d" init -q
echo "# proj" > "$d/README.md"; echo "echo hi" > "$d/run.sh"
( cd "$d" && git add . && git commit -qm "chore: initial commit" ) >/dev/null 2>&1
v="$(verdict "$d")"; [ "$v" = "existing" ] && ok || bad "#398 thin source: want existing, got '$v'"
c="$(confidence "$d")"; [ "$c" = "medium" ] && ok || bad "#398 thin source: want medium confidence, got '$c'"

# A deliberate docs/ tree is somebody's act, unlike a README, so it still
# counts as a content signal.
d="$WORK/docs-tree"; mkdir -p "$d/docs"; git -C "$d" init -q
echo "# proj" > "$d/README.md"; echo "# guide" > "$d/docs/guide.md"
( cd "$d" && git add . && git commit -qm "chore: initial commit" ) >/dev/null 2>&1
v="$(verdict "$d")"; [ "$v" = "existing" ] && ok || bad "#398 docs tree: want existing, got '$v'"

# A genuinely established project is unaffected: full evidence still reads high.
c="$(confidence "$WORK/mature")"; [ "$c" = "high" ] && ok || bad "#398 mature repo: want high confidence, got '$c'"

# --- the report names its evidence and confidence (acceptance criteria)
out="$(cd "$WORK/mature" && "$SPARK" orient 2>&1)"
assert_contains "report shows evidence" "Evidence" "$out"
assert_contains "report shows confidence" "confidence" "$out"

# --- inspect-only: a bare run writes nothing, even in a repo with no state
d="$WORK/inspect"; fixture_empty_git "$d"
( cd "$d" && "$SPARK" orient ) >/dev/null 2>&1
[ ! -e "$d/.spark" ] && ok || bad "orient created .spark without --set"

d="$WORK/mature"  # a fully-committed tree: orient must leave it clean
before="$(git -C "$d" status --porcelain)"
( cd "$d" && "$SPARK" orient ) >/dev/null 2>&1
[ "$before" = "$(git -C "$d" status --porcelain)" ] && ok || bad "orient dirtied a mature repo"

# --- --set records the fact create-only
d="$WORK/setrec"; make_repo "$d"
rc=0; ( cd "$d" && "$SPARK" orient --set existing ) >/dev/null 2>&1 || rc=$?
assert_rc "orient --set exits 0" 0 "$rc"
[ -f "$d/.spark/preferences.json" ] && ok || bad "--set did not create preferences.json"
jq empty "$d/.spark/preferences.json" 2>/dev/null && ok || bad "recorded preferences.json is not valid JSON"
prefs="$(cat "$d/.spark/preferences.json")"
assert_contains "records the classification key" "project.classification" "$prefs"
assert_contains "records the classification value" "existing" "$prefs"
assert_contains "records the classified date" "project.classified" "$prefs"

# --- --set merges without clobbering an existing committed fact
d="$WORK/setmerge"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"permissions.preset":"conservative"}\n' > "$d/.spark/preferences.json"
( cd "$d" && "$SPARK" orient --set new ) >/dev/null 2>&1
merged="$(cat "$d/.spark/preferences.json")"
assert_contains "existing project fact survives" "conservative" "$merged"
assert_contains "classification is added" "project.classification" "$merged"

# --- re-set behaves sanely: same value is a no-op, a different value applies
rc=0; out="$(cd "$d" && "$SPARK" orient --set new 2>&1)" || rc=$?
assert_rc "same-value re-set exits 0" 0 "$rc"
assert_contains "same-value re-set is a no-op" "already recorded" "$out"

rc=0; out="$(cd "$d" && "$SPARK" orient --set existing 2>&1)" || rc=$?
assert_rc "changed re-set exits 0" 0 "$rc"
assert_contains "changed re-set is called explicit" "re-set" "$out"
after="$(cat "$d/.spark/preferences.json")"
case "$after" in *'"project.classification": "existing"'*) ok ;; *) bad "changed re-set not applied: $after" ;; esac

# --- invalid classification is rejected, nothing written
d="$WORK/setbad"; make_repo "$d"
rc=0; out="$(cd "$d" && "$SPARK" orient --set bogus 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "invalid --set value should fail"; fi
assert_contains "names the bad value" "invalid classification" "$out"
[ ! -e "$d/.spark" ] && ok || bad "invalid --set still wrote state"

# --- no jq and no python3: --set into an existing file degrades gracefully
shim="$WORK/oshim"; mkdir -p "$shim"
for tool in bash sh git grep sed cat cp mv rm mkdir mktemp basename dirname tr find sort head tail date env uname readlink awk cut wc ls chmod touch; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$src" ] && ln -s "$src" "$shim/$tool"
done
d="$WORK/noparser"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"permissions.preset":"delivery"}\n' > "$d/.spark/preferences.json"
before="$(cat "$d/.spark/preferences.json")"
rc=0; out="$(cd "$d" && env PATH="$shim" "$SPARK" orient --set new 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "no-parser --set should return non-zero"; fi
assert_contains "points at a manual edit" "by hand" "$out"
[ "$before" = "$(cat "$d/.spark/preferences.json")" ] && ok || bad "no-parser --set modified the file"

finish
