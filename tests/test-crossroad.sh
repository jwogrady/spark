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
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

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

# --- the load-bearing control: an INCOMPLETE or UNKNOWN input is INVALID -------
# (#696) A genuine boundary KIND with no named authority/surface must NOT report
# CONTINUE — that fail-open path let a machine caller run past a real boundary on
# an omitted argument. It also must not manufacture DECISION REQUIRED. It is
# INVALID (exit 2): halt until the claim is completed or the kind corrected.
verdict INVALID 2 "an unnamed new-authority claim is invalid, not CONTINUE"   new-authority
verdict INVALID 2 "a named authority without a cited surface is invalid" \
  new-authority "some authority"
verdict INVALID 2 "a cited surface without a named authority is invalid" \
  release-policy "" "#480 release gate"
# Whitespace is not a name (#691 review): a blank or all-space authority/surface
# is an incomplete claim → INVALID, never a stop and never a pass.
verdict INVALID 2 "all-whitespace authority AND surface are invalid" \
  new-authority " " "	"
verdict INVALID 2 "a whitespace-only authority with a real surface is invalid" \
  new-authority "   " "AGENTS.md guardrails"
verdict INVALID 2 "a real authority with a whitespace-only surface is invalid" \
  new-authority "a write-capable deploy key" "  "
# An unrecognised kind (a typo or an undeclared kind) cannot be classified → INVALID.
verdict INVALID 2 "an unrecognised stop kind is invalid"                made-up-reason
verdict INVALID 2 "a misspelled boundary kind is invalid, not CONTINUE" release_polcy
verdict INVALID 2 "an empty kind is invalid"                            ""
# A malformed argument count is invalid input, not a silent-ignore.
verdict INVALID 2 "extra positional arguments are invalid"              activate-authorized a b c
verdict INVALID 2 "extra args after a complete boundary are invalid" \
  new-authority "a deploy key" "AGENTS.md" "surplus"

# --- INVALID is distinct from CONTINUE and DECISION REQUIRED (#696) ------------
# The verdict, the exit code, and the reason must let a machine consumer tell a
# failed classification apart from a successful non-boundary CONTINUE.
case "$(xr_stop_check destructive-external 2>&1)" in
  *"NOT a pass and NOT CONTINUE"*"NOT a manufactured human handoff"*) ok ;;
  *) bad "an incomplete boundary must say it is neither a pass, a CONTINUE, nor a handoff" ;;
esac
case "$(xr_stop_check made-up-reason 2>&1)" in
  *"cannot evaluate it"*"NOT CONTINUE"*) ok ;;
  *) bad "an unknown kind must say the classifier cannot evaluate it and it is not CONTINUE" ;;
esac

# --- the reason text names the discipline, so a reader can act on it ----------
case "$(xr_stop_check activate-authorized)" in
  *"not an authority boundary"*) ok ;; *) bad "continue reason must explain why it is not a boundary" ;;
esac
# The incomplete-boundary reason names WHICH value is missing (#691 review), not a
# blanket "neither was given".
case "$(xr_stop_check new-authority 2>&1)" in
  *"missing a named authority and a cited surface"*) ok ;; *) bad "both-missing reason must say both are missing" ;;
esac
case "$(xr_stop_check new-authority "" "AGENTS.md" 2>&1)" in
  *"missing a named authority."*) ok ;; *) bad "authority-missing reason must name the authority" ;;
esac
case "$(xr_stop_check new-authority "a deploy key" "" 2>&1)" in
  *"missing a cited surface."*) ok ;; *) bad "surface-missing reason must name the surface" ;;
esac
case "$(xr_stop_check new-authority "deploy key" "AGENTS.md" 2>&1)" in
  *"reserved to the human by AGENTS.md"*) ok ;; *) bad "a real stop must cite the reserving surface" ;;
esac

# --- design boundary (#691 review): STRUCTURAL, not semantic -----------------
# The classifier requires a named authority AND a cited surface — turning an
# unfalsifiable "it felt consequential" stop into a claim a human can check. It
# cannot verify that the surface reserves the authority (no such mechanical
# oracle exists), so a structurally complete but arbitrary claim still stops, and
# the verdict presents it as a CLAIM to confirm — never an asserted verified fact.
verdict "DECISION REQUIRED" 3 "a structurally complete claim stops; substance is human-checked" \
  new-authority "an arbitrary named authority" "an arbitrary cited surface"
case "$(xr_stop_check new-authority "x" "y" 2>&1)" in
  *"cited as reserved"*"confirm the citation holds"*) ok ;;
  *) bad "the stop verdict must present the surface as a claim to confirm, not verified fact" ;;
esac

finish
