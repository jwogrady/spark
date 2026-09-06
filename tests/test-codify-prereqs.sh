#!/usr/bin/env bash
# Behavioral suite for codify's dependency-readiness preflight
# (skills/codify/scripts/check-prereqs.sh): the #344 ordering invariant — if B
# depends on A, the base used to Codify B must contain A's ACCEPTED INTEGRATED
# RESULT — with three semantically distinct verdicts: READY needs positive
# proof on both axes (prerequisite integration + exactly-at-fresh-trunk base);
# BLOCKED is positive proof of violation; NOT ASSESSED is insufficient
# evidence, never a guess. The verdict is a pure function over evidence lines;
# end-to-end runs use a fake gh plus REAL git ancestry in file-remote fixtures.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
script="$WORK/plugin/skills/codify/scripts/check-prereqs.sh"
. "$script"   # load prereq_verdict (dispatch is source-guarded)

# ===================== pure verdict: the semantics matrix =====================

# no prerequisites, exactly at trunk -> READY (vacuous invariant, proven base).
rc=0; out="$(printf 'behind\t0\torigin/master\nahead\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "no prerequisites at fresh trunk is ready" 0 "$rc"
assert_contains "says no prerequisites" "no prerequisites declared" "$out"

# no prerequisites, no trunk -> READY with the freshness caveat, not a guess of freshness.
rc=0; out="$(printf 'trunk\tnone\n' | prereq_verdict)" || rc=$?
assert_rc "no prerequisites without a trunk is ready with caveat" 0 "$rc"
assert_contains "freshness honestly not assessed" "freshness not assessed" "$out"

# INTEGRATED blocker + exactly-at-trunk -> READY with positive wording.
rc=0; out="$(printf 'blocker\t12\tINTEGRATED\nbehind\t0\torigin/master\nahead\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "integrated prerequisite at fresh trunk is ready" 0 "$rc"
assert_contains "ready states the positive proof" "merged result is contained in this base" "$out"

# open blocker -> BLOCKED.
rc=0; out="$(printf 'blocker\t12\tOPEN\nbehind\t0\torigin/master\nahead\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "open blocker blocks" 1 "$rc"
assert_contains "names the open prerequisite" "#12 is OPEN" "$out"

# unknown state -> BLOCKED (never guess).
rc=0; out="$(printf 'blocker\t9\tUNKNOWN\n' | prereq_verdict)" || rc=$?
assert_rc "unknown blocker state blocks" 1 "$rc"

# #344: merged result positively NOT in this base -> BLOCKED, even though the
# issue is closed and the base is not behind.
rc=0; out="$(printf 'blocker\t12\tUNINTEGRATED\nbehind\t0\torigin/master\nahead\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "closed-but-unintegrated result blocks" 1 "$rc"
assert_contains "names the missing result" "NOT in this base" "$out"

# #344: manually closed with no merged result -> NOT ASSESSED, never READY.
rc=0; out="$(printf 'blocker\t12\tUNPROVEN:no-merged-result\nbehind\t0\torigin/master\nahead\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "manual close without a merged result is not assessed" 3 "$rc"
assert_contains "says a manual close is not acceptance" "manual close is not an accepted result" "$out"
case "$out" in *"ready"*) bad "an unproven prerequisite must never read as ready" ;; *) ok ;; esac

# merged result unknown to local history -> NOT ASSESSED.
rc=0; out="$(printf 'blocker\t12\tUNPROVEN:result-not-local\n' | prereq_verdict)" || rc=$?
assert_rc "result missing from local history is not assessed" 3 "$rc"

# BLOCKED dominates NOT ASSESSED when both exist (multiple prerequisites,
# one unsatisfied -> BLOCKED).
rc=0; out="$(printf 'blocker\t12\tINTEGRATED\nblocker\t15\tOPEN\nblocker\t17\tUNPROVEN:no-merged-result\n' | prereq_verdict)" || rc=$?
assert_rc "one open among many blocks" 1 "$rc"
assert_contains "names the open one" "#15 is OPEN" "$out"

# stale base -> BLOCKED even with every prerequisite integrated.
rc=0; out="$(printf 'blocker\t12\tINTEGRATED\nbehind\t4\torigin/master\nahead\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "stale base blocks" 1 "$rc"
assert_contains "names the trunk and count" "4 commit(s) behind origin/master" "$out"

