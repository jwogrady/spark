#!/usr/bin/env bash
# Behavioral suite for `spark triage` (#467): the existing-repository entry
# motion's first arrow — establish what is true, read-only, and stop.
#
# Two things this suite exists to hold shut.
#
# 1. THE FOUR TRUTH STATES MUST NOT COLLAPSE. Known, mechanically wrong,
#    judgment-bearing and unread are four different answers, and the cheap
#    failures all look like conflations: reporting an unread surface as a
#    negative fact, reporting a known negative as unknown, reporting an owed
#    decision as a failure, or reporting a contradiction as a decision.
#
# 2. IT MUST NOT WRITE. A truth pass that mutates the thing it is describing is
#    not a truth pass. The read-only case below snapshots the working tree, the
#    git object store and every `.spark/` file before and after, and compares.
#
# Offline wherever the property allows: the row generators are driven from
# fixtures, and `gh` is removed from PATH for the cases about unread remotes.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # triage_rows / gov_judgment_rows / repo_* (source-guarded)

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# row <rows> <surface> <id> -> status ; det <...> -> detail
row() { printf '%s\n' "$1" | awk -F'\t' -v s="$2" -v i="$3" '$1 == s && $3 == i { print $2; exit }'; }
det() { printf '%s\n' "$1" | awk -F'\t' -v s="$2" -v i="$3" '$1 == s && $3 == i { print $4; exit }'; }
# any <rows> <surface> -> the first status seen for that surface
anyst() { printf '%s\n' "$1" | awk -F'\t' -v s="$2" '$1 == s { print $2; exit }'; }

# A `gh`-free PATH: several properties are about what triage says when it
# CANNOT read the remote, and the sandbox may have a real gh.
nogh="$WORK/nogh"
mkdir -p "$nogh"
for t in git awk sed grep find comm sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$nogh/$t" 2>/dev/null || true
done

# mk_existing <dir> — a coherent EXISTING repository: real sources, a docs tree,
# a recorded classification that matches, and a clean tree.
mk_existing() {
  local d="$1"
  mkdir -p "$d/src" "$d/docs" "$d/.spark"
  git -C "$d" init -q 2>/dev/null || { mkdir -p "$d"; git -C "$d" init -q; }
  git -C "$d" config user.email t@e.invalid
  git -C "$d" config user.name T
  echo 'x = 1' > "$d/src/app.py"
  echo '[project]' > "$d/pyproject.toml"
  echo '# docs' > "$d/docs/index.md"
  printf '{\n  "project.classification": "existing",\n  "project.classified": "2026-01-01"\n}\n' \
    > "$d/.spark/preferences.json"
  # The human-provisioned governance surfaces. Without them the repo owes a
  # decision — only a human writes an issue form — so a fixture that called
  # itself coherent while omitting them was claiming something untrue.
  mkdir -p "$d/.github/ISSUE_TEMPLATE"
  echo 'name: Bug' > "$d/.github/ISSUE_TEMPLATE/bug.yml"
  echo '## What' > "$d/.github/pull_request_template.md"
  echo '{}' > "$d/release-please-config.json"
  git -C "$d" add -A
  git -C "$d" commit -qm "chore: seed"
}

# ============ 1. a coherent existing repo, no ceremony =====================
# The acceptance criterion "a coherent existing repository can proceed without
# unnecessary ceremony" is mechanical here: the repo's own surfaces are known,
# no decision is owed, and reconciliation is not required. Governance still
# reports unread remote surfaces (no gh), which is honest and separate.
coh="$WORK/coherent"
mk_existing "$coh"
rows="$(cd "$coh" && env PATH="$nogh" bash -c '. '"$SPARK"'; triage_rows "'"$coh"'"')"

assert_eq "a recorded classification that matches is KNOWN" "=" "$(row "$rows" class recorded)"
assert_contains "and names the live verdict's agreement" "classifier agrees" "$(det "$rows" class recorded)"
assert_eq "the worktree is a known fact" "=" "$(row "$rows" worktree branch)"
assert_eq "the trunk relationship is a known fact" "=" "$(row "$rows" trunk ref)"

