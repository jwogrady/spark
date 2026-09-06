#!/usr/bin/env bash
# Offline suite for the milestone-gate readiness signal (#194). It exercises
# the pure decision logic against fixtures and asserts the workflow can never
# perform release mechanics. No network, no gh.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/.github/scripts/milestone-gate.sh"
runner="$root/.github/scripts/gate-runner.sh"
workflow="$root/.github/workflows/milestone-gate.yml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# gate <want-exit> <desc> <manifest> <issues> <checks> <state> [needle ...]
gate() {
  local want="$1" desc="$2" man="$3" iss="$4" chk="$5" want_state="$6"; shift 6
  local out rc=0 needle
  out="$(bash "$script" --manifest "$man" --issues "$iss" --checks "$chk" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then bad "$desc — want exit $want, got $rc"; return 0; fi
  case "$out" in
    "gate-state: $want_state"*) ;;
    *) bad "$desc — want state '$want_state', got: $(printf '%s' "$out" | head -n1)"; return 0 ;;
  esac
  for needle in "$@"; do
    case "$out" in *"$needle"*) ;; *) bad "$desc — output lacks '$needle'"; return 0 ;; esac
  done
  ok
}

bash -n "$script"  && ok || bad "bash -n milestone-gate.sh"
bash -n "$runner"  && ok || bad "bash -n gate-runner.sh"

printf '{".":"0.10.0"}\n' > "$work/m-010.json"
printf '{".":"0.11.0"}\n' > "$work/m-011.json"

cat > "$work/open.json" <<'EOF'
[
  {"number": 194, "state": "closed", "milestone": {"title": "v0.10 — Truthful record & governance"}},
  {"number": 196, "state": "open",   "milestone": {"title": "v0.10 — Truthful record & governance"}},
  {"number": 300, "state": "open",   "milestone": {"title": "v0.11 — Later"}}
]
EOF
cat > "$work/all-closed.json" <<'EOF'
[
  {"number": 186, "state": "closed", "milestone": {"title": "v0.10 — Truthful record & governance"}},
  {"number": 194, "state": "closed", "milestone": {"title": "v0.10 — Truthful record & governance"}}
]
EOF
cat > "$work/flat.json" <<'EOF'
[
  {"number": 186, "state": "closed", "milestone": "v0.10 — Truthful record & governance"}
]
EOF

# Open issues in the mapped milestone → blocked, names the open one, not the v0.11 one.
gate 1 "open milestone issue blocks" \
  "$work/m-010.json" "$work/open.json" green blocked "#196"

# Milestone complete + validation green → ready.
gate 0 "complete + green is ready" \
  "$work/m-010.json" "$work/all-closed.json" green ready "Ready for human approval"

# Complete but validation not green → blocked.
gate 1 "complete but red validation blocks" \
  "$work/m-010.json" "$work/all-closed.json" red blocked "validation is not green"

# The ready summary must never promise release mechanics.
out="$(bash "$script" --manifest "$work/m-010.json" --issues "$work/all-closed.json" --checks green 2>&1)"
case "$out" in *"no release mechanics"*) ok ;; *) bad "ready summary must state it performs no release mechanics" ;; esac

# Version with no matching milestone → neutral, exit 0, no signal.
gate 0 "unmapped version is neutral" \
  "$work/m-011.json" "$work/all-closed.json" green neutral "gate is neutral"

# Flattened milestone string parses the same as the object form.
gate 0 "flattened milestone form parses" \
  "$work/m-010.json" "$work/flat.json" green ready "Ready for human approval"

# Missing manifest is a usage error, not a silent pass.
bash "$script" --manifest "$work/nope.json" --issues "$work/flat.json" >/dev/null 2>&1 && rc=0 || rc=$?
[ "${rc:-0}" -eq 2 ] && ok || bad "missing manifest should exit 2 (got ${rc:-0})"

# --- Safety: the workflow provably cannot merge, tag, or publish -----------
grep -qE '^[[:space:]]+contents:[[:space:]]*read'  "$workflow" && ok || bad "workflow must grant contents: read"
grep -qE '^[[:space:]]+contents:[[:space:]]*write' "$workflow" && bad "workflow must NOT grant contents: write" || ok
grep -qE '^[[:space:]]+statuses:[[:space:]]*write' "$workflow" && ok || bad "workflow needs statuses: write"
for forbidden in 'gh pr merge' 'gh release' 'git tag' 'git push'; do
  if grep -qF "$forbidden" "$workflow" "$runner" "$script"; then
    bad "milestone-gate must not contain '$forbidden'"
  else ok; fi
done

finish
