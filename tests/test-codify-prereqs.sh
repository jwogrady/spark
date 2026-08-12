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
  cat > "$fakebin/gh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *"dependencies/blocked_by"*) printf '12\n' ;;
  *"issue view 7 --json body"*) printf 'Implements the thing.\n' ;;
  *"issue view 12 --json state"*) printf 'CLOSED\n' ;;
  *graphql*"num=12"*) [ "$oid" = "NONE" ] || printf '%s\n' "$oid" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$fakebin/gh"
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
cat > "$fakebin/gh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *"dependencies/blocked_by"*) printf '12\n' ;;
  *"issue view 7 --json body"*) printf 'Implements the thing.\n' ;;
  *"issue view 12 --json state"*) printf 'CLOSED\n' ;;
  *graphql*"num=12"*) printf '%s\n%s\n' "$SIDE_SHA" "$PREREQ_SHA" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$fakebin/gh"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "any one integrated merged result proves the prerequisite" 0 "$rc"

# ATTACK: a blocker declared in BOTH the native list and the body is
# evaluated once (dedup), and the verdict still needs its proof.
repo="$(fresh e2e-dedup)"
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
log="${GH_DEDUP_LOG:-/dev/null}"; printf '%s
' "$*" >> "$log"
case "$*" in
  *"dependencies/blocked_by"*) printf '12
' ;;
  *"issue view 7 --json body"*) printf 'Blocked by #12
' ;;
  *"issue view 12 --json state"*) printf 'OPEN
' ;;
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
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"dependencies/blocked_by"*) printf '12\n' ;;
  *"issue view 7 --json body"*) printf 'No body deps.\n' ;;
  *"issue view 12 --json state"*) printf 'CLOSED\n' ;;
  *graphql*) exit 1 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$fakebin/gh"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "unavailable relationship proof is not assessed" 3 "$rc"
assert_contains "instructs manual verification" "verify" "$out"

# blocked-by endpoint failure -> NOT ASSESSED (never 'no blockers').
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"dependencies/blocked_by"*) exit 1 ;;
  *"issue view 7 --json body"*) printf 'No body deps.\n' ;;
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
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"dependencies/blocked_by"*) : ;;
  *"issue view 7 --json body"*) printf 'No deps here.\n' ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "no prerequisites at fresh trunk is ready" 0 "$rc"
( cd "$repo" && git checkout -qb feat/7-thing origin/master \
    && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ] ) \
  && ok || bad "explicit start point puts the new branch exactly at origin/master"

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