# #344: ahead/diverged base -> not fresh-trunk ready ("not behind" is not enough).
rc=0; out="$(printf 'blocker\t12\tINTEGRATED\nbehind\t0\torigin/master\nahead\t3\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "diverged base blocks" 1 "$rc"
assert_contains "names the divergence" "ahead of/diverged from origin/master" "$out"
assert_contains "teaches the explicit start point" "explicit start point" "$out"

# prerequisites integrated but no readable trunk -> NOT ASSESSED (base proof
# unavailable; absence of a detected problem is not READY).
rc=0; out="$(printf 'blocker\t12\tINTEGRATED\ntrunk\tnone\n' | prereq_verdict)" || rc=$?
assert_rc "integrated without a provable base is not assessed" 3 "$rc"
assert_contains "says the base is unproven" "no remote trunk is readable" "$out"

# ATTACK (fetch-failure regression): a trunk whose refresh FAILED must never
# back a positive fresh-trunk claim — prerequisites present -> NOT ASSESSED.
rc=0; out="$(printf 'blocker\t12\tINTEGRATED\ntrunk\tunrefreshed\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "unrefreshed trunk with prerequisites is not assessed" 3 "$rc"
assert_contains "names the failed refresh" "could not be refreshed" "$out"
case "$out" in *"exactly at"*) bad "a stale tracking ref must never claim fresh" ;; *) ok ;; esac
rc=0; out="$(printf 'trunk\tunrefreshed\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "unrefreshed trunk with no prerequisites is ready with caveat" 0 "$rc"
assert_contains "caveats the failed refresh" "could not be refreshed" "$out"

# #363: a cross-repository blocker is never resolved against this repo —
# OPEN in its owning repo is a positive violation; otherwise its integration
# into this base is unprovable here.
rc=0; out="$(printf 'blocker\t12\tXREPO-OPEN:other/elsewhere\n' | prereq_verdict)" || rc=$?
assert_rc "cross-repo open blocker blocks" 1 "$rc"
assert_contains "names the owning repository" "other/elsewhere#12 is OPEN" "$out"
rc=0; out="$(printf 'blocker\t12\tXREPO-UNPROVEN:other/elsewhere\nbehind\t0\torigin/master\nahead\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "cross-repo closed blocker is not assessed" 3 "$rc"
assert_contains "says it cannot be proven here" "cannot be proven here" "$out"
rc=0; out="$(printf 'blocker\t12\tXREPO-UNPROVEN:unknown-repository\n' | prereq_verdict)" || rc=$?
assert_rc "unidentifiable owning repo is not assessed" 3 "$rc"

# malformed evidence -> never READY.
rc=0; out="$(printf 'behind\tnonsense\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "non-numeric freshness blocks" 1 "$rc"
rc=0; out="$(printf 'blocker\t12\tGIBBERISH\n' | prereq_verdict)" || rc=$?
assert_rc "gibberish blocker classification blocks" 1 "$rc"

# ================= end-to-end: real ancestry, fake gh =================
# Fixture: a bare file remote whose master carries the prerequisite's merge
# result; clones position HEAD relative to it.
seed="$WORK/seed"; make_repo "$seed"
bare="$WORK/origin.git"; git clone -q --bare "$seed" "$bare"
adv="$WORK/adv"; git clone -q "$bare" "$adv"
( cd "$adv" && git commit --allow-empty -qm "feat: prerequisite result" && git push -q origin master )
PREREQ_SHA="$(cd "$adv" && git rev-parse HEAD)"
# a side branch whose commit is fetched but NOT an ancestor of master
( cd "$adv" && git checkout -qb side master~1 \
    && git commit --allow-empty -qm "feat: unmerged side result" && git push -q origin side )
SIDE_SHA="$(cd "$adv" && git rev-parse HEAD)"

fakebin="$WORK/fakegh"; mkdir -p "$fakebin"
mk_gh() { # mk_gh <merged-oid-or-NONE> — graphql answers for blocker 12
  local oid="$1"
  stub_gh "$fakebin/gh" <<EOF
case "\$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12,"repository_url":"https://api.github.com/repos/o/self"}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Implements the thing."}' ;;
  *"issue view 12 --json state"*) answer_json '{"state":"CLOSED"}' ;;
  *graphql*"num=12"*) if [ "$oid" = "NONE" ]; then answer_json "{\"data\":{\"repository\":{\"issue\":{\"closedByPullRequestsReferences\":{\"nodes\":[]}}}}}"; else answer_json "{\"data\":{\"repository\":{\"issue\":{\"closedByPullRequestsReferences\":{\"nodes\":[{\"merged\":true,\"mergeCommit\":{\"oid\":\"$oid\"}}]}}}}}"; fi ;;
  *) exit 1 ;;
