#!/usr/bin/env bash
# Behavioral tests for release-plan-check.sh (issue #380): red/green fixture
# coverage for the banned claim class (a durable release plan carrying a
# transient environment-capability claim), the positive milestone-authority
# requirement, fail-closed behavior on an empty or unreadable scan, and the
# live repo's own release docs passing. The red fixtures include the actual
# paragraph v0.16.2 shipped, so the guard is proven against the real defect,
# not a synthetic one.

set -euo pipefail
. "$(dirname "$0")/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"
check="$root/plugins/spark/skills/plan/scripts/release-plan-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

bash -n "$check" && ok || bad "bash -n release-plan-check.sh"

# run <want-exit> <desc> <dir> [needle ...]
run() {
  local want="$1" desc="$2" dir="$3"; shift 3
  local out rc=0 needle
  out="$(bash "$check" --dir "$dir" 2>&1)" || rc=$?
  [ "$rc" -eq "$want" ] || { bad "$desc — want exit $want, got $rc: $out"; return 0; }
  for needle in "$@"; do
    case "$out" in *"$needle"*) ;; *) bad "$desc — output lacks '$needle'"; return 0 ;; esac
  done
  ok
}

# --- red: the paragraph v0.16.2 actually shipped (verbatim) is caught
d="$work/shipped-defect"; mkdir -p "$d"
cat > "$d/v0.17-plan.md" <<'EOF'
# v0.17.0 — Provenance promotion

## Planning limitation

The intended GitHub milestone is **`v0.17 — Provenance promotion`**. The planning environment used for this pass can assign an existing milestone but does not expose milestone creation, so #373–#377 carry the version intent until the milestone object is created through a capable GitHub client.
EOF
run 1 "the v0.16.2 defect is caught" "$d" "planning limitation" "GAP"

# --- red: reworded unavailability claims (no banned term, different phrasing)
d="$work/reworded"; mkdir -p "$d"
printf '# v0.18 plan\n\nmilestone #15 is the authority.\nWe were unable to create a milestone; milestone creation is not available.\n' > "$d/v0.18-plan.md"
run 1 "reworded unavailability is caught" "$d" "unavailable/uncreated"

d="$work/notyet"; mkdir -p "$d"
printf '# plan\n\nWork rides milestone #9.\nThe milestone #9 has not been created yet.\n' > "$d/v0.19-plan.md"
run 1 "'not been created yet' is caught" "$d" "unavailable/uncreated"

# --- red: the banned section in other dress — h1, no-space heading, bold
d="$work/dress"; mkdir -p "$d"
printf '# Planning limitation\n\nmilestone #3 exists.\n' > "$d/a-plan.md"
run 1 "h1 'Planning limitation' is caught" "$d" "planning limitation"
printf '**Planning limitation** — tooling note.\n\nmilestone #3 exists.\n' > "$d/a-plan.md"
run 1 "bold 'Planning limitation' is caught" "$d" "planning limitation"

# --- red: a plan with no concrete milestone record
d="$work/nomilestone"; mkdir -p "$d"
printf '# v0.20 plan\n\nScope: issues #1 and #2.\n' > "$d/v0.20-plan.md"
run 1 "plan without milestone #N is caught" "$d" "names no concrete GitHub milestone"

# --- red: '**Milestone:** TBD' does not satisfy the authority requirement
printf '# v0.20 plan\n\n**Milestone:** TBD\n' > "$d/v0.20-plan.md"
run 1 "'Milestone: TBD' is not an authority record" "$d" "names no concrete GitHub milestone"

# --- green: a clean plan naming its milestone
d="$work/clean"; mkdir -p "$d"
printf '# v0.21 plan\n\nGitHub milestone #21 is the version authority.\nScope: #1, #2.\n' > "$d/v0.21-plan.md"
run 0 "clean plan passes" "$d" "0 gaps"

# --- green: a non-plan release record needs no milestone line, but is still
# scanned for the banned class
printf '# v0.9 launch record\n\nShipped as v0.9.0.\n' > "$d/v0.9.md"
run 0 "historical record without milestone line passes" "$d" "2 doc(s) scanned"
printf '# v0.9 launch record\n\nA planning limitation kept the milestone uncreated.\n' > "$d/v0.9.md"
run 1 "banned class caught in non-plan release docs too" "$d" "v0.9.md"
rm -f "$d/v0.9.md"

# --- fail-closed: nothing to scan is never a clean pass
d="$work/empty"; mkdir -p "$d"
run 2 "empty releases dir is not assessed" "$d" "not assessed"
ln -s "$work/missing-target" "$d/z-plan.md"
run 2 "a dangling symlink alone is not assessed" "$d" "not assessed"
run 2 "missing dir is not assessed" "$work/does-not-exist" "not assessed"

# --- the live repo's own release docs pass the guard
run 0 "live docs/releases passes" "$root/docs/releases" "0 gaps"

finish
