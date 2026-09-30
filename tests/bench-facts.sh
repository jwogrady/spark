#!/usr/bin/env bash
# Paired snapshot benchmark (#736): journey versus snapshot versus reuse, on ONE
# repository/GitHub state, for one work unit.
#
# Three arms, run back to back so they observe the same state:
#
#   journey   the raw reads an agent makes per round to establish a work unit's
#             current truth without the compiler — one fetch per surface the
#             #730 baseline showed being re-fetched: the record, its comments
#             (every page), its reviews, the check runs at its HEAD, the issue
#             it implements with that issue's children and blockers, the
#             milestone, the standing-authority thread (every page), the
#             repository and the trunk rules. This is the CONTRACT-MINIMAL
#             journey — one read per surface per round — which the measured
#             baseline exceeded (README §2.5), so a saving against it is a
#             floor, not a ceiling.
#   snapshot  `spark facts --issue N` with no stored record: the compiler's
#             own reads, every round. Round 2 repeats round 1 unchanged — this
#             is the "reuse disabled" control.
#   reuse     `spark facts --issue N --delta`: round 1 cold (no record), round 2
#             warm against round 1's record. The compiler still re-reads every
#             source (P4); what the consumer receives shrinks.
#
# Counts, and what they are:
#   gh        invocations of the gh binary, counted by a PATH shim (bench.sh's
#             technique). Here one invocation is one HTTP request BY
#             CONSTRUCTION: the journey pages explicitly (per_page=100&page=k)
#             and the compiler never passes --paginate — so `requests` is
#             exact, not a lower bound. A request made by anything other than
#             gh would be invisible; nothing in either arm makes one.
#   bytes     bytes each arm returned to its consumer on stdout — what an
#             agent would have to read.
#   ms        wall milliseconds per arm-round. Live figures depend on the
#             network and are observational; stub figures are host-dependent.
#   telemetry the compiler's own counters for the snapshot and reuse arms.
#
# The measured boundary INCLUDES the compiler: its API calls and the bytes it
# prints are the snapshot arms' figures; nothing is moved outside the count.
#
# --stub replays fixed GitHub answers through a gh stub (the fixture style of
# tests/test-fact-snapshot.sh) in a throwaway sandbox, so every count is exact
# and reproducible, and adds a third round after a simulated push (a new HEAD)
# — which a merged live PR cannot provide. Without --stub the arms run against
# live GitHub for the work unit named, in this repository.
#
# Fail closed: a read that fails, in any arm, aborts the run with the arm and
# round named; a partial table is never printed as a result.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

unit=""; stub=""; as_json=""; rounds=2
while [ "$#" -gt 0 ]; do
  case "$1" in
    --issue)   shift; unit="${1:-}" ;;
    --issue=*) unit="${1#--issue=}" ;;
    --stub)    stub=1 ;;
    --json)    as_json=1 ;;
    --rounds)  shift; rounds="${1:-2}" ;;
    -h|--help)
      echo "usage: bench-facts.sh --issue <number> [--stub] [--json] [--rounds N]"
      echo "  Paired measurement of journey / snapshot / reuse reads for one work unit."
      echo "  --stub replays fixed GitHub answers in a sandbox (exact, reproducible, adds a post-push round)."
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  if [ "$#" -gt 0 ]; then shift; fi
done
case "$unit" in ''|0|0*|*[!0-9]*) echo "--issue takes a work-unit number" >&2; exit 2 ;; esac
case "$rounds" in ''|0|*[!0-9]*) echo "--rounds takes a positive integer" >&2; exit 2 ;; esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/out"

# --- the gh shim: count every invocation, then run the real (or stub) gh ---
real_gh="$(command -v gh 2>/dev/null || true)"
[ -n "$real_gh" ] || { echo "gh is not on PATH" >&2; exit 2; }
GH_TARGET="$real_gh"

