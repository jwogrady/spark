#!/usr/bin/env bash
# Behavioral suite for the verdict layer's authority boundary (#559).
#
# The defect this suite locks shut: `spark governance validate` reported every
# `!` row as "mechanically invalid governance state" — false by the row
# alphabet's own legend — and offered exactly three outcomes, none of which
# meant "a human must decide this". With no such outcome the cheapest route
# from a red gate to a green one was for the agent to write the judgment
# itself. That is the #558 incident: Spark correctly reported that #558 had no
# release decision, and the agent added `backlog` and `P3` so certification
# could continue.
#
# Two properties are asserted here, and they pull in opposite directions:
#
#   1. an owed human decision is DECISION REQUIRED, never a mechanical failure,
#      and it does NOT clear because an agent recommended a value;
#   2. genuinely mechanical work stays mechanical — a hard failure where it is
#      broken, and still create-only repairable where Spark has authority. The
#      fix must not turn every governance gap into a human prompt.
#
# Offline throughout: the row generators are pure functions driven from
# fixtures, and the two end-to-end paths (`plan validate`, `roadmap-check`) both
# work from files. gh is never consulted.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # gov_judgment_rows / gov_mechanical_rows (source-guarded)

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

model="$(resolve_governance)"

# count <rows> — how many non-empty rows, so "none" is distinguishable from
# "one blank line", which is what an unquoted printf leaves behind.
count() { printf '%s\n' "$1" | awk 'NF' | wc -l | tr -d ' '; }

# ============ 1. the partition over `!` is total and exclusive ============
# Every `!` row lands in exactly one class. If a row could land in both, two
# consumers could disagree about whether a gap is broken state or an owed
# decision; if it could land in neither, a real finding would vanish from every
# verdict. Both failures are silent, so they are asserted directly.
rows="$(printf '%s\n' \
  "$(printf 'metadata\t!\t#1\tcategory is required and none is declared')" \
  "$(printf 'file\t!\t.github/ISSUE_TEMPLATE\tnone of its declared paths exists')" \
  "$(printf 'dependency\t!\ta cycle\tthese issues cannot be started in any order')" \
  "$(printf 'plan\t!\tkey\tlabel "nope" is not declared by any governed family')" \
  "$(printf 'invented\t!\tx\ta surface nobody has classified yet')" \
  "$(printf 'label\t+\tP1\twould be created')" \
  "$(printf 'label\t~\tfeature\tcolour differs')" \
  "$(printf 'ruleset\t>\ttrunk\tdeferred')" \
  "$(printf 'metadata\t?\t#2\tcould not be read')" \
  "$(printf 'metadata\t=\t#3\tevery declared invariant holds')")"

judg="$(gov_judgment_rows "$rows")"
mech="$(gov_mechanical_rows "$rows")"

nbang="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "!" && NF' | wc -l | tr -d ' ')"
assert_rc "the fixture carries five judgment-or-mechanical rows" 5 "$nbang"
assert_rc "the partition covers every ! row" "$nbang" \
  "$(( $(count "$judg") + $(count "$mech") ))"

# Exclusivity: no row appears in both halves.
both="$(printf '%s\n%s\n' "$judg" "$mech" | awk 'NF' | sort | uniq -d)"
if [ -z "$both" ]; then ok; else bad "a row is both judgment and mechanical: $both"; fi

# Non-`!` statuses belong to neither. In particular a `+` row is Spark's own
# create-only authority: if the fix swept those into "ask the human" it would
# have over-gated exactly the mechanical work it must leave alone.
for st in '+' '~' '>' '?' '='; do
  case "$judg$mech" in
    *"$(printf '\t%s\t' "$st")"*) bad "a '$st' row leaked into the ! partition" ;;
    *) ok ;;
  esac
done

# ============ 2. each emitting surface is classified deliberately ============
# The classes below are the whole contract, so they are asserted per surface
# rather than inferred from the complement. `metadata` and `file` name values
# only a human may choose; a `dependency` cycle is impossible whoever looks at
# it; a `plan` artifact is an unapproved draft anyone may correct.
cls() {
  local row="$1"
  if [ -n "$(gov_judgment_rows "$row")" ]; then echo judgment
  elif [ -n "$(gov_mechanical_rows "$row")" ]; then echo mechanical
  else echo unclassified; fi
}
assert_eq_s() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}
assert_eq_s "a live-issue metadata gap is judgment" judgment \
  "$(cls "$(printf 'metadata\t!\t#1\tdocs-impact is required and none is declared')")"
