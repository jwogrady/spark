#!/usr/bin/env bash
# Behavioural suite for snapshot-first consumption (#735): the policy data,
# the page that renders it, and the drill-down `spark facts --explain`.
#
# The things a happy-path check would miss:
#
#   * a drill-down without a reason, with a reason outside the vocabulary, or
#     with a key the model does not declare, reads nothing at all; one whose
#     reason does not apply to the fact's status never reads the source;
#   * the record fetched is the node the fact's SOURCE names, so an audit of
#     authority reaches the decision comment and not the work unit;
#   * every drill-down is on the run's log, and the count derives from the
#     log — a later invocation cannot overwrite it low;
#   * the page renders every policy and every reason the data declares.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "fact consumption (#735)"
sandbox_init

POLICY="$WORK/plugin/preferences/fact-consumption.tsv"
DOC="$WORK/plugin/docs/reference/fact-consumption.md"
rec() { awk -F'\t' -v k="$1" '$1 == k' "$POLICY"; }

# --- the data and the page ----------------------------------------------------
[ -f "$POLICY" ] && ok || bad "preferences/fact-consumption.tsv is shipped"
[ -f "$DOC" ] && ok || bad "reference/fact-consumption.md is shipped"
assert_eq "the policy declares its version" "1" "$(rec version | cut -f2)"
assert_eq "written against fact-model schema 1" "1" "$(rec schema | cut -f2)"
[ "$(rec policy | wc -l)" -ge 7 ] && ok || bad "at least the seven consumption rules are declared"
for id in $(rec policy | cut -f2); do grep -q "^| \`$id\` |" "$DOC" && ok || bad "the page renders policy $id"; done
for r in $(rec reason | cut -f2); do grep -q "^| \`$r\` |" "$DOC" && ok || bad "the page renders reason $r"; done
assert_eq "every reason names the status it applies to, or any" "" \
  "$(rec reason | awk -F'\t' '$3 !~ /^(ESTABLISHED|UNKNOWN|CONFLICT|NOT_APPLICABLE|any)$/ {print $2}' | tr '\n' ' ')"
assert_eq "reason tokens are lower-case words" "" "$(rec reason | cut -f2 | grep -vE '^[a-z][a-z-]*$' | tr '\n' ' ')"
grep -q 'snapshot first' "$DOC" && ok || bad "the page states the policy's name"

# --- the drill-down -----------------------------------------------------------
make_repo "$WORK/proj"
git -C "$WORK/proj" remote add origin "git@github.com:jwogrady/Spark.git"
cd "$WORK/proj"
mkdir -p "$WORK/bin"
export GH_CALL_LOG="$WORK/gh.calls"
export PATH="$WORK/bin:$PATH"
cat > "$WORK/bin/date" <<'SH'
#!/usr/bin/env bash
echo "2026-09-29T12:00:00Z"
SH
chmod +x "$WORK/bin/date"
mkdir -p .spark
cat > .spark/preferences.json <<'JSON'
{ "authority.decision_record": "github.com/jwogrady/spark#677/comment/5622552139" }
JSON
NODE='{"id":123456789,"full_name":"jwogrady/spark","default_branch":"master","updated_at":"2026-09-07T21:00:00Z","description":"the repository record"}'
AUTH_BODY='spark-authority-v1
target github.com/jwogrady/spark
grant merge:routine
boundary release:approve'
AUTH_COMMENT="$(jq -nc --arg body "$AUTH_BODY" '{id:5622552139,updated_at:"2026-09-10T20:00:00Z",user:{login:"jwogrady",type:"User"},author_association:"OWNER",issue_url:"https://api.github.com/repos/jwogrady/spark/issues/677",body:$body}')"
AUTH_ISSUE='{"number":677,"updated_at":"2026-09-10T20:05:00Z","title":"standing authority"}'
ISSUE_734='{"number":734,"state":"open","title":"the work unit record","body":"## Acceptance\n\n- [ ] one\n"}'
UNIT="$(jq -nc '{__typename:"Issue", number:734, updatedAt:"2026-09-20T10:00:00Z",
  repository:{nameWithOwner:"jwogrady/spark"}, milestone:null, parent:null,
  subIssues:{pageInfo:{hasNextPage:false}, nodes:[]}, blockedBy:{pageInfo:{hasNextPage:false}, nodes:[]}}')"
VIEWER='{"data":{"viewer":{"login":"jwogrady"},"repository":{"viewerPermission":"ADMIN"}}}'
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *viewerPermission*) answer_json '$VIEWER' ;;
  *issueOrPullRequest*) answer_json '{"data":{"repository":{"issueOrPullRequest":$UNIT}}}' ;;
  *"repos/jwogrady/spark/issues/comments/5622552139"*) answer_json '$AUTH_COMMENT' ;;
  *"repos/jwogrady/spark/issues/677"*) answer_json '$AUTH_ISSUE' ;;
  *"repos/jwogrady/spark/issues/734"*) answer_json '$ISSUE_734' ;;
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
record_reads() { command grep -cE 'repos/jwogrady/spark/issues/(734|677|comments)' "$GH_CALL_LOG" || true; }

# Refusals read nothing.
: > "$GH_CALL_LOG"
assert_eq "a drill-down without a reason is refused" "1" \
  "$("$SPARK" facts --issue 734 --explain authority.standing >/dev/null 2>&1; echo $?)"
assert_eq "a reason outside the vocabulary is refused" "1" \
  "$("$SPARK" facts --issue 734 --explain authority.standing --because vibes >/dev/null 2>&1; echo $?)"
assert_eq "--because without --explain is refused" "1" \
  "$("$SPARK" facts --issue 734 --because audit >/dev/null 2>&1; echo $?)"