# --- the sandbox and its stub, when replaying ------------------------------
HEAD1="a1b2c3d4e5f60718293a4b5c6d7e8f9012345678"
HEAD2="c1d2e3f4a5b60718293a4b5c6d7e8f9012345678"
BASE="b1c2d3e4f5061728394a5b6c7d8e9f0123456789"
IMPL=734; MS=20
if [ -n "$stub" ]; then
  mkdir -p "$TMP/sb/home"
  cp -r "$root/plugins/spark" "$TMP/sb/plugin"
  SPARK="$TMP/sb/plugin/bin/spark"
  export HOME="$TMP/sb/home" XDG_CONFIG_HOME="$TMP/sb/home/.config" GIT_CONFIG_NOSYSTEM=1
  mkdir -p "$XDG_CONFIG_HOME"
  git config --global user.email "bench@example.invalid"; git config --global user.name "bench"
  git config --global init.defaultBranch master
  mkdir -p "$TMP/sb/proj"; git -C "$TMP/sb/proj" init -q
  ( cd "$TMP/sb/proj" && echo seed > seed.txt && git add . && git commit -qm "chore: seed" )
  git -C "$TMP/sb/proj" remote add origin "git@github.com:jwogrady/spark.git"
  PROJ="$TMP/sb/proj"
  mkdir -p "$PROJ/.spark"
  printf '{\n  "authority.decision_record": "github.com/jwogrady/spark#677/comment/5622552139"\n}\n' > "$PROJ/.spark/preferences.json"
  # Fixtures. Two heads: HEAD1 for rounds 1–2, HEAD2 after the simulated push.
  cat > "$TMP/sb/fixtures.sh" <<'FIX'
BASE="b1c2d3e4f5061728394a5b6c7d8e9f0123456789"
NODE='{"id":123456789,"full_name":"jwogrady/spark","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}'
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"tests"}]}}]'
AUTH_BODY='spark-authority-v1
target github.com/jwogrady/spark
grant merge:routine
boundary release:approve'
AUTH_COMMENT="$(jq -nc --arg body "$AUTH_BODY" '{id:5622552139,updated_at:"2026-09-10T20:00:00Z",user:{login:"jwogrady",type:"User"},author_association:"OWNER",issue_url:"https://api.github.com/repos/jwogrady/spark/issues/677",body:$body,html_url:"https://github.com/jwogrady/spark/issues/677#issuecomment-5622552139"}')"
AUTH_ISSUE='{"number":677,"updated_at":"2026-09-10T20:05:00Z","state":"open","title":"Standing authority"}'
ISSUE_BODY="## Acceptance\n\n- [ ] the one criterion\n"
issue_rest() { jq -nc --arg b "$ISSUE_BODY" '{number:734,state:"open",title:"Expose bounded task snapshots",updated_at:"2026-09-20T10:00:00Z",body:$b,milestone:{number:20},html_url:"https://github.com/jwogrady/spark/issues/734"}'; }
issue_node() { jq -nc '{__typename:"Issue", number:734, updatedAt:"2026-09-20T10:00:00Z", repository:{nameWithOwner:"jwogrady/spark"}, milestone:null, parent:{__typename:"Issue", number:728, state:"OPEN", updatedAt:"2026-09-01T10:00:00Z", repository:{nameWithOwner:"jwogrady/spark"}}, subIssues:{pageInfo:{hasNextPage:false}, nodes:[]}, blockedBy:{pageInfo:{hasNextPage:false}, nodes:[]}}'; }
pr_node() { jq -nc --arg h "$1" --arg b "$BASE" --arg body "$ISSUE_BODY" '{__typename:"PullRequest", number:801, updatedAt:"2026-09-22T10:00:00Z", repository:{nameWithOwner:"jwogrady/spark"}, milestone:null, headRefOid:$h, baseRefName:"master", baseRefOid:$b, baseRef:{target:{oid:$b}}, commits:{nodes:[{commit:{oid:$h, statusCheckRollup:{contexts:{pageInfo:{hasNextPage:false}, nodes:[{__typename:"CheckRun", name:"tests", status:"COMPLETED", conclusion:"SUCCESS", checkSuite:{app:{databaseId:15368}}}]}}}}]}, comments:{pageInfo:{hasPreviousPage:false}, nodes:[]}, closingIssuesReferences:{pageInfo:{hasNextPage:false}, nodes:[{__typename:"Issue", number:734, updatedAt:"2026-09-20T10:00:00Z", repository:{nameWithOwner:"jwogrady/spark"}, body:$body}]}}'; }
pr_rest() { jq -nc --arg h "$1" --arg b "$BASE" '{number:801,state:"open",title:"Emit the complete task snapshot",updated_at:"2026-09-22T10:00:00Z",body:"Refs #734.",head:{sha:$h,ref:"feat/734"},base:{sha:$b,ref:"master"},milestone:null,html_url:"https://github.com/jwogrady/spark/pull/801"}'; }
pr_view() { jq -nc --arg h "$1" '{number:801,headRefOid:$h,baseRefName:"master",state:"OPEN",milestone:null,closingIssuesReferences:[{number:734}]}'; }
COMMENTS_P1="$(jq -nc '[{id:1,updated_at:"2026-09-22T10:01:00Z",user:{login:"jwogrady"},body:"first"},{id:2,updated_at:"2026-09-22T10:02:00Z",user:{login:"github-actions"},body:"<!-- spark-openai-review pr=801 head=x verdict=NOT ASSESSED -->\n## Reviewer verdict: NOT ASSESSED"},{id:3,updated_at:"2026-09-22T10:03:00Z",user:{login:"jwogrady"},body:"third"}]')"
check_runs() { jq -nc --arg h "$1" '{total_count:2,check_runs:[{name:"tests",status:"completed",conclusion:"success",head_sha:$h,app:{id:15368}},{name:"doctor",status:"completed",conclusion:"success",head_sha:$h,app:{id:15368}}]}'; }
MILESTONE='{"number":20,"title":"v0.23 — Never automate inefficiency","state":"open","open_issues":8,"closed_issues":52,"updated_at":"2026-09-29T00:00:00Z"}'
AUTH_PAGE1="$(jq -nc --argjson c "$AUTH_COMMENT" '[$c, {id:9,updated_at:"2026-09-11T00:00:00Z",user:{login:"jwogrady"},body:"orchestration note"}]')"
VIEWER='{"data":{"viewer":{"login":"jwogrady"},"repository":{"viewerPermission":"ADMIN"}}}'
FIX
  # The stub. HEAD is read from a file so the harness can "push" between rounds.
  printf '%s\n' "$HEAD1" > "$TMP/sb/head"
  cat > "$TMP/sb/gh" <<STUB