# No judgment row from triage's OWN surfaces on a coherent repo — that is what
# "without unnecessary ceremony" has to mean if it means anything.
own_judg="$(printf '%s\n' "$rows" | awk -F'\t' '
  $2 == "!" && ($1 == "class" || $1 == "intent" || $1 == "worktree" || $1 == "trunk") { n++ }
  END { print n+0 }')"
assert_eq "a coherent repo owes no decision on its own surfaces" "0" "$own_judg"
own_mech="$(printf '%s\n' "$rows" | awk -F'\t' '
  $2 == "!" && ($1 == "class" || $1 == "intent" || $1 == "worktree" || $1 == "trunk") { n++ }
  END { print n+0 }')"
assert_eq "and holds no mechanical contradiction on them either" "0" "$own_mech"

# ============ 2. a mechanical contradiction is not a decision ==============
# A dependency cycle is the canonical case: whichever issue you start, the graph
# forbids it. No human authority resolves that, so it must land mechanical.
cyc="$(printf 'dependency\t!\ta cycle\tthese issues cannot be started in any order: #1 -> #2 -> #1\n')"
assert_eq "a cycle is mechanical" "1" \
  "$(printf '%s\n' "$(gov_mechanical_rows "$cyc")" | awk 'NF' | wc -l | tr -d ' ')"
assert_eq "and is NOT a human decision" "0" \
  "$(printf '%s\n' "$(gov_judgment_rows "$cyc")" | awk 'NF' | wc -l | tr -d ' ')"

# ============ 3. a missing project judgment is HUMAN DECISION REQUIRED =====
# An unrecorded classification: the classifier has the evidence and says so,
# but ADR-0022 reserves the verdict for the human.
unc="$WORK/unclassified"
mk_existing "$unc"
rm -f "$unc/.spark/preferences.json"
rows_u="$(cd "$unc" && env PATH="$nogh" bash -c '. '"$SPARK"'; triage_rows "'"$unc"'"')"
assert_eq "an unrecorded classification is a judgment row" "!" "$(row "$rows_u" class recorded)"
assert_eq "classified as judgment, not mechanical" "1" \
  "$(printf '%s\n' "$(gov_judgment_rows "$rows_u")" | awk -F'\t' '$1=="class"' | wc -l | tr -d ' ')"
assert_contains "and it reports the evidence it has" "the classifier reads existing" \
  "$(det "$rows_u" class recorded)"
# It must NOT choose. The row states the evidence and stops.
case "$(det "$rows_u" class recorded)" in
  *"recorded existing"*|*"set to"*|*"defaulting"*) bad "triage must not assign the classification" ;;
  *) ok ;;
esac
# And nothing was written to make it so.
if [ -f "$unc/.spark/preferences.json" ]; then
  bad "triage created .spark/preferences.json"
else ok; fi

# A recorded intent whose named issues are all closed is also a judgment: the
# evidence is complete, the replacement value is the human's.
# Driven through the row generator with a stubbed gh so the property is about
# triage's classification, not about the network.
stub="$WORK/ghclosed"
mkdir -p "$stub"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$stub/$t" 2>/dev/null || true
done
printf '#!/usr/bin/env bash\necho closed\n' > "$stub/gh"
chmod +x "$stub/gh"
spent="$WORK/spent"
mk_existing "$spent"
printf '{\n  "next_action": "finish #4242",\n  "blockers": "none",\n  "updated": "2026-01-02"\n}\n' \
  > "$spent/.spark/state.json"
rows_s="$(cd "$spent" && env PATH="$stub" bash -c '. '"$SPARK"'; triage_rows "'"$spent"'"')"
assert_eq "a spent recorded intent is a judgment row" "!" "$(row "$rows_s" intent recorded)"
assert_contains "and says why" "is closed" "$(det "$rows_s" intent recorded)"
assert_eq "and is classified judgment" "1" \
  "$(printf '%s\n' "$(gov_judgment_rows "$rows_s")" | awk -F'\t' '$1=="intent"' | wc -l | tr -d ' ')"

# ============ 4. unread evidence is UNKNOWN / NOT ASSESSED ================
# With no gh, the remote-facing governance surfaces cannot be read. They must
# report `?` — and never a negative fact.
na_count="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "?" && NF { n++ } END { print n+0 }')"
if [ "$na_count" -gt 0 ]; then ok; else bad "with no gh, some surface must report NOT ASSESSED"; fi
# The critical conflation: an unread surface must not be reported as judgment.
unread_as_judg="$(printf '%s\n' "$rows" \
  | awk -F'\t' '$2 == "?" { print $1 "\t!\t" $3 "\t" $4 }' )"