assert_eq "--explain with --delta is refused" "1" \
  "$("$SPARK" facts --issue 734 --delta --explain authority.standing --because audit >/dev/null 2>&1; echo $?)"
assert_eq "and none of those reached GitHub" "0" "$(command grep -c . "$GH_CALL_LOG" || true)"
ERR="$("$SPARK" facts --issue 734 --explain authority.standing --because vibes 2>&1 >/dev/null || true)"
assert_contains "the refusal lists the vocabulary" "unknown, conflict, audit" "$ERR"

# A key the model does not declare is refused by name before the compile
# spends a read; a reason with a required status is refused for a fact in
# another status, after the compile and without a read of the source.
: > "$GH_CALL_LOG"
assert_eq "an unknown key is refused" "1" \
  "$("$SPARK" facts --issue 734 --explain review.cached --because audit >/dev/null 2>&1; echo $?)"
assert_contains "naming the keys that exist" "authority.standing" \
  "$("$SPARK" facts --issue 734 --explain review.cached --because audit 2>&1 >/dev/null || true)"
assert_eq "and an unknown key reached GitHub for nothing" "0" "$(command grep -c . "$GH_CALL_LOG" || true)"
: > "$GH_CALL_LOG"
assert_eq "reason unknown does not apply to an ESTABLISHED fact" "1" \
  "$("$SPARK" facts --issue 734 --explain authority.standing --because unknown >/dev/null 2>&1; echo $?)"
assert_eq "a status refusal read the comment for the compile only, never as the source" "1" \
  "$(command grep -c 'repos/jwogrady/spark/issues/comments/5622552139' "$GH_CALL_LOG" || true)"
assert_eq "reason unknown applies to an UNKNOWN fact" "0" \
  "$("$SPARK" facts --issue 734 --explain placement.current --because unknown >/dev/null 2>&1; echo $?)"

# The record is the node the SOURCE names.
: > "$GH_CALL_LOG"
E="$(SPARK_RUN_ID=rexp "$SPARK" facts --issue 734 --explain authority.standing --because audit 2>/dev/null)"
assert_eq "the output is an explain object, never a snapshot shape (R22)" "explain" "$(printf '%s' "$E" | jq -r 'keys | join(",")')"
assert_eq "it carries the fact's key, status and reason" "authority.standing|ESTABLISHED|audit" \
  "$(printf '%s' "$E" | jq -r '.explain | "\(.key)|\(.status)|\(.because)"')"
assert_eq "its provenance and source are the fact's" "https://github.com/jwogrady/spark/issues/677#issuecomment-5622552139|human-decision" \
  "$(printf '%s' "$E" | jq -r '.explain | "\(.provenance)|\(.source.type)"')"
assert_eq "and the record is the decision comment, fetched now" "5622552139|OWNER" \
  "$(printf '%s' "$E" | jq -r '.explain.record | "\(.id)|\(.author_association)"')"
# The compile read the comment once for its fields; the drill-down read it
# again, whole, for the stated reason — two reads of one node, the second the
# explicit developer-journey read the policy bounds and counts.
assert_eq "the drill-down is one more read of the comment endpoint" "2" \
  "$(command grep -c 'repos/jwogrady/spark/issues/comments/5622552139' "$GH_CALL_LOG" || true)"

E2="$(SPARK_RUN_ID=rexp "$SPARK" facts --issue 734 --explain work_unit.identity --because explanation 2>/dev/null)"
assert_eq "a work-unit-sourced fact fetches the issue record" "734|the work unit record" \
  "$(printf '%s' "$E2" | jq -r '.explain.record | "\(.number)|\(.title)"')"
E3="$(SPARK_RUN_ID=rexp "$SPARK" facts --issue 734 --explain repository.identity --because audit 2>/dev/null)"
assert_eq "a repository-sourced fact fetches the repository record" "the repository record" \
  "$(printf '%s' "$E3" | jq -r '.explain.record.description')"
E4="$(SPARK_RUN_ID=rexp "$SPARK" facts --issue 734 --explain next_action.governed --because explanation 2>/dev/null)"
assert_eq "a derived fact has no record; its inputs are the record" "null|true" \
  "$(printf '%s' "$E4" | jq -r '.explain | "\(.record)|\(.inputs | type == "array")"')"

# Observability: the log, and the count derived from it.
assert_eq "every drill-down is on the run's log with its reason and key" \
  "audit	authority.standing
explanation	work_unit.identity
audit	repository.identity
explanation	next_action.governed" \
  "$(cut -f1,2 .spark/telemetry/rexp.drilldowns)"
TEL="$("$SPARK" telemetry show --run rexp --json)"
assert_contains "the run reports the drill-down count from the log" '"facts_drilldowns":4' "$TEL"
assert_contains "and the reasons, sorted" '"facts_drilldown_reasons":"audit:2;explanation:2"' "$TEL"
assert_contains "and that an explain was printed" '"facts_output_shape":"explain"' "$TEL"
# A later projection cannot lower the count: it is derived at read time.
SPARK_RECORDING=1 "$SPARK" telemetry record --run rexp facts_drilldowns=1 >/dev/null 2>&1 || true
assert_contains "a stored projection cannot lower the derived count" '"facts_drilldowns":4' \
  "$("$SPARK" telemetry show --run rexp --json)"
# Without a run, nothing is logged and nothing fails.
rm -rf .spark/telemetry
"$SPARK" facts --issue 734 --explain authority.standing --because audit >/dev/null 2>&1 && ok || bad "a drill-down outside a run still answers"
[ ! -e .spark/telemetry ] && ok || bad "a drill-down outside a run logs nothing"

finish