assert_eq_s "an absent human-provisioned surface is judgment" judgment \
  "$(cls "$(printf 'file\t!\t.github/ISSUE_TEMPLATE\thuman-provisions')")"
assert_eq_s "a dependency cycle is mechanical" mechanical \
  "$(cls "$(printf 'dependency\t!\ta cycle\tcannot be started in any order')")"
assert_eq_s "an unapproved plan artifact is mechanical" mechanical \
  "$(cls "$(printf 'plan\t!\tk\tlabel is not declared by any governed family')")"
# Fail closed: an unrecognised surface must not soften a gate into "ask the
# human and continue". A new `!` producer is a hard failure until someone
# classifies it on purpose.
assert_eq_s "an unclassified surface fails closed as mechanical" mechanical \
  "$(cls "$(printf 'invented\t!\tx\tnobody has classified this yet')")"

# ============ 3. the #558 reproduction, three states ============
# Driven through roadmap-check, the surface where the incident happened. All
# three states use the same feature issue; only the recorded decision changes.
rc_script="$WORK/plugin/skills/plan/scripts/roadmap-check.sh"
cat > "$WORK/roadmap.md" <<'EOF'
# Roadmap

## v0.9 — Current

**Status:** Shipped (`v0.9.0`)

Tracks #100.

## v0.10 — Next

**Status:** Planned — see #101.
EOF

# check_rc <want> <desc> <issues-file> [needle ...]
check_rc() {
  local want="$1" desc="$2" issues="$3"; shift 3
  local out rc=0 needle
  out="$(bash "$rc_script" --roadmap "$WORK/roadmap.md" --issues "$issues" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    bad "$desc — want exit $want, got $rc"; return 0
  fi
  for needle in "$@"; do
    case "$out" in
      *"$needle"*) ;;
      *) bad "$desc — output lacks '$needle'"; return 0 ;;
    esac
  done
  ok
}

# State 1 — an unresolved feature. This is #558 as filed: open, no milestone,
# no disposition, no priority.
cat > "$WORK/s1.json" <<'EOF'
[
  {"number": 558, "title": "Bound autonomous runs with explicit convergence and verification budgets",
   "labels": ["feature"], "milestone": null,
   "body": "Autonomous runs need a convergence budget. No release decision has been made."}
]
EOF
check_rc 5 "state 1: an unresolved feature is DECISION REQUIRED" "$WORK/s1.json" \
  "DECISION REQUIRED: feature #558" "a recommendation is not authority"

# State 2 — the agent recommends, with evidence, in the issue body. The gap
# must NOT clear. This is the precise failure #559 names: the agent may propose
# `backlog`, but proposing it is not deciding it. Note the body contains the
# word "backlog" and even names a priority; neither is a recorded decision,
# because a decision lives in the governed field, not in prose.
cat > "$WORK/s2.json" <<'EOF'
[
  {"number": 558, "title": "Bound autonomous runs with explicit convergence and verification budgets",
   "labels": ["feature"], "milestone": null,
   "body": "Recommendation from an automated run: backlog at P3, since it does not falsify a v0.21 guarantee. Evidence: the milestone closed without it. Proposed only — pending human approval."}
]
EOF
check_rc 5 "state 2: an agent recommendation alone leaves it unresolved" "$WORK/s2.json" \
  "DECISION REQUIRED: feature #558"

# State 2b — the recommendation names a milestone in prose. A milestone is a
# field; naming one in a sentence is not assigning it.
cat > "$WORK/s2b.json" <<'EOF'
[
  {"number": 558, "title": "Bound autonomous runs", "labels": ["feature"], "milestone": null,
   "body": "I recommend assigning this to milestone v0.24 and marking it backlog if you disagree."}
]
EOF
check_rc 5 "state 2b: a milestone named in prose is not an assignment" "$WORK/s2b.json" \
  "DECISION REQUIRED: feature #558"