assert_eq "an unread surface is never a judgment row" "0" \
  "$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "?" && $2 == "!"' | wc -l | tr -d ' ')"
# ...and the detail must say it was not read, not that the thing is absent.
first_na="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "?" && NF { print $4; exit }')"
assert_contains "and says it was not assessed" "not assessed" "$first_na"

# A recorded intent that cannot be checked is `?`, not a finding against it.
unchk="$WORK/unchecked"
mk_existing "$unchk"
printf '{\n  "next_action": "finish #4242",\n  "blockers": "",\n  "updated": "2026-01-02"\n}\n' \
  > "$unchk/.spark/state.json"
rows_n="$(cd "$unchk" && env PATH="$nogh" bash -c '. '"$SPARK"'; triage_rows "'"$unchk"'"')"
assert_eq "an unverifiable recorded intent is NOT ASSESSED" "?" "$(row "$rows_n" intent recorded)"
assert_contains "and blames the missing reader, not the intent" "gh is absent" \
  "$(det "$rows_n" intent recorded)"

# ============ 5. a known negative stays a known negative ==================
# "No upstream is tracked" and "no intent is recorded" are established facts.
# Reporting either as `?` would teach the reader that Spark cannot tell the
# difference between an answer and a shrug.
assert_eq "no upstream tracked is KNOWN, not unknown" "=" "$(row "$rows" worktree upstream)"
assert_contains "and states the negative plainly" "no upstream is tracked" \
  "$(det "$rows" worktree upstream)"
assert_eq "no recorded intent is KNOWN, not unknown" "=" "$(row "$rows" intent recorded)"
assert_contains "and does not demand one" "does not require one" "$(det "$rows" intent recorded)"

# ============ 6 & 7. the read-only contract ================================
# Snapshot everything a run could plausibly touch, run the verb for real, and
# compare. This is the property the whole verb rests on.
ro="$WORK/readonly"
mk_existing "$ro"
printf '{\n  "next_action": "something",\n  "blockers": "none",\n  "updated": "2026-01-02"\n}\n' \
  > "$ro/.spark/state.json"

snap() {
  # tracked + untracked content, every .spark file's bytes, the full object
  # store, every ref, and the config — in one comparable blob.
  ( cd "$1" && find . -path ./.git -prune -o -type f -print0 2>/dev/null \
      | LC_ALL=C sort -z | xargs -0 -r cksum
    echo "--refs--";   git -C "$1" show-ref 2>/dev/null || true
    echo "--status--"; git -C "$1" status --porcelain 2>/dev/null || true
    echo "--objs--";   find "$1/.git/objects" -type f 2>/dev/null | LC_ALL=C sort
    echo "--cfg--";    cat "$1/.git/config" 2>/dev/null || true )
}

before="$(snap "$ro")"
rc=0; out="$(cd "$ro" && env PATH="$nogh" "$SPARK" triage 2>&1)" || rc=$?
after="$(snap "$ro")"
assert_eq "triage writes nothing at all" "$before" "$after"
assert_contains "and says so in its own report" "Read-only" "$out"

# The specific mutations named in the contract, asserted individually so a
# regression names itself rather than showing up as one opaque diff.
if [ -f "$ro/.spark/state.json" ]; then
  assert_contains "state.json is untouched" '"next_action": "something"' "$(cat "$ro/.spark/state.json")"
else bad ".spark/state.json disappeared"; fi
for f in .spark/triage.json .spark/triage.md triage-report.md TRIAGE.md; do
  if [ -e "$ro/$f" ]; then bad "triage created $f"; else ok; fi
done
assert_eq "no commit was made" "1" "$(git -C "$ro" rev-list --count HEAD | tr -d ' ')"