esac
EOF
}

fresh() { # fresh <name> — a clone with HEAD exactly at origin/master
  local d="$WORK/$1"; rm -rf "$d"; git clone -q "$bare" "$d"
  ( cd "$d" && git fetch -q origin side ) # side result known locally
  printf '%s' "$d"
}

# merged accepted result IS in the base, HEAD exactly at fresh trunk -> READY.
repo="$(fresh e2e-ready)"; mk_gh "$PREREQ_SHA"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "integrated + fresh trunk is ready" 0 "$rc"
assert_contains "positive proof is stated" "merged result is contained in this base" "$out"

# blocker closed, merged result exists but is NOT an ancestor of HEAD -> BLOCKED.
repo="$(fresh e2e-unint)"; mk_gh "$SIDE_SHA"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "merged-but-unintegrated result blocks" 1 "$rc"
assert_contains "names the absent result" "NOT in this base" "$out"

# blocker manually closed, NO merged closing PR -> NOT ASSESSED, never ready.
repo="$(fresh e2e-manual)"; mk_gh "NONE"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "manually closed blocker is not assessed" 3 "$rc"
case "$out" in *"ready"*) bad "manual close must never be ready" ;; *) ok ;; esac

# HEAD diverged from trunk (local extra commit) -> BLOCKED, not fresh-trunk ready.
repo="$(fresh e2e-diverged)"; mk_gh "$PREREQ_SHA"
( cd "$repo" && git commit --allow-empty -qm "feat: unrelated local work" )
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "diverged HEAD blocks" 1 "$rc"
assert_contains "names the divergence" "diverged" "$out"

# HEAD behind trunk -> BLOCKED.
repo="$(fresh e2e-behind)"; mk_gh "$PREREQ_SHA"
( cd "$adv" && git checkout -q master && git commit --allow-empty -qm "feat: newer trunk work" && git push -q origin master )
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "behind trunk blocks" 1 "$rc"
assert_contains "names behind" "behind origin/master" "$out"

# ATTACK: multiple merged closing PRs where only the SECOND is integrated —
# the resolver must find the integrated one, not stop at the first.
repo="$(fresh e2e-multi)"
stub_gh "$fakebin/gh" <<EOF
case "\$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12,"repository_url":"https://api.github.com/repos/o/self"}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Implements the thing."}' ;;
  *"issue view 12 --json state"*) answer_json '{"state":"CLOSED"}' ;;
  *graphql*"num=12"*) answer_json "{\"data\":{\"repository\":{\"issue\":{\"closedByPullRequestsReferences\":{\"nodes\":[{\"merged\":true,\"mergeCommit\":{\"oid\":\"$SIDE_SHA\"}},{\"merged\":true,\"mergeCommit\":{\"oid\":\"$PREREQ_SHA\"}}]}}}}}" ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "any one integrated merged result proves the prerequisite" 0 "$rc"

# ATTACK: a blocker declared in BOTH the native list and the body is
# evaluated once (dedup), and the verdict still needs its proof.
repo="$(fresh e2e-dedup)"
stub_gh "$fakebin/gh" <<'EOF'
log="${GH_DEDUP_LOG:-/dev/null}"; printf '%s
' "$*" >> "$log"
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12,"repository_url":"https://api.github.com/repos/o/self"}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Blocked by #12"}' ;;
  *"issue view 12 --json state"*) answer_json '{"state":"OPEN"}' ;;
  *) exit 1 ;;
esac
EOF
export GH_DEDUP_LOG="$WORK/dedup-calls.log"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "duplicated declaration still blocks on the open blocker" 1 "$rc"
[ "$(grep -c 'issue view 12 --json state' "$GH_DEDUP_LOG")" = "1" ] \
  && ok || bad "a blocker declared twice is evaluated once"
unset GH_DEDUP_LOG