#!/usr/bin/env bash
GH_JQ=""; __prev=""
for __a in "\$@"; do [ "\$__prev" = "--jq" ] && GH_JQ="\$__a"; __prev="\$__a"; done
answer_json() { if [ -n "\$GH_JQ" ]; then printf '%s' "\$1" | jq -r "\$GH_JQ"; else printf '%s\n' "\$1"; fi; }
. "$TMP/sb/fixtures.sh"
H="\$(cat "$TMP/sb/head")"
case "\$*" in
  *viewerPermission*) answer_json "\$VIEWER" ;;
  *"number=801"*) answer_json '{"data":{"repository":{"issueOrPullRequest":'"\$(pr_node "\$H")"'}}}' ;;
  *"number=734"*) answer_json '{"data":{"repository":{"issueOrPullRequest":'"\$(issue_node)"'}}}' ;;
  *"issues/comments/5622552139"*) answer_json "\$AUTH_COMMENT" ;;
  *"issues/677/comments?per_page=100&page=1"*) answer_json "\$AUTH_PAGE1" ;;
  *"issues/677/comments?per_page=100&page="*) answer_json '[]' ;;
  *"issues/677"*) answer_json "\$AUTH_ISSUE" ;;
  *"rules/branches/"*) answer_json "\$RULES" ;;
  *"pr view 801"*) answer_json "\$(pr_view "\$H")" ;;
  *"pulls/801/reviews"*) answer_json '[]' ;;
  *"pulls/801"*) answer_json "\$(pr_rest "\$H")" ;;
  *"issues/801/comments?per_page=100&page=1"*) answer_json "\$COMMENTS_P1" ;;
  *"issues/801/comments?per_page=100&page="*) answer_json '[]' ;;
  *"issues/734/sub_issues"*) answer_json '[]' ;;
  *"issues/734/dependencies/blocked_by"*) answer_json '[]' ;;
  *"issues/734"*) answer_json "\$(issue_rest)" ;;
  *"check-runs"*) answer_json "\$(check_runs "\$H")" ;;
  *"milestones/20"*) answer_json "\$MILESTONE" ;;
  *"repos/jwogrady/spark"*) answer_json "\$NODE" ;;
  *) echo "stub: no answer for: \$*" >&2; exit 1 ;;