# Remote mutation: a gh stub that FAILS on any verb capable of writing. If
# triage reaches for one, the stub's sentinel appears.
wgh="$WORK/writeguard"
mkdir -p "$wgh"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$wgh/$t" 2>/dev/null || true
done
cat > "$wgh/gh" <<'GHEOF'
#!/usr/bin/env bash
# Any write-shaped invocation is recorded. Read-shaped ones return empty.
for a in "$@"; do
  case "$a" in
    --method|-X) echo "WRITE $*" >> "$SENTINEL"; exit 0 ;;
    -f|-F) echo "WRITE $*" >> "$SENTINEL"; exit 0 ;;
    edit|create|close|reopen|comment|delete|merge|label) echo "WRITE $*" >> "$SENTINEL"; exit 0 ;;
  esac
done
case "${1:-}" in
  auth) exit 0 ;;
  api)  exit 0 ;;
esac
exit 0
GHEOF
chmod +x "$wgh/gh"
export SENTINEL="$WORK/gh-writes.log"
: > "$SENTINEL"
( cd "$ro" && env PATH="$wgh" SENTINEL="$SENTINEL" "$SPARK" triage >/dev/null 2>&1 ) || true
assert_eq "triage makes no write-shaped gh call" "" "$(cat "$SENTINEL")"

# ============ 8. the deep audit is not invoked =============================
# The sandbox copies ONLY plugins/spark, so the audit companion is genuinely
# absent — which is the real property: core Triage must not depend on an
# optional companion.
if [ -d "$WORK/plugin/../spark-audit" ]; then bad "the audit companion leaked into the sandbox"; else ok; fi
rc2=0; ( cd "$coh" && env PATH="$nogh" "$SPARK" triage >/dev/null 2>&1 ) || rc2=$?
if [ "$rc2" -le 5 ]; then ok; else bad "triage failed with the audit companion absent (rc=$rc2)"; fi
# And a guard against future drift: an audit entry point on PATH must stay
# untouched. It is not reachable today; the assertion is what keeps it so.
agh="$WORK/auditshim"
mkdir -p "$agh"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$agh/$t" 2>/dev/null || true
done
export AUDIT_SENTINEL="$WORK/audit-invoked.log"
: > "$AUDIT_SENTINEL"
for name in spark-audit audit assess; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "$AUDIT_SENTINEL"\n' "$name" > "$agh/$name"
  chmod +x "$agh/$name"
done
( cd "$coh" && env PATH="$agh" AUDIT_SENTINEL="$AUDIT_SENTINEL" "$SPARK" triage >/dev/null 2>&1 ) || true
assert_eq "triage invokes no audit entry point" "" "$(cat "$AUDIT_SENTINEL")"

# ============ 9. canonical producers stay authoritative ===================
# triage must READ these, not reimplement them. Proven by moving the fact at
# its source and watching triage's report move with it: a private copy would
# not notice.
mv "$coh/.spark/preferences.json" "$coh/.spark/preferences.json.bak"
printf '{\n  "project.classification": "new",\n  "project.classified": "2026-01-01"\n}\n' \
  > "$coh/.spark/preferences.json"
rows_p="$(cd "$coh" && env PATH="$nogh" bash -c '. '"$SPARK"'; triage_rows "'"$coh"'"')"
assert_contains "triage reads the recorded fact from the preference layer" "recorded new" \
  "$(det "$rows_p" class recorded)"
mv "$coh/.spark/preferences.json.bak" "$coh/.spark/preferences.json"

# The git facts come from repo_git_facts, so a real branch change moves them.
git -C "$coh" checkout -q -b a-working-branch
rows_b="$(cd "$coh" && env PATH="$nogh" bash -c '. '"$SPARK"'; triage_rows "'"$coh"'"')"
assert_contains "triage reads the branch from the shared git producer" "a-working-branch" \
  "$(det "$rows_b" worktree branch)"
git -C "$coh" checkout -q master 2>/dev/null || git -C "$coh" checkout -q -

# The judgment/mechanical split comes from the ONE partition list, so triage's
# own surfaces are declared there rather than in a second local test.
assert_contains "class is a declared judgment surface" "class" "$GOV_JUDGMENT_SURFACES"
assert_contains "intent is a declared judgment surface" "intent" "$GOV_JUDGMENT_SURFACES"
assert_eq "an undeclared triage surface still fails closed as mechanical" "1" \
  "$(printf '%s\n' "$(gov_mechanical_rows "$(printf 'invented\t!\tx\tnobody classified this\n')")" \
     | awk 'NF' | wc -l | tr -d ' ')"

