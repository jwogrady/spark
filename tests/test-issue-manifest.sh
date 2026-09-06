#!/usr/bin/env bash
# Offline suite for the plan skill's issue-manifest helper (#214). Exercises
# manifest validation, the deterministic --dry-run call plan, resume-state
# skips, and the live call construction against a stub `gh` that logs every
# invocation — no network, no real gh, no git. The live e2e against GitHub is
# run separately by a human-driven session.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/plugins/spark/skills/plan/scripts/issue-manifest.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

bash -n "$script" && ok || bad "bash -n issue-manifest.sh"

# Source the pure functions (main is source-guarded; nothing runs).
. "$script"

# --- fixtures: a 3-issue slate with 1 subissue + 1 blockedby -----------------
slate="$work/slate"
mkdir -p "$slate/bodies"
printf 'Body A\n' > "$slate/bodies/a.md"
printf 'Body B\n' > "$slate/bodies/b.md"
printf 'Body C\n' > "$slate/bodies/c.md"
{
  printf '# a comment and a blank line are tolerated\n\n'
  printf 'issue\tA\tAdd exporter\tfeature,plan\tv0.15\tbodies/a.md\n'
  printf 'issue\tB\tWire importer\tfeature\tv0.15\tbodies/b.md\n'
  printf 'issue\tC\tDocs pass\t\tv0.15\tbodies/c.md\n'
  printf 'subissue\tA\tB\n'
  printf 'blockedby\tB\t#12\n'
} > "$slate/manifest.tsv"

# --- validation: the good manifest passes, silently ---------------------------
rc=0; out="$(im_validate "$slate/manifest.tsv")" || rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "valid manifest passes validation (rc=$rc: $out)"

# reject <desc> <needle> <manifest-content...> — each rejection case is named.
reject() {
  local desc="$1" needle="$2"; shift 2
  local m="$work/bad.tsv" rc=0 out
  printf '%s\n' "$@" > "$m"
  out="$(im_validate "$m")" || rc=$?
  if [ "$rc" -ne 1 ]; then bad "$desc — want rc 1, got $rc ($out)"; return 0; fi
  case "$out" in
    *"$needle"*) ok ;;
    *) bad "$desc — output lacks '$needle' ($out)" ;;
  esac
}

# accept <desc> <record>... — the mirror of reject: a manifest that must pass
# validation cleanly. Added with #472, which makes several shapes legal that
# were previously refused.
accept() {
  local desc="$1"; shift
  local m="$work/good.tsv" rc=0 out
  printf '%s\n' "$@" > "$m"
  out="$(im_validate "$m")" || rc=$?
  if [ "$rc" -eq 0 ]; then ok; else bad "$desc — want rc 0, got $rc ($out)"; fi
}

T=$'\t'
reject "duplicate KEY" "duplicate KEY 'A'" \
  "issue${T}A${T}One${T}${T}${T}$slate/bodies/a.md" \
  "issue${T}A${T}Two${T}${T}${T}$slate/bodies/b.md"
reject "link ref to undefined KEY" "neither #N nor a KEY" \
  "issue${T}A${T}One${T}${T}${T}$slate/bodies/a.md" \
  "subissue${T}A${T}NOPE"
reject "malformed #N ref" "neither #N nor a KEY" \
  "issue${T}A${T}One${T}${T}${T}$slate/bodies/a.md" \
  "blockedby${T}A${T}#12x"
reject "missing body file" "body file not found" \
  "issue${T}A${T}One${T}${T}${T}bodies/nope.md"
reject "empty body file path" "missing body file path" \
  "issue${T}A${T}One${T}${T}${T}"
reject "empty title" "empty title" \
  "issue${T}A${T}${T}${T}${T}$slate/bodies/a.md"
accept "two milestones in one manifest" \
  "issue${T}A${T}One${T}${T}v0.15${T}$slate/bodies/a.md" \
  "issue${T}B${T}Two${T}${T}v0.16${T}$slate/bodies/b.md"
