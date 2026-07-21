#!/usr/bin/env bash
# Regression tests for the plan skill's roadmap-completeness checker
# (plugins/spark/skills/plan/scripts/roadmap-check.sh). Fully offline: every
# case supplies its own --roadmap and --issues fixtures, so gh is never
# consulted and nothing touches the network.

set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/plugins/spark/skills/plan/scripts/roadmap-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0

# check <want-exit> <desc> <roadmap> <issues> [needle ...]
# Runs the checker against the fixtures and asserts the exit code, plus that
# the combined output contains every needle.
check() {
  local want="$1" desc="$2" roadmap="$3" issues="$4"; shift 4
  local out rc=0 needle
  out="$(bash "$script" --roadmap "$roadmap" --issues "$issues" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail=$((fail + 1)); echo "  ✖ $desc — want exit $want, got $rc"; return 0
  fi
  for needle in "$@"; do
    case "$out" in
      *"$needle"*) ;;
      *) fail=$((fail + 1)); echo "  ✖ $desc — output lacks '$needle'"; return 0 ;;
    esac
  done
  pass=$((pass + 1))
}

if bash -n "$script" 2>/dev/null; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "  ✖ bash -n roadmap-check.sh"
fi

# --- roadmap fixtures
cat > "$work/complete.md" <<'EOF'
# Roadmap

## v0.9 — Current train

**Status:** Shipped (`v0.9.0`)

Everything landed.

---

## v0.10 — Next train

**Status:** Next

