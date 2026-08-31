#!/usr/bin/env bash
# Behavioural suite for #583 — the Claude coding lane, asserted as a contract.
#
# This lane holds `contents: write` and is woken by a comment. That combination
# is the classic escalation shape, so its safety is not a matter of intent — it
# is a set of properties that must be mechanically true of the workflow file,
# and must stay true when someone edits it later.
#
# What is asserted, and why each one matters:
#
#   * a trusted association is REQUIRED, and the check sits in `if:` so it is
#     evaluated before any step runs and before credentials exist;
#   * an @claude mention is required too — a trusted human who did not ask for
#     Claude should not get it;
#   * forks are refused before checkout, because untrusted head code must never
#     execute where a write token is available;
#   * `workflows: write`, `administration` and `secrets` are NOT granted. A lane
#     that could edit its own guardrails would have none;
#   * there is no `workflow_run` trigger: the reviewer -> writer handoff is #585's
#     to enable, not this issue's;
#   * this lane does not review automatically, so it cannot become a second
#     reviewer beside #584.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "claude coding lane (#583)"
sandbox_init

WF="$repo_root/.github/workflows/claude.yml"
[ -f "$WF" ] && ok || bad "the coding lane workflow must exist"

if command -v python3 >/dev/null 2>&1; then
  py() { python3 -c "$1" "$WF"; }
else
  echo "  (python3 unavailable — YAML assertions skipped)"; finish; exit 0
fi

READ='import sys,yaml;d=yaml.safe_load(open(sys.argv[1]));on=d.get(True) or d.get("on");j=d["jobs"]["claude"];'

# --- it parses, and is one job -----------------------------------------------
py "$READ print('ok')" >/dev/null 2>&1 && ok || bad "the workflow must be valid YAML with a claude job"

# --- the write surface is exactly what the issue permits ---------------------
PERMS="$(py "$READ print(sorted((j.get('permissions') or {}).items()))")"
assert_contains "it may push to a branch"        "('contents', 'write')"      "$PERMS"
assert_contains "it may converse on a PR"        "('pull-requests', 'write')" "$PERMS"
assert_contains "it may comment on issues"       "('issues', 'write')"        "$PERMS"

# The absences are the control. Granting any of these would let the lane rewrite
# the guardrails that constrain it.
for forbidden in workflows administration secrets packages; do
  case "$PERMS" in
    *"'$forbidden'"*) bad "the lane must not be granted '$forbidden'" ;;
    *) ok ;;
  esac
done

# --- a trusted association is required, in `if:` -----------------------------
IF="$(py "$READ print(j.get('if',''))")"
for role in OWNER MEMBER COLLABORATOR; do
  assert_contains "association $role is accepted" "$role" "$IF"
done
# The gate must be a condition on the job, not a step: a step-level check runs
# after the runner already holds credentials.
[ -n "$IF" ] && ok || bad "the association gate must live in the job's if: condition"

# An untrusted association appears nowhere as an accepted value.
case "$IF" in
  *NONE*|*FIRST_TIME_CONTRIBUTOR*|*CONTRIBUTOR*)
    bad "an untrusted author association must not be accepted" ;;
  *) ok ;;
esac

# --- a mention is also required ----------------------------------------------
assert_contains "an explicit @claude mention is required" "@claude" "$IF"
# Both conditions, not either: association AND mention.
assert_contains "the two conditions are combined with and" "&&" "$IF"

# --- forks are refused before checkout ---------------------------------------
STEPS="$(py "$READ print([s.get('name','') for s in j['steps']])")"
assert_contains "there is an explicit untrusted-head refusal" "Refuse untrusted heads" "$STEPS"
first_step="$(py "$READ print(j['steps'][0].get('name',''))")"
assert_contains "and it runs first, before checkout" "Refuse untrusted heads" "$first_step"

body="$(cat "$WF")"
assert_contains "the refusal compares head against this repository" "HEAD_REPO" "$body"

# --- the reviewer handoff is NOT enabled here --------------------------------
# #585 owns waking this lane from a reviewer verdict. Landing it early would
# turn on an automation path this issue is not authorised to enable.
TRIGGERS="$(py "$READ print(sorted(on.keys()))")"
case "$TRIGGERS" in
  *workflow_run*) bad "no workflow_run trigger belongs here — #585 owns the reviewer handoff" ;;
  *) ok ;;
esac

# --- it is not a second automatic reviewer -----------------------------------
# Waking on every pull_request would make this lane a reviewer beside #584.
case "$TRIGGERS" in
  *"'pull_request'"*) bad "the coding lane must not wake on every pull_request" ;;
  *) ok ;;
esac
assert_contains "it wakes on a comment"        "issue_comment"  "$TRIGGERS"
assert_contains "and on a review"              "pull_request_review" "$TRIGGERS"

# At most one production reviewer: no other workflow currently reviews every PR
# automatically, so installing #584 later cannot produce two.
autoreviewers=0
for f in "$repo_root"/.github/workflows/*.yml; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in claude.yml) continue ;; esac
  if grep -qE '^\s+pull_request:' "$f" && grep -qiE 'review' "$(printf '%s' "$f")"; then
    autoreviewers=$((autoreviewers + 1))
  fi
done
[ "$autoreviewers" -eq 0 ] && ok \
  || bad "another workflow already reviews every PR automatically ($autoreviewers); #584 would be a second"

# --- it never merges ----------------------------------------------------------
case "$body" in
  *"pr merge"*|*"merge_method"*) bad "the coding lane must contain no merge capability" ;;
  *) ok ;;
esac
assert_contains "and the prompt says so explicitly" "Never merge" "$body"

# --- the operator contract is documented -------------------------------------
DOC="$repo_root/docs/ops/claude-coding-lane.md"
[ -f "$DOC" ] && ok || bad "the lane must be documented at docs/ops/claude-coding-lane.md"
if [ -f "$DOC" ]; then
  d="$(cat "$DOC")"
  assert_contains "stating how it is invoked"      "@claude" "$d"
  assert_contains "what it may write"              "feature branch" "$d"
  assert_contains "and what it can never do"       "never merge" "$d"
fi

# --- MUTATION CONTROL --------------------------------------------------------
# Remove the association gate — the single change that turns a comment-triggered
# write-capable job into an escalation path. The gate assertions must go red.
MUTWF="$WORK/claude-mutant.yml"
sed 's/^    if: |$/    if: \&\& |/' "$WF" > "$MUTWF" 2>/dev/null || cp "$WF" "$MUTWF"
python3 - "$WF" "$MUTWF" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
d["jobs"]["claude"].pop("if", None)
yaml.safe_dump(d, open(sys.argv[2], "w"))
PY
mif="$(python3 -c "import sys,yaml;d=yaml.safe_load(open(sys.argv[1]));print(d['jobs']['claude'].get('if',''))" "$MUTWF")"
if [ -z "$mif" ]; then ok
else bad "MUTATION control did not remove the gate — it proves nothing"; fi
case "$mif" in
  *OWNER*) bad "MUTATION control — the gate survived; the assertions do not discriminate" ;;
  *) ok ;;
esac

finish
