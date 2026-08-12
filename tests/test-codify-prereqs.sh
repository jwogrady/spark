#!/usr/bin/env bash
# Behavioral suite for codify's dependency-readiness preflight
# (skills/codify/scripts/check-prereqs.sh): the ordering invariant — if B
# depends on A, the base used to Codify B must contain A's accepted result —
# enforced fail-closed. The verdict is a pure function over evidence lines
# (offline-testable); the end-to-end path runs against a fake gh.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
script="$WORK/plugin/skills/codify/scripts/check-prereqs.sh"
. "$script"   # load prereq_verdict (dispatch is source-guarded)

# --- pure verdict: no evidence at all -> ready.
rc=0; out="$(printf '' | prereq_verdict)" || rc=$?
assert_rc "no evidence is ready" 0 "$rc"

# --- a CLOSED blocker and a current base -> ready.
rc=0; out="$(printf 'blocker\t12\tCLOSED\nbehind\t0\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "closed blocker, current base is ready" 0 "$rc"

# --- an OPEN blocker fails closed, named.
rc=0; out="$(printf 'blocker\t12\tOPEN\n' | prereq_verdict)" || rc=$?
assert_rc "open blocker blocks" 1 "$rc"
assert_contains "names the open prerequisite" "#12 is OPEN" "$out"

# --- an UNKNOWN blocker state also fails closed (never guess).
rc=0; out="$(printf 'blocker\t9\tUNKNOWN\n' | prereq_verdict)" || rc=$?
assert_rc "unknown blocker state blocks" 1 "$rc"

# --- a stale base fails closed even with every blocker closed.
rc=0; out="$(printf 'blocker\t12\tCLOSED\nbehind\t4\torigin/master\n' | prereq_verdict)" || rc=$?
assert_rc "stale base blocks" 1 "$rc"
assert_contains "names the trunk and count" "4 commit(s) behind origin/master" "$out"

# --- end-to-end with a fake gh: native blocked-by plus a body "Blocked by #N"
# line are unioned and deduped; the open one blocks.
repo="$WORK/prj"; make_repo "$repo"
fakebin="$WORK/fakegh"; mkdir -p "$fakebin"
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"dependencies/blocked_by"*) printf '12\n' ;;
  *"issue view 7 --json body"*) printf 'Do the thing.\nBlocked by #12, #15\n' ;;
  *"issue view 12 --json state"*) printf 'CLOSED\n' ;;
  *"issue view 15 --json state"*) printf 'OPEN\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$fakebin/gh"
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "end-to-end blocks on the open body-declared prerequisite" 1 "$rc"
assert_contains "names #15" "#15 is OPEN" "$out"
case "$out" in
  *"#12"*) bad "closed blocker #12 must not be reported as blocking" ;;
  *) ok ;;
esac

# --- all prerequisites closed -> ready (no remote trunk in the sandbox, so
# freshness is honestly unassessed rather than guessed).
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"dependencies/blocked_by"*) : ;;
  *"issue view 7 --json body"*) printf 'Blocked by #12\n' ;;
  *"issue view 12 --json state"*) printf 'CLOSED\n' ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo" && env PATH="$fakebin:$PATH" bash "$script" 7 2>&1)" || rc=$?
assert_rc "closed prerequisites are ready" 0 "$rc"
assert_contains "says ready" "ready" "$out"

# --- no gh at all -> not assessed (exit 3), instructs manual verification.
bare="$WORK/barebin"; mkdir -p "$bare"
for t in bash sh dirname basename cat grep sed awk sort tr head find env git printf; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] && ln -s "$real" "$bare/$t"
done
rc=0; out="$(cd "$repo" && env PATH="$bare" bash "$script" 7 2>&1)" || rc=$?
assert_rc "no gh degrades to not-assessed" 3 "$rc"
assert_contains "instructs manual verification" "verify prerequisites by hand" "$out"

# --- usage: a non-numeric issue is rejected.
rc=0; ( cd "$repo" && bash "$script" abc >/dev/null 2>&1 ) || rc=$?
assert_rc "non-numeric issue rejected" 2 "$rc"

finish
