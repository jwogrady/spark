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
