#!/usr/bin/env bash
# Regression tests for the plan skill's roadmap-completeness checker
# (plugins/spark/skills/plan/scripts/roadmap-check.sh). Fully offline: every
# case supplies its own --roadmap and --issues fixtures, so gh is never
# consulted and nothing touches the network.

set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/plugins/spark/skills/plan/scripts/roadmap-check.sh"
sparkbin="$(cd "$(dirname "$0")/.." && pwd)/plugins/spark/bin/spark"
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

**Status:** Planned

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
  {"number": 180, "title": "Backlogged", "labels": ["feature", "backlog"], "milestone": null, "body": "Backlog: waiting on #188 policy"},
  {"number": 181, "title": "Blocked", "labels": ["feature"], "milestone": "v0.10 — Next train", "body": "Blocked by #185"},
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
check 5 "unassigned feature awaits a human decision" \
  "$work/complete.md" "$work/issues-unassigned.json" \
  "DECISION REQUIRED: feature #190" "0 gap(s), 1 decision(s)" \
  "a recommendation is not authority"

# --- PROSE IS NOT AUTHORITY (#570). Each of these three spellings used to clear
# the gate on its own, so an agent could record a release decision by writing one
# sentence into an issue body. They are evidence now, and the message says so.
check 5 "a Blocked-by body is evidence, not a decision" \
  "$work/complete.md" "$work/issues-blocked.json" \
  "DECISION REQUIRED: feature #191" "proposes one in prose, which is evidence, not authority"
check 5 "a Depends-on header is evidence, not a decision" \
  "$work/complete.md" "$work/issues-depends.json" \
  "DECISION REQUIRED: feature #192" "evidence, not authority"
check 5 "a Backlog line with a rationale is evidence, not a decision" \
  "$work/complete.md" "$work/issues-backlog-reason.json" \
  "DECISION REQUIRED: feature #193" "evidence, not authority"
# ...and the message names the governed fields that WOULD record it, read from
# the model rather than spelled out here.
check 5 "and names the structured surfaces that carry authority" \
  "$work/complete.md" "$work/issues-backlog-reason.json" \
  "assign a milestone, or apply a disposition label (backlog)"
check 5 "bare Backlog line without rationale is still undecided" \
  "$work/complete.md" "$work/issues-backlog-bare.json" \
  "DECISION REQUIRED: feature #194"

# --- STRUCTURED POSITIVE CONTROLS: the two surfaces that DO carry authority.
# Without these the change could have been "reject everything", which would pass
# the negative cases and be useless.
cat > "$work/issues-lbl.json" <<'EOF'
[
  {"number": 900, "title": "Deferred", "labels": ["feature", "backlog"], "milestone": null, "body": "Deferred deliberately; revisit before v1."}
]
EOF
check 0 "a governed disposition label records the decision" \
  "$work/complete.md" "$work/issues-lbl.json" \
  "ok: feature #900 — carries a governed disposition label"

cat > "$work/issues-ms.json" <<'EOF'
[
  {"number": 901, "title": "Scheduled", "labels": ["feature"], "milestone": "v0.10 — Next train", "body": "No prose about disposition at all."}
]
EOF
check 0 "a milestone records the decision" \
  "$work/complete.md" "$work/issues-ms.json" \
  "ok: feature #901 — assigned to a milestone"

# A structured field wins even when the prose contradicts it: the prose was
# never consulted for the class, only for the message.
cat > "$work/issues-both.json" <<'EOF'
[
  {"number": 902, "title": "Both", "labels": ["feature", "backlog"], "milestone": null, "body": "Blocked pending a human decision about the next release."}
]
EOF
check 0 "a governed label clears it despite contradicting prose" \
  "$work/complete.md" "$work/issues-both.json" \
  "ok: feature #902"

# --- the exact reproductions from the report, verbatim
cat > "$work/issues-repro-backlog.json" <<'EOF'
[
  {"number": 999, "title": "Fixture", "labels": ["feature"], "milestone": null, "body": "Backlog: automated recommendation only; pending human approval."}
]
EOF
check 5 "the reported Backlog: recommendation no longer clears the gate" \
  "$work/complete.md" "$work/issues-repro-backlog.json" \
  "DECISION REQUIRED: feature #999"