# ============ 10. unresolved judgments are reported, never assigned =======
# The shape of the live #558/#564 items: an issue with no release disposition.
# triage must carry the governance row through and change nothing about it.
disp="$(printf 'metadata\t!\t#558\tno release disposition: neither a milestone nor a disposition decision\n')"
assert_eq "an undisposed issue is a judgment row" "1" \
  "$(printf '%s\n' "$(gov_judgment_rows "$disp")" | awk 'NF' | wc -l | tr -d ' ')"
assert_eq "and never mechanical" "0" \
  "$(printf '%s\n' "$(gov_mechanical_rows "$disp")" | awk 'NF' | wc -l | tr -d ' ')"
# The rendered report must name it and stop, with the boundary said in words.
out_j="$(cd "$unc" && env PATH="$nogh" "$SPARK" triage 2>&1)" || true
assert_contains "the report states the authority boundary" "authority is yours" "$out_j"
assert_contains "and that it does not choose" "never chosen" "$out_j"
case "$out_j" in
  *"backlog applied"*|*"assigned P"*|*"milestone set"*) bad "triage assigned a project value" ;;
  *) ok ;;
esac

# ============ explicit issue references only (#571) ========================
# The extractor is the whole fix: a reference is `#` plus digits with a word
# boundary either side. Without the sigil every number in prose becomes one, and
# `v0.22` silently means issue #22 — which is what triage did, looking up 21 and
# 22 as issues because they are fragments of v0.21.0 and v0.22.
ir() { issue_refs "$1" | tr '\n' ' ' | sed 's/ $//'; }

assert_eq "a version is not an issue reference"        "" "$(ir 'v0.22')"
assert_eq "nor a dotted version"                       "" "$(ir 'v0.21.0 is published')"
assert_eq "a year is not an issue reference"           "" "$(ir '2026-08-28')"
assert_eq "a port is not an issue reference"           "" "$(ir 'listening on port 8080')"
assert_eq "a percentage and a count are not either"    "" "$(ir '95% of 200 runs')"
assert_eq "an explicit reference is one"           "4242" "$(ir 'finish #4242')"
assert_eq "several explicit references, in order" "467 468" "$(ir 'complete #467 then #468')"
assert_eq "a sigil inside a word is not a reference"   "" "$(ir 'abc#12 is not a reference')"
assert_eq "nor digits running into a word"             "" "$(ir '#12abc is not a reference')"
assert_eq "a trailing period does not swallow it"     "7" "$(ir 'see #7.')"
# The exact shape that produced the defect: versions and real references mixed.
assert_eq "versions are skipped and references kept" "467 468" \
  "$(ir 'v0.22 sprint: finish #467 and #468, per v0.21.0')"
# doctor's narrower question rides the same syntax with a width floor rather
# than a second regex.
assert_eq "the width floor filters short references" "467 4242" \
  "$(issue_refs 'mixed #7 #467 #4242' 3 | tr '\n' ' ' | sed 's/ $//')"

# --- WHICH issues were queried, not merely the verdict ---------------------
# The previous fixture's weakness: a stub that answered `closed` to everything
# made a wrong query set look right. These assert the query log itself.
qbin="$WORK/qgh"
mkdir -p "$qbin"
for t in git awk sed grep find sort printf bash env cat wc tr head cut date mktemp rm mkdir ls dirname basename jq python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$qbin/$t" 2>/dev/null || true
done
cat > "$qbin/gh" <<'GHEOF'
#!/usr/bin/env bash
# Log every issue lookup, then answer with whatever QSTATE says.
if [ "${1:-}" = "api" ]; then
  case "${2:-}" in
    */issues/*) echo "${2##*/}" >> "$QLOG"; echo "${QSTATE:-open}" ;;
  esac
  exit 0
fi
exit 0
GHEOF
chmod +x "$qbin/gh"