esac
STUB
  chmod +x "$TMP/sb/gh"
  GH_TARGET="$TMP/sb/gh"
  OWNER=jwogrady; REPO=spark
else
  SPARK="$root/plugins/spark/bin/spark"
  PROJ="$root"
  nwo="$("$real_gh" repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || { echo "cannot resolve the repository" >&2; exit 1; }
  OWNER="${nwo%%/*}"; REPO="${nwo##*/}"
fi

# The counting shim shadows gh for every arm.
# One line per invocation: the compiler passes a multi-line GraphQL document as
# one argument, so the arguments are flattened before they are logged, or a
# single call would count as a hundred.
{
  printf '#!/usr/bin/env bash\n'
  printf 'a="$*"; a="${a//$'"'"'\\n'"'"'/ }"; printf "%%s\\n" "$a" >> "$BENCH_COUNT"\n'
  printf 'exec %s "$@"\n' "$GH_TARGET"
} > "$TMP/bin/gh"
chmod +x "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH"

now_ms() {
  local n; n="$(date +%s%N 2>/dev/null)"
  case "$n" in *N*|'') echo "$(( $(date +%s) * 1000 ))" ;; *) echo "$(( n / 1000000 ))" ;; esac
}

# run_counted <arm> <round> <cmd...> — one command of an arm: its stdout is
# appended to the arm-round's bytes file; a failure aborts the whole run.
run_counted() {
  local arm="$1" round="$2"; shift 2
  local outf="$TMP/out/$arm.$round.bytes"
  if ! "$@" >> "$outf" 2>"$TMP/out/err"; then
    echo "bench-facts: $arm round $round: read failed: $* — $(head -c 300 "$TMP/out/err")" >&2
    exit 1
  fi
}

# pages <arm> <round> <path> — every page of a list endpoint, one request each.
pages() {
  local arm="$1" round="$2" path="$3" page=1 n
  while :; do
    local f="$TMP/out/page.json"
    if ! gh api "$path?per_page=100&page=$page" > "$f" 2>"$TMP/out/err"; then
      echo "bench-facts: $arm round $round: read failed: $path page $page — $(head -c 300 "$TMP/out/err")" >&2; exit 1
    fi
    cat "$f" >> "$TMP/out/$arm.$round.bytes"
    n="$(jq 'length' "$f" 2>/dev/null || echo 0)"
    [ "$n" -ge 100 ] || break
    page=$((page + 1))
  done
}