# GitHub relationship unavailable (graphql fails for the closed blocker)
# -> NOT ASSESSED.
repo="$(fresh e2e-noproof)"
stub_gh "$fakebin/gh" <<'EOF'
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12,"repository_url":"https://api.github.com/repos/o/self"}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"No body deps."}' ;;
  *"issue view 12 --json state"*) answer_json '{"state":"CLOSED"}' ;;
  *graphql*) exit 1 ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "unavailable relationship proof is not assessed" 3 "$rc"
assert_contains "instructs manual verification" "verify" "$out"

# blocked-by endpoint failure -> NOT ASSESSED (never 'no blockers').
stub_gh "$fakebin/gh" <<'EOF'
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) exit 1 ;;
  *"issue view 7 --json body"*) answer_json '{"body":"No body deps."}' ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "failed blocked-by endpoint degrades to not-assessed" 3 "$rc"
assert_contains "instructs manual verification on endpoint failure" "verify prerequisites by hand" "$out"

# no prerequisites at all, HEAD exactly at trunk -> READY; and the branch
# origination contract: a branch created per the ready state starts at the
# resolved fresh trunk, not an arbitrary HEAD.
repo="$(fresh e2e-nodeps)"
stub_gh "$fakebin/gh" <<'EOF'
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"No deps here."}' ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "no prerequisites at fresh trunk is ready" 0 "$rc"
( cd "$repo" && git checkout -qb feat/7-thing origin/master \
    && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ] ) \
  && ok || bad "explicit start point puts the new branch exactly at origin/master"

# --- #438: ONE executable dependency authority.
# ATTACK: the native graph answers [] while the body still carries a stale
# "Blocked by #99". Prose must not manufacture a prerequisite GitHub does not
# have — that is a phantom blocker failing readiness closed. It is reported as
# drift, and the drift must never be resolved against GitHub as if it were an
# edge (no state lookup for #99 at all).
repo="$(fresh e2e-stale-prose)"
stub_gh "$fakebin/gh" <<'EOF'
log="${GH_PROSE_LOG:-/dev/null}"; printf '%s\n' "$*" >> "$log"
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Blocked by #99 (left over from an earlier plan)."}' ;;
  *) exit 1 ;;
esac
EOF
export GH_PROSE_LOG="$WORK/prose-calls.log"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "stale body prose does not block when the native graph is empty" 0 "$rc"
assert_contains "the stale reference is reported as drift" "drift:" "$out"
assert_contains "drift names the stale issue" "Blocked by #99" "$out"
[ "$(grep -c 'issue view 99' "$GH_PROSE_LOG")" = "0" ] \
  && ok || bad "a prose-only reference must never be resolved as an edge"
unset GH_PROSE_LOG

# ATTACK: native carries #12 and the body ALSO claims #98. Only the native
# edge is executable; the extra body reference is drift, never a second edge.
# The open native blocker still blocks, so drift never softens a real verdict.
repo="$(fresh e2e-extra-prose)"
stub_gh "$fakebin/gh" <<'EOF'
log="${GH_EXTRA_LOG:-/dev/null}"; printf '%s\n' "$*" >> "$log"
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12,"repository_url":"https://api.github.com/repos/o/self"}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Blocked by #12 and Blocked by #98"}' ;;
  *"issue view 12 --json state"*) answer_json '{"state":"OPEN"}' ;;
  *) exit 1 ;;
esac
EOF
export GH_EXTRA_LOG="$WORK/extra-calls.log"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "a contradictory body reference adds no executable edge" 1 "$rc"
assert_contains "the native blocker still blocks" "#12 is OPEN" "$out"
assert_contains "the extra body reference is drift" "Blocked by #98" "$out"
[ "$(grep -c 'issue view 98' "$GH_EXTRA_LOG")" = "0" ] \
  && ok || bad "the extra body reference must never be resolved as an edge"
unset GH_EXTRA_LOG

# read-only: the whole flow never calls a mutating gh endpoint.
repo="$(fresh e2e-readonly)"; mk_gh "$PREREQ_SHA"
sed -i.bak 's|^case "\$\*" in|log="${GH_STUB_LOG:-/dev/null}"; printf "%s\\n" "$*" >> "$log"\ncase "$*" in|' "$fakebin/gh" 2>/dev/null || \
  perl -0pi -e 's/^case "\$\*" in/log="\$\{GH_STUB_LOG:-\/dev\/null\}"; printf "%s\\\\n" "\$*" >> "\$log"\ncase "\$*" in/m' "$fakebin/gh"