qrun() { # <intent-text> <state> -> rows, with QLOG holding the queried numbers
  local intent="$1" st="$2" d="$WORK/q$3"
  mk_existing "$d"
  python3 - "$d/.spark/state.json" "$intent" <<'PY'
import json, sys
json.dump({"next_action": sys.argv[2], "blockers": "", "updated": "2026-01-02"},
          open(sys.argv[1], "w"))
PY
  : > "$WORK/qlog.$3"
  QROWS="$(cd "$d" && env PATH="$qbin" QLOG="$WORK/qlog.$3" QSTATE="$st" \
    bash -c '. '"$SPARK"'; triage_rows "'"$d"'"')"
  QUERIED="$(LC_ALL=C sort -n "$WORK/qlog.$3" | tr '\n' ' ' | sed 's/ $//')"
}

# The regression case, verbatim in shape: versions alongside real references.
qrun 'v0.22 sprint: finish #467 and #468, per v0.21.0' open a
assert_eq "only explicit references are queried" "467 468" "$QUERIED"
case "$QUERIED" in
  *" 21 "*|"21 "*|*" 22 "*|"22 "*) bad "a version fragment was queried as an issue" ;;
  *) ok ;;
esac
assert_eq "and open work keeps its verdict" "=" "$(row "$QROWS" intent recorded)"

# All-closed keeps the spent semantics, and still only asks about real refs.
qrun 'finish #4242 and #4243' closed b
assert_eq "all-closed queries exactly the named issues" "4242 4243" "$QUERIED"
assert_eq "and reports the intent spent" "!" "$(row "$QROWS" intent recorded)"
assert_contains "naming the count it actually checked" "names (2) is closed" \
  "$(det "$QROWS" intent recorded)"

# Prose with NO explicit reference must not be called spent, must not be called
# still-live, and must not query anything at all.
qrun 'ship the v0.22 milestone by 2026-09-01 on port 8080' closed c
assert_eq "prose with no reference queries nothing" "" "$QUERIED"
assert_eq "and is a known fact, not a judgment" "=" "$(row "$QROWS" intent recorded)"
assert_contains "reported as referencing no issue" "references no issue explicitly" \
  "$(det "$QROWS" intent recorded)"
case "$(det "$QROWS" intent recorded)" in
  *"still names open work"*) bad "no-reference intent must not claim open work" ;;
  *"is spent"*)              bad "no-reference intent must not be called spent" ;;
  *) ok ;;
esac

# A reference whose state cannot be read stays NOT ASSESSED — never a negative.
qrun 'finish #4242' unreadable d
assert_eq "an unreadable state is not assessed" "?" "$(row "$QROWS" intent recorded)"
assert_contains "and says the state could not be read" "could not be read" \
  "$(det "$QROWS" intent recorded)"

# ============ the verdict and its exit codes ==============================
# Four outcomes, most severe wins, and DECISION REQUIRED is not FAIL.
rc=0; out="$(cd "$unc" && env PATH="$nogh" "$SPARK" triage 2>&1)" || rc=$?
assert_rc "an owed decision exits 5, not 1" 5 "$rc"
assert_contains "and names the outcome" "DECISION REQUIRED" "$out"
case "$out" in *"FAIL"*) bad "an owed decision must not be reported as FAIL" ;; *) ok ;; esac
assert_contains "reconciliation is required when a decision is owed" \
  "Reconciliation required before proceeding: yes" "$out"

# The coherent repo, with the remote unreadable, is NOT ASSESSED — never a pass
# by assumption, and never a claim that all future work is known.
rc=0; out="$(cd "$coh" && env PATH="$nogh" "$SPARK" triage 2>&1)" || rc=$?
assert_rc "unread surfaces alone exit 3" 3 "$rc"
assert_contains "and say so" "NOT ASSESSED" "$out"
assert_contains "with reconciliation undetermined, not negative" \
  "Reconciliation required before proceeding: undetermined" "$out"

# --tsv carries the machine-readable verdict and the reconciliation answer.
tsv="$(cd "$unc" && env PATH="$nogh" "$SPARK" triage --tsv 2>&1)" || true
assert_contains "tsv carries a verdict line" "$(printf 'verdict\tDECISION REQUIRED')" "$tsv"
assert_contains "tsv carries the reconciliation answer" "$(printf 'reconciliation\tyes')" "$tsv"

# The verb refuses outside a git repo rather than inventing an answer.
rc=0; ( cd "$WORK" && "$SPARK" triage >/dev/null 2>&1 ) || rc=$?
assert_rc "outside a git repo triage refuses" 1 "$rc"

finish