Release assignment becomes mechanical (#179, #188).
EOF

cat > "$work/shipped-only.md" <<'EOF'
# Roadmap

## v0.9 — Current train

**Status:** Shipped (`v0.9.0`)

Everything landed (#177).
EOF

cat > "$work/no-links.md" <<'EOF'
# Roadmap

## v0.9 — Current train

**Status:** Shipped (`v0.9.0`)

Everything landed.

## v0.10 — Next train

**Status:** Planned

Some prose that references no issues at all.
EOF

cat > "$work/deferred-marker.md" <<'EOF'
# Roadmap

## v0.9 — Current train

**Status:** Shipped (`v0.9.0`)

Everything landed.

## v0.10 — Next train

**Status:** Planned

Scope deferred until the audit lands.
EOF

# --- issue fixtures (flattened labels/milestone, the pre-normalized form)
cat > "$work/issues-complete.json" <<'EOF'
[
  {"number": 179, "title": "Assigned", "labels": ["feature", "P2"], "milestone": "v0.10 — Next train", "body": "Acceptance criteria here."},
  {"number": 180, "title": "Backlogged", "labels": ["feature"], "milestone": null, "body": "Backlog: waiting on #188 policy"},
  {"number": 181, "title": "Blocked", "labels": ["feature"], "milestone": null, "body": "Blocked by #185"},
  {"number": 182, "title": "Labelled backlog", "labels": ["feature", "backlog"], "milestone": null, "body": "Someday."},
  {"number": 183, "title": "A bug", "labels": ["bug"], "milestone": null, "body": "Not a feature; needs no release decision."}
]
EOF

cat > "$work/issues-empty.json" <<'EOF'
[]
EOF

cat > "$work/issues-unassigned.json" <<'EOF'
[
  {"number": 190, "title": "Drifting idea", "labels": ["feature"], "milestone": null, "body": "Just an idea with no decision recorded."}
]
EOF

cat > "$work/issues-blocked.json" <<'EOF'
[
  {"number": 191, "title": "Waiting", "labels": ["feature"], "milestone": null, "body": "Blocked by #185 until the guard ships."}
]
EOF

cat > "$work/issues-depends.json" <<'EOF'
[
  {"number": 192, "title": "Chained", "labels": ["feature"], "milestone": null, "body": "Depends on: #185\nThen we can start."}
]
EOF

cat > "$work/issues-backlog-reason.json" <<'EOF'
[
  {"number": 193, "title": "Parked", "labels": ["feature"], "milestone": null, "body": "Backlog: waiting on #188 policy"}
]
EOF

cat > "$work/issues-backlog-bare.json" <<'EOF'
[
  {"number": 194, "title": "Parked without a reason", "labels": ["feature"], "milestone": null, "body": "Backlog"}
]
EOF

# gh's raw object form: labels as {"name": …}, milestone as {"title": …}.
cat > "$work/issues-gh-form.json" <<'EOF'
[
  {"number": 179, "title": "Assigned", "labels": [{"name": "feature"}, {"name": "P2"}], "milestone": {"title": "v0.10 — Next train"}, "body": "Acceptance criteria here."}
]
EOF

cat > "$work/issues-gh-form-unassigned.json" <<'EOF'
[
  {"number": 195, "title": "Drifting idea", "labels": [{"name": "feature"}], "milestone": null, "body": "No decision recorded."}
]
EOF

# --- complete roadmap, every feature decided
check 0 "complete roadmap + decided features" \
  "$work/complete.md" "$work/issues-complete.json" \
  "roadmap-check: 0 gap(s)"

# --- feature with no milestone and no marker is the core gap
check 1 "unassigned feature is a gap" \
  "$work/complete.md" "$work/issues-unassigned.json" \
  "GAP: feature #190" "roadmap-check: 1 gap(s)"

# --- explicit blockers and backlog reasons are decisions, not gaps
check 0 "Blocked-by body classifies as blocked" \
  "$work/complete.md" "$work/issues-blocked.json" \
  "ok: feature #191" "roadmap-check: 0 gap(s)"
check 0 "Depends-on header classifies as blocked" \
  "$work/complete.md" "$work/issues-depends.json" \
  "ok: feature #192" "roadmap-check: 0 gap(s)"
check 0 "backlog line with rationale is a decision" \
  "$work/complete.md" "$work/issues-backlog-reason.json" \
  "ok: feature #193" "roadmap-check: 0 gap(s)"
check 1 "bare Backlog line without rationale is a gap" \
  "$work/complete.md" "$work/issues-backlog-bare.json" \
  "GAP: feature #194"

# --- roadmap shape gaps
check 1 "roadmap with only shipped sections lacks a next release" \
  "$work/shipped-only.md" "$work/issues-empty.json" \
  "GAP: roadmap names no next release"
check 1 "unshipped section without issue links is a gap" \
  "$work/no-links.md" "$work/issues-empty.json" \
  'GAP: roadmap section "v0.10' "roadmap-check: 1 gap(s)"
check 0 "unshipped section with a deferred marker passes" \
  "$work/deferred-marker.md" "$work/issues-empty.json" \
  "roadmap-check: 0 gap(s)"

# --- the marker must start a line: the word mid-sentence is not a decision
cat > "$work/issues-backlog-midsentence.json" <<'EOF'
[
  {"number": 197, "title": "Drifting", "labels": ["feature"], "milestone": null, "body": "Someone said do not let this rot in the backlog forever."}
]
EOF
check 1 "mid-sentence 'backlog' is not a decision" \
  "$work/complete.md" "$work/issues-backlog-midsentence.json" \
  "GAP: feature #197"

# --- corrupt issues JSON is a tool error (exit 2), never a clean pass
printf 'not json' > "$work/issues-corrupt.json"
check 2 "corrupt issues JSON exits 2" \
  "$work/complete.md" "$work/issues-corrupt.json"

# --- gh object form parses the same as the flattened form
check 0 "gh object-form labels/milestone parse as assigned" \
  "$work/complete.md" "$work/issues-gh-form.json" \
  "ok: feature #179" "roadmap-check: 0 gap(s)"
check 1 "gh object-form unassigned feature is a gap" \
  "$work/complete.md" "$work/issues-gh-form-unassigned.json" \
  "GAP: feature #195"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