# State 3a — the human records the decision as a label. The check now passes,
# and deterministic consumers may use the value normally.
cat > "$WORK/s3a.json" <<'EOF'
[
  {"number": 558, "title": "Bound autonomous runs", "labels": ["feature", "backlog"],
   "milestone": null, "body": "Deferred deliberately; revisit before v1."}
]
EOF
check_rc 0 "state 3a: a human-recorded backlog label resolves it" "$WORK/s3a.json" \
  "ok: feature #558" "0 gap(s), 0 decision(s)"

# State 3b — or as a milestone. Either is authority; both clear the gap.
cat > "$WORK/s3b.json" <<'EOF'
[
  {"number": 558, "title": "Bound autonomous runs", "labels": ["feature"],
   "milestone": "v0.24 — Thin agent skills", "body": "Scheduled."}
]
EOF
check_rc 0 "state 3b: a human-assigned milestone resolves it" "$WORK/s3b.json" \
  "ok: feature #558"

# ============ 4. the negative control ============
# The fix must not over-gate. Mechanical work stays mechanical: a hard failure
# where the state is wrong, and untouched where Spark already has authority.

# 4a — a mechanical roadmap gap is exit 1, not 5, even though a human must
# eventually type the fix. "Needs a human's hands" is not "needs a human's
# authority": anyone may add a missing issue link.
cat > "$WORK/no-links.md" <<'EOF'
# Roadmap

## v0.9 — Current

**Status:** Shipped (`v0.9.0`)

Tracks #100.

## v0.10 — Next

**Status:** Planned
EOF
cat > "$WORK/empty.json" <<'EOF'
[]
EOF
rc=0; out="$(bash "$rc_script" --roadmap "$WORK/no-links.md" --issues "$WORK/empty.json" 2>&1)" || rc=$?
assert_rc "a mechanical roadmap gap is still a hard gap" 1 "$rc"
assert_contains "and is labelled a gap, not a decision" "GAP: roadmap section" "$out"

# 4b — a `+` row is Spark's own create-only authority and must remain outside
# the judgment partition, so provisioning is never blocked on a human decision.
plus="$(printf 'label\t+\tP1\twould be created #d93f0b')"
assert_eq_s "a provisionable label is neither judgment nor mechanical" unclassified \
  "$(cls "$plus")"

# 4c — and it is actually still create-only through the verb, with no human
# gate introduced. Offline, so the label surface reports NOT ASSESSED rather
# than creating anything; what matters is that the refusal is about the unread
# surface, not about an owed decision.
rc=0; out="$("$SPARK" governance apply --yes 2>&1)" || rc=$?
case "$out" in
  *"DECISION REQUIRED"*) bad "apply must not gate create-only work on a decision" ;;
  *) ok ;;
esac

# 4d — an unapproved plan artifact that contradicts the schema is a hard
# failure, not a decision. Correcting a draft needs no authority over live
# state, and softening this would let a typo'd label read as "waiting on you".
cat > "$WORK/bad-plan.tsv" <<'EOF'
issue	k1	A title	nope-not-a-label	body
EOF
rc=0; out="$("$SPARK" plan validate "$WORK/bad-plan.tsv" 2>&1)" || rc=$?
case "$rc" in
  5) bad "an unapproved draft artifact must not report DECISION REQUIRED" ;;
  0) bad "a plan artifact declaring an ungoverned label must not validate" ;;
  *) ok ;;
esac

# ============ 5. the verdict never invents the decision ============
# The report must present the admissible SET and stop. Two things are asserted:
# the set comes from the model, and the output says in words that a
# recommendation is not authority — the sentence an autonomous run reads before
# it reaches for the label.
adm="$(gov_admissible "$model")"
assert_contains "the admissible set names the disposition family" "disposition" "$adm"
assert_contains "and its declared member" "backlog" "$adm"
assert_contains "and the priority family" "P0 P1 P2 P3" "$adm"
# It must not RANK them or mark one as the default — a recommendation smuggled
# into the choice set is still a recommendation.
for w in recommend suggest default "probably" "likely"; do
  case "$adm" in
    *"$w"*) bad "the admissible set editorialises with '$w'" ;;
    *) ok ;;
  esac
done

# And validate's own output carries the boundary in prose, where the operator
# and the next autonomous run both read it.
rc=0; out="$("$SPARK" governance validate 2>&1)" || rc=$?
assert_contains "validate states the authority boundary" \
  "A recommendation is not authority" "$out"
assert_contains "and says what would actually clear it" \
  "the governed field itself carries" "$out"

finish