cat > "$work/issues-repro-blocked.json" <<'EOF'
[
  {"number": 999, "title": "Fixture", "labels": ["feature"], "milestone": null, "body": "Blocked pending a human decision about the next release."}
]
EOF
check 5 "the reported Blocked-pending wording no longer clears the gate" \
  "$work/complete.md" "$work/issues-repro-blocked.json" \
  "DECISION REQUIRED: feature #999"

# A mechanical roadmap gap stays FAIL, not DECISION REQUIRED — the softer
# outcome must not swallow a contradiction anyone could correct.
check 1 "a mechanical roadmap gap is still exit 1" \
  "$work/no-links.md" "$work/issues-lbl.json" \
  'GAP: roadmap section "v0.10'

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

# --- #267: a Status outside the vocabulary is a gap.
cat > "$work/bad-status.md" <<'EOF'
# Roadmap

## v0.9 — Current train

**Status:** Shipped (`v0.9.0`)

Everything landed (#177).

## v0.10 — Next train

**Status:** Cooking

Prose referencing #188.
EOF
check 1 "status outside the vocabulary is a gap" \
  "$work/bad-status.md" "$work/issues-empty.json" \
  'is outside the vocabulary'

# --- `Blocked` is in the vocabulary. It was added because no existing term
# could describe a release whose certification had been withdrawn: Merged and
# Shipped overclaim, In progress reads as ordinary progress, and
# Deferred/Backlog say the work was chosen against. A check that exists to
# enforce truthfulness must not force an untruth.
cat > "$work/blocked-status.md" <<'EOF'
# Roadmap

## v0.9 — Current train

**Status:** Shipped (`v0.9.0`)

Everything landed (#177).

## v0.10 — Next train

**Status:** Blocked — certification withdrawn; repairs in progress.

Prose referencing #188.
EOF
check 0 "Blocked is a vocabulary status" \
  "$work/blocked-status.md" "$work/issues-empty.json" \
  'uses a vocabulary status'

# --- the marker must start a line: the word mid-sentence is not a decision
cat > "$work/issues-backlog-midsentence.json" <<'EOF'
[
  {"number": 197, "title": "Drifting", "labels": ["feature"], "milestone": null, "body": "Someone said do not let this rot in the backlog forever."}
]
EOF
check 5 "mid-sentence 'backlog' is not a decision" \
  "$work/complete.md" "$work/issues-backlog-midsentence.json" \
  "DECISION REQUIRED: feature #197"

# --- precedence: a mechanical gap outranks an owed decision (#559). A gap is
# correctable by anyone; a decision is not. If exit 5 won here, a real roadmap
# contradiction would be reported under the softer outcome and read as "waiting
# on the human" rather than "fix this".
check 1 "a roadmap gap outranks an owed decision" \
  "$work/no-links.md" "$work/issues-unassigned.json" \
  'GAP: roadmap section "v0.10' "DECISION REQUIRED: feature #190" \
  "1 gap(s), 1 decision(s)"

# --- jq and python3 must agree, because they are two implementations of one
# rule. Only one runs on any given machine, so a divergence hides until the
# other reader is the one installed — the failure mode is invisible by
# construction unless it is asserted directly.
nojq="$work/nojq"; mkdir -p "$nojq"
for t in bash env git awk sed grep find sort printf cat wc tr head cut date mktemp rm mkdir ls dirname basename python3; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$nojq/$t" 2>/dev/null || true
done
parity() {
  local desc="$1" issues="$2" a b ra=0 rb=0
  a="$(bash "$script" --roadmap "$work/complete.md" --issues "$issues" 2>&1)" || ra=$?
  b="$(env PATH="$nojq" bash "$script" --roadmap "$work/complete.md" --issues "$issues" 2>&1)" || rb=$?
  if [ "$ra" = "$rb" ] && [ "$a" = "$b" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "  ✖ $desc — jq exit $ra vs python exit $rb"
    diff <(echo "$a") <(echo "$b") | head -6 || true
  fi
}
if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  parity "jq and python agree on a prose backlog line"  "$work/issues-repro-backlog.json"
  parity "jq and python agree on blocked-pending prose" "$work/issues-repro-blocked.json"
  parity "jq and python agree on a governed label"      "$work/issues-lbl.json"
  parity "jq and python agree on a milestone"           "$work/issues-ms.json"
  parity "jq and python agree on the complete fixture"  "$work/issues-complete.json"
else
  pass=$((pass + 1))   # one reader present: parity is not observable here
fi

# --- the governed disposition family is what makes check C answerable. If it
# cannot be resolved, the run is NOT ASSESSED — never a guess, and never a pass.
# A hard-coded fallback would take over at exactly the moment the real authority
# was unusable, which is the substitution this codebase keeps finding.
lonely="$work/lonely/skills/plan/scripts"
mkdir -p "$lonely"
cp "$script" "$lonely/roadmap-check.sh"
rc=0; out="$(bash "$lonely/roadmap-check.sh" --roadmap "$work/complete.md" \
  --issues "$work/issues-lbl.json" 2>&1)" || rc=$?
if [ "$rc" -eq 3 ]; then pass=$((pass + 1)); else
  fail=$((fail + 1)); echo "  ✖ an unresolvable disposition family must exit 3, got $rc"; fi
case "$out" in
  *"disposition family could not be resolved"*) pass=$((pass + 1)) ;;
  *) fail=$((fail + 1)); echo "  ✖ and must say why it could not be assessed" ;;
esac
case "$out" in
  *"ok: feature"*) fail=$((fail + 1)); echo "  ✖ it must not clear an issue it could not classify" ;;
  *) pass=$((pass + 1)) ;;
