#!/usr/bin/env bash
# Behavioural suite for #626 — a read-only assessment must not trust a
# validation command's name.
#
# Dogfooding found a repository whose `validate` ran a build that rewrote a
# TRACKED file. A read-only motion that ran it would have mutated the repository
# it was only supposed to describe — and nothing about the name `validate` gave
# any warning.
#
# So the rule is: project scripts are untrusted with respect to mutation until
# observed otherwise, and the observation happens somewhere disposable. The
# assertions that carry it:
#
#   * a mutating command named `validate` never runs in place, and the source
#     tree is proven unchanged afterwards — tracked content, index, refs AND
#     untracked output, because a build that only leaves untracked artefacts has
#     still changed what the next reader sees;
#   * an observational command named `check` runs normally and is not penalised
#     for the sins of its neighbours;
#   * safety is never inferred from a name — the same command is treated
#     identically whether it is called `validate`, `build` or `lint`;
#   * when isolation cannot be established the answer is NOT ASSESSED with the
#     risk named, never a quiet in-place run;
#   * a genuine failure stays a failure. The rule exists to stop mutation, not
#     to soften a real red result.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "read-only assessment safety (#626)"
sandbox_init
. "$SPARK"

PROJ="$WORK/proj"
make_repo "$PROJ"
printf 'tracked\n' > "$PROJ/data.json"
git -C "$PROJ" add -A
git -C "$PROJ" -c user.email=t@e.com -c user.name=t commit -qm "seed data"

verdict_of() { printf '%s\n' "$1" | awk -F'\t' '$1 == "verdict" { print $2 }'; }
field_of()   { printf '%s\n' "$1" | awk -F'\t' -v k="$2" '$1 == k { print $2 }'; }
reason_of()  { printf '%s\n' "$1" | awk -F'\t' '$1 == "verdict" { print $3 }'; }

snap_before="$(ro_snapshot "$PROJ")"

# --- a mutating command named `validate` -------------------------------------
# The dogfood shape: a build step that rewrites a tracked file.
rc=0
OUT="$(ro_probe "$PROJ" 'printf mutated > data.json')" || rc=$?
[ "$rc" = "0" ] && ok || bad "a mutating command that succeeds is still a PASS (got rc $rc)"
assert_contains "isolation is established"            "established" "$(field_of "$OUT" isolation)"
assert_contains "the command is reported as mutating" "yes"         "$(field_of "$OUT" mutating)"
assert_contains "the source is proven unchanged"      "unchanged"   "$(field_of "$OUT" source)"
assert_contains "and the report says it never ran in place" "never run in place" "$(reason_of "$OUT")"

# The whole point: the tracked file the command rewrote is untouched here.
if [ "$(cat "$PROJ/data.json")" = "tracked" ]; then ok
else bad "a read-only probe must not let the command rewrite the source tracked file"; fi

# --- the snapshot covers more than tracked content ---------------------------
# A build that leaves only untracked output has still changed what the next
# reader observes, so absence of a tracked diff must not be the whole test.
rc=0
OUT="$(ro_probe "$PROJ" 'printf generated > build-output.txt')" || rc=$?
assert_contains "untracked output counts as mutation" "yes" "$(field_of "$OUT" mutating)"
if [ ! -f "$PROJ/build-output.txt" ]; then ok
else bad "untracked build output must not appear in the source tree"; fi

# A command that moves a ref is mutation too.
rc=0
OUT="$(ro_probe "$PROJ" 'git -c user.email=t@e.com -c user.name=t commit -q --allow-empty -m sneaky')" || rc=$?
assert_contains "a commit in isolation leaves the source refs alone" "unchanged" "$(field_of "$OUT" source)"
if [ "$(git -C "$PROJ" rev-list --count HEAD)" = "2" ]; then ok
else bad "the source ref moved during a read-only probe"; fi

