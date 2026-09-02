# Canonical decisions for the OpenAI reviewer lane (#584).
#
# One producer per fact. The workflow steps and the behavioural suite both
# source THIS file, so a rule proven by a test is the rule the runner enforces.
#
# Every function here is pure: its result is a function of its arguments and
# stdin only — no network, no gh, no git, no ambient state. That is what lets a
# synthetic-input fixture prove the real control rather than a proxy for it.
#
# Source, don't execute.

ORL_MARKER_TAG="spark-openai-review"
ORL_RESERVATION_TAG="spark-openai-review-reservation"
ORL_TRUSTED_LOGIN="github-actions[bot]"
ORL_TRUSTED_APP="github-actions"

# The verdict vocabulary is closed. Anything outside it is NOT ASSESSED.
orl_normalize_verdict() { # [raw-first-line] -> normalized verdict
  local raw v
  if [ "$#" -gt 0 ]; then raw="$1"; else IFS= read -r raw || raw=""; fi
  v="$(printf '%s' "$raw" | tr -d '\r' | sed -E 's/[^A-Za-z ].*$//; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
  case "$v" in
    PASS|"CHANGES REQUIRED"|"DECISION REQUIRED"|"NOT ASSESSED") printf '%s' "$v" ;;
    *) printf 'NOT ASSESSED' ;;
  esac
}

# Read closing issue references only from PR prose; a bare #123 is not a contract.
orl_closing_issues() { # stdin: pr text -> issue numbers, one per line, sorted unique
  { grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?) #[0-9]+' || true; } \
    | { grep -oE '[0-9]+' || true; } | sort -un
}

# Final machine-readable verdict evidence consumed by #585.
orl_marker() { # verdict pr head_sha
  printf '<!-- %s pr=%s head=%s verdict=%s -->' "$ORL_MARKER_TAG" "$2" "$3" "$1"
}

# Durable pre-invocation claim. It is posted before the model call so a duplicate
# event cannot make a second paid invocation for the same exact PR + HEAD.
orl_reservation() { # pr head_sha
  printf '<!-- %s pr=%s head=%s -->' "$ORL_RESERVATION_TAG" "$1" "$2"
}

# Has the trusted reviewer producer already claimed this exact PR + HEAD?
# stdin is TSV: login<TAB>app-slug<TAB>comment-body, one comment per line.
# Text alone is never authority: both GitHub identity fields must match, and the
# marker must bind the exact expected PR and HEAD.
orl_has_trusted_claim() { # expected_pr expected_head
  local want_pr="$1" want_head="$2" login app body
  [ -n "$want_pr" ] && [ -n "$want_head" ] || return 1
  while IFS=$'\t' read -r login app body; do
    [ "$login" = "$ORL_TRUSTED_LOGIN" ] || continue
    [ "$app" = "$ORL_TRUSTED_APP" ] || continue
    case "$body" in
      *"<!-- $ORL_RESERVATION_TAG pr=$want_pr head=$want_head -->"*|*"<!-- $ORL_MARKER_TAG pr=$want_pr head=$want_head verdict="*) return 0 ;;
    esac
  done
  return 1
}

# Human-facing routing. #585, not reviewer prose, owns automatic writer handoff.
orl_route() { # verdict
  case "$1" in
    PASS)                 echo "**READY FOR GOVERNED CLOSE-OUT.** Nothing blocking was found. This verdict is not merge authority." ;;
    "CHANGES REQUIRED") echo "Changes are required on this exact HEAD. #585 or the authorized external relay owns any writer handoff; do not merge." ;;
    "DECISION REQUIRED") echo "**Stopping for @jwogrady.** This needs a project judgment no agent may make." ;;
    *)                    echo "The change was **not assessed**. This is not a pass." ;;
  esac
}

# orl_is_truncated <orig_bytes> <budget> — was the diff cut to fit the budget?
# Returns 0 (truncated) when the original diff is larger than the budget, and
# also 0 (fail closed) when either value is non-numeric — an unreadable size must
# never be treated as a complete diff. The check is purely on size, so it fires
# whatever the cut lands on: a mid-line cut or a split multi-byte character all
# leave the original larger than the budget (#693).
orl_is_truncated() { # <orig_bytes> <budget>
  case "$1" in ''|*[!0-9]*) return 0 ;; esac
  case "$2" in ''|*[!0-9]*) return 0 ;; esac
  [ "$1" -gt "$2" ]
}

# orl_evidence_truncated <diff_state> <manifest_ok> — is the review evidence
# incomplete? The reviewer has seen the whole change only when the diff content
# is COMPLETE *and* the changed-file manifest was fetched. A non-complete diff
# (TRUNCATED or UNAVAILABLE) or an unavailable manifest leaves part of the change
# unseen, so it blocks PASS. Prints the flag consumed as the <truncated> argument
# of orl_enforce_completeness: 1 (incomplete → downgrade a PASS) or 0 (#693).
orl_evidence_truncated() { # <diff_state> <manifest_ok>
  if [ "$1" = "COMPLETE" ] && [ "$2" = "1" ]; then printf '0'; else printf '1'; fi
}

# orl_enforce_completeness <verdict> <truncated> — a PASS on a TRUNCATED diff is
# not a pass. The reviewer never saw the whole change, so a prefix-only PASS is
# downgraded to NOT ASSESSED. Any other verdict — a real defect found, a decision
# owed, or an already-NOT ASSESSED — is returned unchanged. This is the mechanical
# guarantee that a blocker beyond the diff bound can never yield PASS (#693).
orl_enforce_completeness() { # <verdict> <truncated>
  if [ "${2:-0}" = "1" ] && [ "$1" = "PASS" ]; then
    printf 'NOT ASSESSED'
  else
    printf '%s' "$1"
  fi
}