reject "self-link" "self-link" \
  "issue${T}A${T}One${T}${T}${T}$slate/bodies/a.md" \
  "subissue${T}A${T}A"
reject "duplicate link" "duplicate link" \
  "issue${T}A${T}One${T}${T}${T}$slate/bodies/a.md" \
  "issue${T}B${T}Two${T}${T}${T}$slate/bodies/b.md" \
  "blockedby${T}A${T}B" \
  "blockedby${T}A${T}B"
reject "unknown record type" "unknown record type 'frobnicate'" \
  "frobnicate${T}A${T}B"
reject "wrong field count (issue)" "needs 6 tab-separated fields" \
  "issue${T}A${T}One${T}$slate/bodies/a.md"
reject "wrong field count (link)" "needs 3 tab-separated fields" \
  "issue${T}A${T}One${T}${T}${T}$slate/bodies/a.md" \
  "subissue${T}A"
reject "malformed KEY" "characters outside" \
  "issue${T}a key${T}One${T}${T}${T}$slate/bodies/a.md"
reject "empty KEY" "issue KEY is empty" \
  "issue${T}${T}One${T}${T}${T}$slate/bodies/a.md"

# --- dry-run: exact deterministic call plan for the slate ---------------------
expected="$work/expected-plan.txt"
cat > "$expected" <<EOF
lookup: milestones GET repos/{owner}/{repo}/milestones?state=all&per_page=100 resolve "v0.15"
lookup: labels GET repos/{owner}/{repo}/labels?per_page=100 verify feature,plan
lookup: ids GraphQL issue fullDatabaseId for #12
create: A POST repos/{owner}/{repo}/issues title="Add exporter" labels="feature,plan" milestone="v0.15" body=$slate/bodies/a.md
create: B POST repos/{owner}/{repo}/issues title="Wire importer" labels="feature" milestone="v0.15" body=$slate/bodies/b.md
create: C POST repos/{owner}/{repo}/issues title="Docs pass" labels="" milestone="v0.15" body=$slate/bodies/c.md
wire: subissue A<-B POST repos/{owner}/{repo}/issues/<A.number>/sub_issues -F sub_issue_id=<B.id>
wire: blockedby B<-#12 POST repos/{owner}/{repo}/issues/<B.number>/dependencies/blocked_by -F issue_id=<#12.id>
dry-run: 3 create(s), 2 wire(s); 0 skip(s); no calls made
EOF
rc=0; out="$(bash "$script" --dry-run --state "$work/none.state" "$slate/manifest.tsv")" || rc=$?
if [ "$rc" -eq 0 ] && diff -u "$expected" <(printf '%s\n' "$out") >/dev/null; then ok
else bad "dry-run plan exact match (rc=$rc)"; diff -u "$expected" <(printf '%s\n' "$out") | sed 's/^/    /' || true
fi

# --- resume state: prior landings are skipped, known numbers print literally --
resume="$work/resume"
mkdir -p "$resume"
cp "$slate/bodies/"*.md "$resume/"
{
  printf 'issue\tA\tAdd exporter\tfeature,plan\tv0.15\ta.md\n'
  printf 'issue\tB\tWire importer\tfeature\tv0.15\tb.md\n'
  printf 'issue\tC\tDocs pass\t\tv0.15\tc.md\n'
  printf 'subissue\tA\tB\n'
  printf 'subissue\tA\tC\n'
  printf 'blockedby\tB\t#12\n'
} > "$resume/manifest.tsv"
printf 'created\tA\t37\t9001\nwired\tsubissue\tA\tB\n' > "$resume/prior.state"
rc=0; out="$(bash "$script" --dry-run --state "$resume/prior.state" "$resume/manifest.tsv")" || rc=$?
assert_line() { # desc needle
  case "$out" in *"$2"*) ok ;; *) bad "$1 — output lacks '$2' ($out)" ;; esac
}
[ "$rc" -eq 0 ] && ok || bad "resume dry-run exits 0 (rc=$rc)"
assert_line "created key skipped with = exists"      "skip: A = exists #37 (state)"
assert_line "wired link skipped"                     "skip: subissue A<-B (state)"
assert_line "state-known parent number prints literally" \
  "wire: subissue A<-C POST repos/{owner}/{repo}/issues/37/sub_issues -F sub_issue_id=<C.id>"