# journey <round> — the contract-minimal raw reads for the work unit.
journey() {
  local round="$1" kind head impl ms
  local view="$TMP/out/view.json"
  # One read to learn what the unit is: the record itself.
  if gh pr view "$unit" --json number,headRefOid,baseRefName,state,milestone,closingIssuesReferences > "$view" 2>/dev/null; then
    kind=pr
    printf '%s\n' "$(cat "$view")" >> "$TMP/out/journey.$round.bytes"
    head="$(jq -r '.headRefOid' "$view")"
    impl="$(jq -r '.closingIssuesReferences[0].number // empty' "$view")"
    ms="$(jq -r '.milestone.number // empty' "$view")"
    run_counted journey "$round" gh api "repos/$OWNER/$REPO/pulls/$unit"
    pages journey "$round" "repos/$OWNER/$REPO/issues/$unit/comments"
    run_counted journey "$round" gh api "repos/$OWNER/$REPO/pulls/$unit/reviews"
    run_counted journey "$round" gh api "repos/$OWNER/$REPO/commits/$head/check-runs"
  else
    kind=issue
    run_counted journey "$round" gh api "repos/$OWNER/$REPO/issues/$unit"
    pages journey "$round" "repos/$OWNER/$REPO/issues/$unit/comments"
    impl="$unit"
    ms="$(jq -r '.milestone.number // empty' "$TMP/out/journey.$round.bytes" 2>/dev/null | head -1)"
  fi
  if [ -n "$impl" ]; then
    [ "$impl" = "$unit" ] || run_counted journey "$round" gh api "repos/$OWNER/$REPO/issues/$impl"
    run_counted journey "$round" gh api "repos/$OWNER/$REPO/issues/$impl/sub_issues"
    run_counted journey "$round" gh api "repos/$OWNER/$REPO/issues/$impl/dependencies/blocked_by"
  fi
  [ -z "$ms" ] || run_counted journey "$round" gh api "repos/$OWNER/$REPO/milestones/$ms"
  [ -n "$ms" ] || [ -z "$stub" ] || run_counted journey "$round" gh api "repos/$OWNER/$REPO/milestones/$MS"
  pages journey "$round" "repos/$OWNER/$REPO/issues/677/comments"
  run_counted journey "$round" gh api "repos/$OWNER/$REPO"
  run_counted journey "$round" gh api "repos/$OWNER/$REPO/rules/branches/master"
}

RUNTAG="bench$$"
snapshot_arm() { # snapshot_arm <arm> <round> <flag...>
  local arm="$1" round="$2"; shift 2
  ( cd "$PROJ" && SPARK_RUN_ID="$RUNTAG-$arm-$round" "$SPARK" facts --issue "$unit" "$@" ) >> "$TMP/out/$arm.$round.bytes" 2>"$TMP/out/err" \
    || { echo "bench-facts: $arm round $round: spark facts failed — $(head -c 300 "$TMP/out/err")" >&2; exit 1; }
  # What the compiler could not establish is evidence too, not noise.
  sed 's/\x1b\[[0-9;]*m//g' "$TMP/out/err" | awk -v a="$arm" -v r="$round" 'NF { print a "\t" r "\t" $0 }' >> "$TMP/out/notes"
}

tel() { # tel <arm> <round> <key>
  ( cd "$PROJ" && "$SPARK" telemetry show --run "$RUNTAG-$1-$2" --json 2>/dev/null ) | jq -r --arg k "$3" '.fields[$k] // "NOT ASSESSED"'
}

measure() { # measure <arm> <round> <fn...>
  local arm="$1" round="$2"; shift 2
  export BENCH_COUNT="$TMP/out/$arm.$round.count"
  : > "$BENCH_COUNT"; : > "$TMP/out/$arm.$round.bytes"
  local s e; s="$(now_ms)"; "$@"; e="$(now_ms)"
  local ghn bytes
  ghn="$(wc -l < "$BENCH_COUNT" | tr -d ' ')"
  bytes="$(wc -c < "$TMP/out/$arm.$round.bytes" | tr -d ' ')"
  printf '%s\t%s\t%s\t%s\t%s\n' "$arm" "$round" "$ghn" "$bytes" "$((e - s))" >> "$TMP/out/rows"
}

: > "$TMP/out/rows"; : > "$TMP/out/notes"
# A clean start for the compiler's record, so "cold" means cold.
rm -rf "$PROJ/.spark/facts"
r=1
# The snapshot arm neither stores nor compares a record, so nothing is wiped
# between its rounds: two identical rounds ARE the reuse-disabled control.
while [ "$r" -le "$rounds" ]; do
  measure journey  "$r" journey "$r"
  measure snapshot "$r" snapshot_arm snapshot "$r"
  r=$((r + 1))
done
rm -rf "$PROJ/.spark/facts"
r=1
while [ "$r" -le "$rounds" ]; do
  measure reuse "$r" snapshot_arm reuse "$r" --delta
  r=$((r + 1))