esac

# --- MULTI-WORD DISPOSITION MEMBERS (#587) --------------------------------
# A GitHub label may contain spaces, and the model accepts one: `not planned` is
# an ordinary deferred disposition. Serialising the member list space-delimited
# split it in two, so an issue carrying exactly that governed label was still
# reported as having no release decision — the governed value resolved, could be
# provisioned, and still produced a false DECISION REQUIRED.
#
# This runs in its own repository because the member has to come from a real
# project-tier model rather than from a fixture the checker never reads.
mw="$work/multiword"
mkdir -p "$mw/.spark"
git -C "$mw" init -q
printf 'version\t1\nmember\tdisposition\tnot planned\tabcdef\tA valid multi-word deferred disposition\n' \
  > "$mw/.spark/governance.tsv"
cp "$work/complete.md" "$mw/ROADMAP.md"
cat > "$mw/carries.json" <<'EOF'
[
  {"number": 900, "title": "Deferred", "labels": ["feature", "not planned"], "milestone": null, "body": "Deliberately not planned."}
]
EOF
cat > "$mw/without.json" <<'EOF'
[
  {"number": 901, "title": "Undecided", "labels": ["feature"], "milestone": null, "body": "No decision recorded."}
]
EOF

# The fixture is only meaningful if the member really resolved with its space
# intact. Asserted before anything is concluded from it.
members="$(cd "$mw" && "$sparkbin" governance --tsv 2>/dev/null \
  | awk -F'\t' '$1 == "member" && $2 == "disposition" { print $3 }')"
case "$members" in
  *"not planned"*) pass=$((pass + 1)) ;;
  *) fail=$((fail + 1)); echo "  ✖ the multi-word member did not resolve; the case proves nothing" ;;
esac

mwcheck() { # <want-exit> <desc> <issues> <needle>
  local want="$1" desc="$2" issues="$3" needle="$4" out rc=0
  out="$(cd "$mw" && bash "$script" --roadmap "$mw/ROADMAP.md" --issues "$issues" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail=$((fail + 1)); echo "  ✖ $desc — want exit $want, got $rc"; return 0
  fi
  case "$out" in
    *"$needle"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "  ✖ $desc — output lacks '$needle'" ;;
  esac
}
mwcheck 0 "an issue carrying a multi-word governed label is decided" \
  "$mw/carries.json" "ok: feature #900 — carries a governed disposition label"