assert_line "labels lookup covers only pending creates" "verify feature"$'\n'
assert_line "truthful dry-run tally" "dry-run: 2 create(s), 2 wire(s); 2 skip(s); no calls made"
case "$out" in
  *"create: A "*) bad "skipped key A must not also be planned for creation" ;;
  *) ok ;;
esac
case "$out" in
  *"verify feature,plan"*) bad "labels of skipped issues must not be looked up" ;;
  *) ok ;;
esac

# --- stub gh: live call construction, state writing, resumability -------------
bin="$work/bin"
mkdir -p "$bin"
export GH_CALLS="$work/gh-calls.log" GH_N="$work/gh-n" GH_FAIL="$work/gh-fail"
cat > "$bin/gh" <<'STUB'
#!/usr/bin/env bash
# Test stub: log every invocation, answer with the shapes the helper parses.
echo "$*" >> "$GH_CALLS"
case "$*" in
  *sub_issues*)   exit 0 ;;
  *blocked_by*)   exit 0 ;;
  *graphql*)      printf '12\t9012\n' ;;
  *milestones\?*) printf '5\tv0.15\n' ;;
  *labels\?*)     printf 'feature\nplan\n' ;;
  *"repos/{owner}/{repo}/issues"*)
    if [ -e "$GH_FAIL" ] && [[ "$*" == *"Wire importer"* ]]; then
      echo "HTTP 502: upstream broke (simulated)" >&2
      exit 1
    fi
    n="$(cat "$GH_N" 2>/dev/null || echo 100)"; n=$((n + 1)); echo "$n" > "$GH_N"
    printf '%s\t%s\n' "$n" "$((n + 5000))" ;;
esac
exit 0
STUB
chmod +x "$bin/gh"

live_state="$work/live.state"

# an invalid manifest must reach gh zero times, even in live mode.
printf 'frobnicate\tA\tB\n' > "$work/invalid.tsv"
: > "$GH_CALLS"
rc=0; out="$(PATH="$bin:$PATH" bash "$script" --state "$live_state" "$work/invalid.tsv" 2>&1)" || rc=$?
[ "$rc" -eq 2 ] && ok || bad "invalid manifest live run exits 2 (rc=$rc)"
case "$out" in *"invalid manifest — nothing was created or wired"*) ok ;; *) bad "invalid live run says nothing changed ($out)" ;; esac
[ ! -s "$GH_CALLS" ] && ok || bad "invalid manifest made gh calls: $(cat "$GH_CALLS")"
[ ! -e "$live_state" ] && ok || bad "invalid manifest wrote state"

# a valid --dry-run also makes zero gh calls.
: > "$GH_CALLS"
PATH="$bin:$PATH" bash "$script" --dry-run --state "$live_state" "$slate/manifest.tsv" >/dev/null
[ ! -s "$GH_CALLS" ] && ok || bad "dry-run made gh calls: $(cat "$GH_CALLS")"

# run 1: create B fails mid-slate -> truthful partial report, resumable state.
: > "$GH_CALLS"; : > "$GH_FAIL"
rc=0; out="$(PATH="$bin:$PATH" bash "$script" --state "$live_state" "$slate/manifest.tsv" 2>&1)" || rc=$?
[ "$rc" -eq 1 ] && ok || bad "partial failure exits 1 (rc=$rc: $out)"
case "$out" in *"HTTP 502: upstream broke (simulated)"*) ok ;; *) bad "API error surfaced verbatim ($out)" ;; esac
case "$out" in *"report: created 1, wired 0, skipped 0, failed 1"*) ok ;; *) bad "truthful partial report ($out)" ;; esac
case "$out" in *"resume: fix the cause and rerun the same command"*) ok ;; *) bad "resume guidance present ($out)" ;; esac
[ "$(grep -c '^created' "$live_state")" = "1" ] && ok || bad "state records exactly the one landed create: $(cat "$live_state")"
grep -q "^created	A	101	5101$" "$live_state" && ok || bad "state line format created<TAB>A<TAB>101<TAB>5101: $(cat "$live_state")"

