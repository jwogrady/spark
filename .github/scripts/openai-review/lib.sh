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

# The verdict vocabulary is closed. Anything outside it is NOT ASSESSED — an
# unreadable or malformed verdict is never allowed to read as a pass.
ORL_MARKER_TAG="spark-openai-review"

# orl_normalize_verdict — coerce a model's first line to the closed vocabulary.
#
# Reads the raw first line on stdin (or as $1) and echoes exactly one of
# PASS | CHANGES REQUIRED | DECISION REQUIRED | NOT ASSESSED. Anything it does
# not recognise becomes NOT ASSESSED: a garbled, empty, or novel verdict must
# fail closed, never pass.
orl_normalize_verdict() { # [raw-first-line] -> normalized verdict
  local raw v
  if [ "$#" -gt 0 ]; then raw="$1"; else IFS= read -r raw || raw=""; fi
  # Keep only a leading run of letters and spaces, then squeeze/trim. This drops
  # a trailing ": ..." or punctuation the model may append to the verdict word.
  v="$(printf '%s' "$raw" | tr -d '\r' | sed -E 's/[^A-Za-z ].*$//; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
  case "$v" in
    PASS|"CHANGES REQUIRED"|"DECISION REQUIRED"|"NOT ASSESSED") printf '%s' "$v" ;;
    *) printf 'NOT ASSESSED' ;;
  esac
}

# orl_closing_issues — the issue numbers a PR body declares it closes.
#
# Reads PR text on stdin, echoes each referenced issue number once, ascending.
# Only the GitHub closing keywords count (closes/fixes/resolves); a bare "#12"
# mention is not a contract and is deliberately ignored.
orl_closing_issues() { # stdin: pr text -> issue numbers, one per line, sorted unique
  # No closing reference is a normal answer, not a failure: emit nothing and
  # succeed so a caller under `set -e`/pipefail is not aborted by grep's no-match.
  { grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?) #[0-9]+' || true; } \
    | { grep -oE '[0-9]+' || true; } | sort -un
}

# orl_marker — the hidden, machine-readable evidence line embedded in the posted
# review. It binds the verdict to the exact PR and HEAD SHA so that (a) a later
# run can tell this HEAD was already reviewed (idempotency) and (b) #585 can read
# the verdict for a HEAD without transcribing prose.
#
# Args: verdict pr head_sha
orl_marker() {
  printf '<!-- %s pr=%s head=%s verdict=%s -->' "$ORL_MARKER_TAG" "$2" "$3" "$1"
}

# orl_reviewed_head — has this exact HEAD already been reviewed?
#
# Arg: head_sha. Stdin: the concatenated bodies of the PR's existing comments.
# Returns 0 if a prior reviewer comment already carries a marker for this HEAD,
# 1 otherwise. This is the one-verdict-per-HEAD gate: a re-fire for a HEAD that
# was already judged does nothing, and — because the match is on the exact SHA —
# a new HEAD (a synchronize push) is never mistaken for an already-reviewed one.
orl_reviewed_head() { # <head_sha> ; stdin: comment bodies
  local sha="$1"
  [ -n "$sha" ] || return 1
  grep -qE "$ORL_MARKER_TAG pr=[0-9]+ head=$sha verdict="
}

# orl_route — the human-facing routing line for a verdict. Names who acts next
# and forecloses the reviewer being read as merge authority.
orl_route() { # <verdict> -> routing sentence
  case "$1" in
    PASS)                echo "**READY FOR HUMAN MERGE.** Nothing blocking was found. Merging remains a human act." ;;
    "CHANGES REQUIRED")  echo "@claude a reviewer pass found changes required. Fix them on this branch and push; do not merge." ;;
    "DECISION REQUIRED") echo "**Stopping for @jwogrady.** This needs a project judgment no agent may make. Options may be described below; choosing one is yours." ;;
    *)                   echo "The change was **not reviewed**. This is not a pass." ;;
  esac
}