export GH_STUB_LOG="$WORK/gh-prereq-calls.log"
( cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 >/dev/null 2>&1 ) || true
case "$(cat "$GH_STUB_LOG" 2>/dev/null)" in
  *"-X POST"*|*"-X PATCH"*|*"-X DELETE"*|*"--method"*|*"--input"*) bad "prereq check must never call a mutating gh endpoint" ;;
  *) ok ;;
esac
unset GH_STUB_LOG

# ATTACK e2e: origin unreachable (fetch fails), blocker's merged oid already
# local and ancestral, remote trunk actually newer -> NOT ASSESSED, never a
# positive "exactly at the fresh trunk" READY from the stale tracking ref.
repo="$(fresh e2e-fetchfail)"; mk_gh "$PREREQ_SHA"
( cd "$adv" && git checkout -q master && git commit --allow-empty -qm "feat: remote moved on" && git push -q origin master )
( cd "$repo" && git remote set-url origin /nonexistent-origin.git )
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "failed refresh with prerequisites is not assessed" 3 "$rc"
assert_contains "names the failed refresh" "could not be refreshed" "$out"

# ATTACK (#363): the same-number trap — the native edge names issue 12 of
# ANOTHER repository, while THIS repo's issue 12 is closed with an integrated
# merged result. The unrelated local issue must never satisfy the dependency:
# not READY, no local graphql resolution, the owning repo named.
repo="$(fresh e2e-xrepo)"
stub_gh "$fakebin/gh" <<'EOF'
log="${GH_XREPO_LOG:-/dev/null}"; printf '%s\n' "$*" >> "$log"
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12,"repository_url":"https://api.github.com/repos/other/elsewhere"}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Implements the thing."}' ;;
  *"issue view 12 -R other/elsewhere"*) answer_json '{"state":"CLOSED"}' ;;
  *"issue view 12 --json state"*) answer_json '{"state":"CLOSED"}' ;;
  *graphql*"num=12"*) printf 'SHOULD-NEVER-BE-CALLED\n' ;;
  *) exit 1 ;;
esac
EOF
export GH_XREPO_LOG="$WORK/xrepo-calls.log"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "same-number cross-repo blocker is not assessed" 3 "$rc"
assert_contains "names the owning repository" "other/elsewhere" "$out"
case "$out" in *"ready"*) bad "a cross-repo blocker must never produce ready" ;; *) ok ;; esac
case "$(cat "$GH_XREPO_LOG")" in
  *graphql*) bad "the local repo's same-numbered issue must never be resolved" ;;
  *) ok ;;
esac
unset GH_XREPO_LOG

# cross-repo blocker OPEN in its owning repo -> BLOCKED, named.
stub_gh "$fakebin/gh" <<'EOF'
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12,"repository_url":"https://api.github.com/repos/other/elsewhere"}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Implements the thing."}' ;;
  *"issue view 12 -R other/elsewhere"*) answer_json '{"state":"OPEN"}' ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "cross-repo open blocker blocks end-to-end" 1 "$rc"
assert_contains "names owning repo and number" "other/elsewhere#12" "$out"

# a native edge with no identifiable owning repository -> NOT ASSESSED.
stub_gh "$fakebin/gh" <<'EOF'
case "$*" in
  *"api repos/{owner}/{repo} --jq .full_name"*) answer_json '{"full_name":"o/self"}' ;;
  *"dependencies/blocked_by"*) answer_json '[{"number":12}]' ;;
  *"issue view 7 --json body"*) answer_json '{"body":"Implements the thing."}' ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "unidentifiable owning repo is not assessed end-to-end" 3 "$rc"
assert_contains "never assumed local" "never assumed local" "$out"

# no gh at all -> NOT ASSESSED (exit 3).
bare2="$WORK/barebin"; mkdir -p "$bare2"
for t in bash sh dirname basename cat grep sed awk sort tr head find env git printf; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] && ln -sf "$real" "$bare2/$t"
done
rc=0; out="$(cd "$repo" && env PATH="$bare2" bash "$script" 7 2>&1)" || rc=$?
assert_rc "no gh degrades to not-assessed" 3 "$rc"
assert_contains "instructs manual verification without gh" "verify prerequisites by hand" "$out"

# usage: a non-numeric issue is rejected.
rc=0; ( cd "$repo" && bash "$script" abc >/dev/null 2>&1 ) || rc=$?
assert_rc "non-numeric issue rejected" 2 "$rc"

finish