# run 2: rerun resumes — A skipped (never re-created), the rest lands, and the
# call count grows with mutations (4), not lookups (at most 3).
rm -f "$GH_FAIL"; : > "$GH_CALLS"
rc=0; out="$(PATH="$bin:$PATH" bash "$script" --state "$live_state" "$slate/manifest.tsv" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] && ok || bad "resumed run exits 0 (rc=$rc: $out)"
case "$out" in *"skip: A = exists #101 (state)"*) ok ;; *) bad "resumed run reports the skip ($out)" ;; esac
case "$out" in *"report: created 2, wired 2, skipped 1, failed 0"*) ok ;; *) bad "resumed run truthful report ($out)" ;; esac
[ "$(grep -c 'title=Add exporter' "$GH_CALLS")" = "0" ] && ok || bad "A was re-created on resume"
lookups="$(grep -cE 'milestones\?|labels\?|graphql' "$GH_CALLS")" || true
mutations="$(grep -c -- '-X POST' "$GH_CALLS")" || true
[ "$lookups" -eq 3 ] && ok || bad "batched lookups: want 3, got $lookups: $(cat "$GH_CALLS")"
[ "$mutations" -eq 4 ] && ok || bad "mutations: want 4 (2 creates + 2 wires), got $mutations: $(cat "$GH_CALLS")"
# exact wiring calls: numbers from state/creation, ids from creation/GraphQL.
grep -q '^api -X POST repos/{owner}/{repo}/issues/101/sub_issues -F sub_issue_id=5102$' "$GH_CALLS" \
  && ok || bad "sub-issue call shape: $(cat "$GH_CALLS")"
grep -q '^api -X POST repos/{owner}/{repo}/issues/102/dependencies/blocked_by -F issue_id=9012$' "$GH_CALLS" \
  && ok || bad "blocked-by call shape: $(cat "$GH_CALLS")"
# milestone and labels rode the create calls.
grep -q 'title=Wire importer .*-f labels\[\]=feature -F milestone=5' "$GH_CALLS" \
  && ok || bad "create call carries labels and resolved milestone: $(cat "$GH_CALLS")"

# run 3: everything already landed -> all skips, ZERO gh calls.
: > "$GH_CALLS"
rc=0; out="$(PATH="$bin:$PATH" bash "$script" --state "$live_state" "$slate/manifest.tsv" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] && ok || bad "fully-landed rerun exits 0 (rc=$rc: $out)"
case "$out" in *"report: created 0, wired 0, skipped 5, failed 0"*) ok ;; *) bad "fully-landed rerun truthful report ($out)" ;; esac
[ ! -s "$GH_CALLS" ] && ok || bad "fully-landed rerun made gh calls: $(cat "$GH_CALLS")"

# --- duplicate milestone titles must be REJECTED as ambiguous, never resolved
# first-match (hostile M-lane): a second stub serves two milestones sharing the
# manifest's title.
dupbin="$work/dupbin"; mkdir -p "$dupbin"
cat > "$dupbin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *milestones\?*) printf '5\tv0.15\n9\tv0.15\n' ;;
  *labels\?*)     printf 'feature\nplan\n' ;;
esac
exit 0
STUB
chmod +x "$dupbin/gh"
rc=0; out="$(cd "$slate" && PATH="$dupbin:$PATH" bash "$script" --state "$work/dup.state" manifest.tsv 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"share this title"*"ambiguous"*|*ambiguous*) true ;; *) false ;; esac; } \
  && ok || bad "duplicate milestone titles must fail as ambiguous ($rc: $out)"
case "$out" in *"created 0"*) ok ;; *) bad "ambiguous milestone must create nothing ($out)" ;; esac

finish