done
# The simulated push: only the stub can move a HEAD.
if [ -n "$stub" ]; then
  printf '%s\n' "$HEAD2" > "$TMP/sb/head"
  p=$((rounds + 1))
  measure journey  "$p" journey "$p"
  measure snapshot "$p" snapshot_arm snapshot "$p"
  # reuse's record is from round $rounds at HEAD1; this round compares against it.
  measure reuse "$p" snapshot_arm reuse "$p" --delta
fi

mode="live"; [ -z "$stub" ] || mode="stub"
env_line="$(uname -s) $(uname -r) | bash ${BASH_VERSION%%(*}"

# Telemetry for the compiler arms, per round.
telrow() { # telrow <arm> <round>
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" \
    "$(tel "$1" "$2" facts_api_calls)" "$(tel "$1" "$2" facts_output_bytes)" "$(tel "$1" "$2" facts_output_shape)" \
    "$(tel "$1" "$2" facts_changed)" "$(tel "$1" "$2" facts_unchanged)"
}
: > "$TMP/out/tel"
while IFS=$'\t' read -r arm round _ _ _; do
  case "$arm" in snapshot|reuse) telrow "$arm" "$round" >> "$TMP/out/tel" ;; esac
done < "$TMP/out/rows"

# Clean the telemetry this run wrote into a live repository.
if [ -z "$stub" ]; then rm -f "$PROJ"/.spark/telemetry/"$RUNTAG"-* 2>/dev/null; rmdir "$PROJ/.spark/telemetry" 2>/dev/null; rm -rf "$PROJ/.spark/facts"; fi

if [ -n "$as_json" ]; then
  jq -cn --arg mode "$mode" --arg unit "$unit" --arg env "$env_line" --arg rounds "$rounds" \
    --rawfile rows "$TMP/out/rows" --rawfile tel "$TMP/out/tel" --rawfile notes "$TMP/out/notes" '
    def tsv: split("\n") | map(select(length > 0) | split("\t"));
    ($rows | tsv | map({arm: .[0], round: (.[1]|tonumber), requests: (.[2]|tonumber), bytes: (.[3]|tonumber), ms: (.[4]|tonumber)})) as $r
    | ($tel | tsv | map({arm: .[0], round: (.[1]|tonumber), facts_api_calls: .[2], facts_output_bytes: .[3], facts_output_shape: .[4], facts_changed: .[5], facts_unchanged: .[6]})) as $t
    | {mode: $mode, unit: ($unit|tonumber), rounds: ($rounds|tonumber), environment: $env,
       counts_are: {requests: "gh invocations = HTTP requests by construction (explicit paging; the compiler never paginates)",
                    bytes: "bytes returned to the consumer on stdout", ms: (if $mode == "live" then "observational (network)" else "observational (host)" end)},
       boundary: "the compiler'"'"'s API calls and printed bytes are inside the snapshot and reuse arms",
       rows: $r, telemetry: $t, notes: ($notes | tsv | map({arm: .[0], round: (.[1]|tonumber), note: .[2]}))}'
  exit 0
fi

printf 'bench-facts — %s mode, work unit #%s, %s round(s)%s\n' "$mode" "$unit" "$rounds" "$( [ -n "$stub" ] && echo ' + 1 post-push round' )"
printf '%s\n' "requests = gh invocations = HTTP requests by construction; bytes = stdout to the consumer; ms observational"
printf '\n%-9s %-6s %9s %9s %7s\n' arm round requests bytes ms
awk -F'\t' '{ printf "%-9s %-6s %9s %9s %7s\n", $1, $2, $3, $4, $5 }' "$TMP/out/rows"
printf '\n%-9s %-6s %9s %9s %-9s %8s %10s\n' arm round api_calls out_bytes shape changed unchanged
awk -F'\t' '{ printf "%-9s %-6s %9s %9s %-9s %8s %10s\n", $1, $2, $3, $4, $5, $6, $7 }' "$TMP/out/tel"
if [ -s "$TMP/out/notes" ]; then printf '\nnotes\n'; awk -F'\t' '{ printf "  %s round %s: %s\n", $1, $2, $3 }' "$TMP/out/notes"; fi