mwcheck 5 "and one without it still owes a decision" \
  "$mw/without.json" "DECISION REQUIRED: feature #901"
# The member is offered back to the human whole, not shredded into two words.
mwcheck 5 "the message names the member intact" \
  "$mw/without.json" "disposition label (not planned)"

# Both readers must agree on the boundary: the defect lived in two independent
# split() calls, so fixing one would have left the other wrong on whichever
# machine had the other reader.
if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  a="$(cd "$mw" && bash "$script" --roadmap "$mw/ROADMAP.md" --issues "$mw/carries.json" 2>&1)" || true
  b="$(cd "$mw" && env PATH="$nojq" bash "$script" --roadmap "$mw/ROADMAP.md" --issues "$mw/carries.json" 2>&1)" || true
  if [ "$a" = "$b" ]; then pass=$((pass + 1)); else
    fail=$((fail + 1)); echo "  ✖ jq and python disagree on a multi-word member"
    diff <(echo "$a") <(echo "$b") | head -4 || true
  fi
else
  pass=$((pass + 1))
fi

# --- corrupt issues JSON is a tool error (exit 2), never a clean pass
printf 'not json' > "$work/issues-corrupt.json"
check 2 "corrupt issues JSON exits 2" \
  "$work/complete.md" "$work/issues-corrupt.json"

# --- gh object form parses the same as the flattened form
check 0 "gh object-form labels/milestone parse as assigned" \
  "$work/complete.md" "$work/issues-gh-form.json" \
  "ok: feature #179" "roadmap-check: 0 gap(s)"
check 5 "gh object-form unassigned feature awaits a decision" \
  "$work/complete.md" "$work/issues-gh-form-unassigned.json" \
  "DECISION REQUIRED: feature #195"

# --- assessed with zero open features is a clean pass (distinct from #224's
# "not assessed"): the inventory WAS evaluated and found no features.
check 0 "assessed-but-no-features is a clean pass" \
  "$work/complete.md" "$work/issues-empty.json" \
  "no open feature issues to assess" "roadmap-check: 0 gap(s)"

# --- #224: when the inventory cannot be assessed (no --issues and gh
# missing/failing), the checker must NOT emit a clean pass — exit 3, never 0.
# Build restricted PATHs: one with the real tools but no gh, one with a failing
# gh, so `command -v gh` takes each not-assessed branch.
mk_bin() {
  local d="$1"; mkdir -p "$d"; local t s
  for t in bash sh env awk sed grep cat mktemp rm rmdir sort head tr git find dirname basename wc jq python3; do
    s="$(command -v "$t" 2>/dev/null || true)"; [ -n "$s" ] && ln -sf "$s" "$d/$t"
  done
}
nogh="$work/nogh-bin"; mk_bin "$nogh"
failgh="$work/failgh-bin"; mk_bin "$failgh"
printf '#!/usr/bin/env bash\necho "gh: could not authenticate" >&2\nexit 1\n' > "$failgh/gh"
chmod +x "$failgh/gh"

# no gh at all, no --issues, structurally complete roadmap → exit 3, not 0.
rc=0; out="$(env PATH="$nogh" bash "$script" --roadmap "$work/complete.md" 2>&1)" || rc=$?
if [ "$rc" -eq 3 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "  ✖ #224 no gh + no --issues — want exit 3, got $rc"; fi
case "$out" in *"NOT assessed"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "  ✖ #224 no-gh must report NOT assessed" ;; esac
case "$out" in *"roadmap-check: 0 gap(s)"*) case "$rc" in 0) fail=$((fail + 1)); echo "  ✖ #224 no-gh printed a clean pass" ;; *) pass=$((pass + 1)) ;; esac ;; *) pass=$((pass + 1)) ;; esac

# gh present but failing (offline/unauthenticated) → also exit 3.
rc=0; out="$(env PATH="$failgh" bash "$script" --roadmap "$work/complete.md" 2>&1)" || rc=$?
if [ "$rc" -eq 3 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "  ✖ #224 failing gh — want exit 3, got $rc"; fi
case "$out" in *"NOT assessed"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "  ✖ #224 failing-gh must report NOT assessed" ;; esac

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
