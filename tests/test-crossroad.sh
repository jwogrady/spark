#!/usr/bin/env bash
# Behavioral tests for Crossroad classification (#690).
#
# The defect: PR #688 implemented the already-authorized #584 reviewer lane, had
# all exact-HEAD evidence green and an independent CONFIRMED-CORRECT review, and
# the agent still manufactured a human handoff — citing "activates a new
# authority", "the bootstrap could not self-review", and "you co-authored it".
# None of those is a reserved authority. The classifier must CONTINUE there, and
# still STOP for a genuinely reserved authority that is named with its surface.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/../plugins/spark/lib/execution.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

echo "Crossroad classification (#690)"

bash -n "$here/../plugins/spark/lib/execution.sh" && ok || bad "bash -n execution.sh"

# verdict <want-verdict> <want-rc> <desc> <args...>
verdict() {
  local want="$1" wrc="$2" desc="$3"; shift 3
  local out rc=0
  out="$(xr_stop_check "$@" 2>&1)" || rc=$?
  local got; got="$(printf '%s\n' "$out" | head -1)"
  if [ "$got" != "$want" ]; then bad "$desc — want verdict '$want' got '$got'"; return 0; fi
  if [ "$rc" != "$wrc" ]; then bad "$desc — want rc $wrc got $rc"; return 0; fi
  ok
}

# --- the #688 bootstrap scenario: every reason the agent gave must CONTINUE ---
# Activating a capability the owning issue (#584) already authorized is not a new
# authority grant merely because it goes live on merge.
verdict CONTINUE 0 "activating already-authorized capability continues" activate-authorized
# The bootstrap could not self-review; an independent exact-HEAD review stood in.
# That is an evidence/verification question, not a governance decision.
verdict CONTINUE 0 "evidence substitution continues"                    evidence-substitution
# The three social reasons that manufactured the #688 stop:
verdict CONTINUE 0 "co-authorship is not authority"                     co-authorship
verdict CONTINUE 0 "operator courtesy is not authority"                 operator-courtesy
verdict CONTINUE 0 "perceived presumptuousness is not authority"        presumptuousness
verdict CONTINUE 0 "general consequentiality is not authority"          consequentiality
verdict CONTINUE 0 "general caution is not authority"                   general-caution

# --- genuine boundaries STILL stop, but only when NAMED with a surface --------
verdict "DECISION REQUIRED" 3 "a new authority grant stops" \
  new-authority "a write-capable deploy key" "AGENTS.md GitHub Integration Guardrails"
verdict "DECISION REQUIRED" 3 "human-owned release policy stops" \
  release-policy "v0.23 release approval" "#480 release gate"
verdict "DECISION REQUIRED" 3 "a destructive/irreversible external action stops" \
  destructive-external "force-push to master" "AGENTS.md Destructive Changes"
verdict "DECISION REQUIRED" 3 "a materially new product/governance semantic stops" \
  product-governance-semantics "a new automated reviewer authority model" "an ADR"
verdict "DECISION REQUIRED" 3 "a durable DECISION REQUIRED stops" \
  decision-required "milestone/priority placement" "#677 standing orchestration"

# --- the load-bearing control: you must NAME the authority before stopping -----
# A genuine boundary KIND with no named authority/surface must NOT manufacture a
# stop — it continues. This is exactly the discipline #688 lacked.
verdict CONTINUE 0 "an unnamed new-authority claim does not stop"       new-authority
verdict CONTINUE 0 "a named authority without a cited surface does not stop" \
  new-authority "some authority"
# Whitespace is not a name (#691 review): a blank or all-space authority/surface
# must not pose as named and manufacture a stop.
verdict CONTINUE 0 "all-whitespace authority AND surface do not stop" \
  new-authority " " "	"
verdict CONTINUE 0 "a whitespace-only authority with a real surface does not stop" \
  new-authority "   " "AGENTS.md guardrails"
verdict CONTINUE 0 "a real authority with a whitespace-only surface does not stop" \
  new-authority "a write-capable deploy key" "  "
# An unrecognised reason never invents a Crossroad.
verdict CONTINUE 0 "an unrecognised stop reason continues"              made-up-reason
verdict CONTINUE 0 "an empty reason continues"                          ""

# --- the reason text names the discipline, so a reader can act on it ----------
case "$(xr_stop_check activate-authorized)" in
  *"not an authority boundary"*) ok ;; *) bad "continue reason must explain why it is not a boundary" ;;
esac
case "$(xr_stop_check new-authority 2>&1)" in
  *"must NAME the specific missing human authority"*) ok ;; *) bad "unnamed-boundary reason must demand naming" ;;
esac
case "$(xr_stop_check new-authority "deploy key" "AGENTS.md" 2>&1)" in
  *"reserved to the human by AGENTS.md"*) ok ;; *) bad "a real stop must cite the reserving surface" ;;
esac

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
