#!/usr/bin/env bash
# Behavioural suite for #515: an update target is validated before any call.
#
# The `update` validator carried its own `'#'*` test, which accepts ANY string
# beginning with '#'. So `#abc` validated locally, and because creates and
# milestone creates execute before updates, `apply --yes` created remote state
# and only then failed on a target that was deterministically invalid all along —
# breaking the compiler's "validate everything before any call" guarantee and
# leaving a partial run for the operator to reconcile.
#
# `#0` was accepted by the canonical `im_ref_ok` too: a valid digit string, never
# a valid issue.
#
# Measured discrimination, not asserted. Of the 40 assertions: restoring the
# `'#'*` test turns 15 red — including `spark plan validate` reporting PASS and
# the live run making a call before it failed, which is the reported symptom
# exactly — and restoring the zero-permitting canonical rule turns 5.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
SCRIPT="$WORK/plugin/skills/plan/scripts/issue-manifest.sh"
. "$SCRIPT" 2>/dev/null || true   # sourced for the pure predicates
set +e

work="$WORK/w"; mkdir -p "$work"
echo body > "$work/child.md"

# man <target> — a manifest with a valid create followed by one update record.
man() {
  local f="$work/m.tsv"
  { printf 'issue\tA\tCreated before the malformed update\tfeature,P1,docs-impact:none\t\tchild.md\n'
    printf 'update\t%s\ttitle\tThis target is not an issue number\n' "$1"
  } > "$f"
  printf '%s' "$f"
}

# ============ the predicate is one rule ====================================
# Every record type that names an issue must agree, because the whole defect was
# a second implementation of "#N" that agreed with nothing.
for good in '#1' '#42' '#007' '#100000'; do
  im_issue_ref_ok "$good" && ok || bad "$good should be a valid issue reference"
done
for bad_ref in '#' '#abc' '#1a' '#a1' '#-1' '#+1' '#0' '#00' '# 1' '#1 ' '1' 'KEY' ''; do
  im_issue_ref_ok "$bad_ref" && bad "'$bad_ref' should be rejected" || ok
done

# The canonical ref check must now refuse zero too, not just the update path.
# Built as a literal: $(...) strips the trailing newline the fence needs.
keys=$'\nSOMEKEY\n'
im_ref_ok '#0' "$keys" && bad "im_ref_ok must reject #0" || ok
im_ref_ok '#5' "$keys" && ok || bad "im_ref_ok must accept #5"
im_ref_ok 'SOMEKEY' "$keys" && ok || bad "im_ref_ok must still accept a declared key"

# ============ validation rejects each malformed target =====================
# Precise, per the acceptance criteria: empty, nonnumeric, signed, and zero.
for t in '#abc' '#' '#0' '#-3' '#+3'; do
  rc=0; out="$(im_validate "$(man "$t")" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then ok; else bad "validation accepted the update target '$t'"; fi
  case "$out" in
    *"update targets '$t'"*) ok ;;
    *) bad "the error for '$t' does not name the target: $out" ;;
  esac
done
# ...and a well-formed one still validates, or the rejections above prove nothing.
rc=0; out="$(im_validate "$(man '#12')" 2>&1)" || rc=$?
assert_rc "a valid update target still validates" 0 "$rc"

# ============ spark plan validate agrees with the helper ===================
# One rejection, two entry points: the verb an operator runs and the helper's own
# validation must not disagree about what is valid.
rc=0; vout="$("$SPARK" plan validate "$(man '#abc')" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "spark plan validate accepted '#abc'"; fi
case "$vout" in
  *PASS*) bad "#515: spark plan validate reported PASS for a malformed update target" ;;
  *) ok ;;
esac
assert_contains "and names the malformed target" "#abc" "$vout"
rc=0; vout="$("$SPARK" plan validate "$(man '#12')" 2>&1)" || rc=$?
assert_rc "while a valid artifact still passes the verb" 0 "$rc"

# ============ a live run makes ZERO calls ==================================
# The criterion that matters most. Creates execute before updates, so the old
# behaviour created remote state and THEN failed. The stub records every
# invocation; the file must stay empty.
calls="$work/gh-calls"
: > "$calls"
stub="$work/stub"; mkdir -p "$stub"
cat > "$stub/gh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$calls"
case "\$1" in
  auth) exit 0 ;;
  api)  printf '%s\n' "1"; exit 0 ;;
esac
exit 0
STUB
chmod +x "$stub/gh"

rc=0
out="$(cd "$work" && PATH="$stub:$PATH" bash "$SCRIPT" --state "$work/live.state" \
  "$(man '#abc')" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "a live run with a malformed update target succeeded"; fi
n="$(grep -c . "$calls" || true)"
assert_eq "a live run makes ZERO gh calls when validation fails" 0 "$n"
case "$out" in
  *invalid*) ok ;;
  *) bad "the live run did not report the validation failure: $out" ;;
esac
# No state file either: a run that contacted nothing has nothing to resume.
if [ -f "$work/live.state" ]; then
  bad "a run that made no calls still wrote resume state"
else ok; fi

# The negative control: the same stub DOES get called when the artifact is valid,
# or the zero-call assertion above would pass for the wrong reason.
: > "$calls"
rc=0
out="$(cd "$work" && PATH="$stub:$PATH" bash "$SCRIPT" --state "$work/live2.state" \
  "$(man '#12')" 2>&1)" || rc=$?
n="$(grep -c . "$calls" || true)"
if [ "$n" -gt 0 ]; then ok; else bad "the stub was never called even for a VALID artifact — the zero-call test is vacuous"; fi

finish