# --- an observational command runs normally ----------------------------------
rc=0
OUT="$(ro_probe "$PROJ" 'cat data.json > /dev/null')" || rc=$?
[ "$rc" = "0" ] && ok || bad "an observational command must pass (got rc $rc)"
assert_contains "and is reported as non-mutating" "no" "$(field_of "$OUT" mutating)"
assert_contains "with nothing written"            "wrote nothing" "$(reason_of "$OUT")"

# --- safety is never inferred from the name ----------------------------------
# The same mutating body, under four conventional names, must be treated
# identically. A name allowlist would be the original mistake written down.
for name in validate build lint check; do
  rc=0
  OUT="$(ro_probe "$PROJ" "printf x > $name.out")" || rc=$?
  if [ "$(field_of "$OUT" mutating)" = "yes" ]; then ok
  else bad "a mutating command named '$name' must still be reported as mutating"; fi
  if [ -f "$PROJ/$name.out" ]; then bad "'$name' wrote into the source tree"; else ok; fi
done

# --- a genuine failure stays a failure ---------------------------------------
rc=0
OUT="$(ro_probe "$PROJ" 'exit 7')" || rc=$?
[ "$rc" = "1" ] && ok || bad "a failing command must report FAIL (got rc $rc)"
assert_contains "the verdict is FAIL"          "FAIL" "$(verdict_of "$OUT")"
assert_contains "the exit code is carried"     "exit 7" "$(reason_of "$OUT")"
assert_contains "and it is named a real result" "not a safety refusal" "$(reason_of "$OUT")"

# --- isolation impossible is NOT ASSESSED, never an in-place run -------------
NOGIT="$WORK/plain"
mkdir -p "$NOGIT"
printf 'tracked\n' > "$NOGIT/data.json"
rc=0
OUT="$(ro_probe "$NOGIT" 'printf mutated > data.json')" || rc=$?
[ "$rc" = "3" ] && ok || bad "without isolation the result must be NOT ASSESSED (got rc $rc)"
assert_contains "the verdict is NOT ASSESSED" "NOT ASSESSED" "$(verdict_of "$OUT")"
assert_contains "the risk is named"           "may write tracked files" "$(reason_of "$OUT")"
assert_contains "and the command was not run" "the command was not run" "$(reason_of "$OUT")"
# The decisive assertion: refusing to assess must not mean running it anyway.
if [ "$(cat "$NOGIT/data.json")" = "tracked" ]; then ok
else bad "a NOT ASSESSED probe must not have executed the command in place"; fi

# --- the whole source fingerprint is unchanged across every probe ------------
snap_after="$(ro_snapshot "$PROJ")"
if [ "$snap_before" = "$snap_after" ]; then ok
else bad "the source snapshot changed across the read-only probes ($snap_before -> $snap_after)"; fi

# --- the operator documentation states the hazard ----------------------------
DOC="$repo_root/docs/ops/read-only-assessment.md"
[ -f "$DOC" ] && ok || bad "the read-only hazard must be documented at docs/ops/read-only-assessment.md"
if [ -f "$DOC" ]; then
  assert_contains "and says a validation command may mutate" "mutation-capable" "$(cat "$DOC")"
fi

# --- MUTATION CONTROL --------------------------------------------------------
# Run the command in place instead of in the disposable worktree — the exact
# behaviour the issue reports. The tracked-file fixture must go red.
MUT="$WORK/mutant.sh"
sed 's|( cd "$iso/wt" \&\& eval "$cmd" )|( cd "$root" \&\& eval "$cmd" )|' "$SPARK" > "$MUT"
if ! cmp -s "$SPARK" "$MUT"; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

MPROJ="$WORK/mproj"
make_repo "$MPROJ"
printf 'tracked\n' > "$MPROJ/data.json"
git -C "$MPROJ" add -A
git -C "$MPROJ" -c user.email=t@e.com -c user.name=t commit -qm seed
( . "$MUT"; ro_probe "$MPROJ" 'printf mutated > data.json' >/dev/null 2>&1 ) || true
if [ "$(cat "$MPROJ/data.json")" = "tracked" ]; then
  bad "MUTATION control — the source file survived an in-place run; the fixture does not discriminate"
else ok; fi

finish
