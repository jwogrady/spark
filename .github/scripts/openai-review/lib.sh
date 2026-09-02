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
ORL_INVOKED_TAG="spark-openai-review-invoked"
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

# Durable "the paid model call has been consumed for this exact PR + HEAD" marker.
# Written into the reservation comment IMMEDIATELY BEFORE the model call, so that if
# the run dies after the call but before the final verdict is finalized, a later
# completion event sees the call was already consumed and does not invoke the model
# a second time. It carries no verdict, so #585 (which reads verdict markers) never
# mistakes it for a review outcome (#692).
orl_invoked() { # pr head_sha
  printf '<!-- %s pr=%s head=%s -->' "$ORL_INVOKED_TAG" "$1" "$2"
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

# Has the trusted producer posted a FINAL verdict marker (not merely a reservation)
# for this exact PR + HEAD? A reservation means "claimed, review may still be
# pending"; a final marker means "reviewed, terminal verdict recorded". The two are
# distinguished so a HEAD reserved before its CI was terminal can RESUME once the
# checks complete, while a HEAD already reviewed is never reviewed twice (#692).
# stdin is TSV: login<TAB>app-slug<TAB>comment-body, one comment per line.
orl_has_final_marker() { # expected_pr expected_head
  local want_pr="$1" want_head="$2" login app body
  [ -n "$want_pr" ] && [ -n "$want_head" ] || return 1
  while IFS=$'\t' read -r login app body; do
    [ "$login" = "$ORL_TRUSTED_LOGIN" ] || continue
    [ "$app" = "$ORL_TRUSTED_APP" ] || continue
    case "$body" in
      *"<!-- $ORL_MARKER_TAG pr=$want_pr head=$want_head verdict="*) return 0 ;;
    esac
  done
  return 1
}

# Has the paid model call already been CONSUMED for this exact PR + HEAD — either
# invoked (pre-call marker) or fully reviewed (final verdict marker)? The guard
# skips on this, so once the call is started it is never started again, even if a
# prior run died between the call and finalization (concurrency stops overlap, not
# a sequential retry after failure). Only a bare reservation with NEITHER of these
# is resumable (#692). stdin is TSV: login<TAB>app-slug<TAB>comment-body.
orl_has_consumed() { # expected_pr expected_head
  local want_pr="$1" want_head="$2" login app body
  [ -n "$want_pr" ] && [ -n "$want_head" ] || return 1
  while IFS=$'\t' read -r login app body; do
    [ "$login" = "$ORL_TRUSTED_LOGIN" ] || continue
    [ "$app" = "$ORL_TRUSTED_APP" ] || continue
    case "$body" in
      *"<!-- $ORL_INVOKED_TAG pr=$want_pr head=$want_head -->"*|*"<!-- $ORL_MARKER_TAG pr=$want_pr head=$want_head verdict="*) return 0 ;;
    esac
  done
  return 1
}

# Does this exact PR + HEAD need FAIL-CLOSED recovery? A scheduled sweep calls this
# for the live head of each open PR. Recovery is deliberately narrow: it fires ONLY
# for an INVOKED marker with no final verdict — the paid model call was consumed but
# the run died before finalizing (a job kill, or an error the !cancelled finalize
# could not catch). That case is CI-independent: there is nothing left to review,
# only a fail-closed NOT ASSESSED to record, and no active review can touch a
# consumed HEAD (the guard skips it). A BARE reservation is NOT recovered here: its
# CI may still be legitimately running, and finalizing it blind would recreate the
# very pre-terminal freeze #692 removes — it is left to the completion path. Returns
# 0 (recover) or 1 (nothing to do). The caller adds a grace window so the invoking
# run is long finished. stdin is TSV: login<TAB>app-slug<TAB>comment-body.
orl_needs_recovery() { # expected_pr expected_head
  local claims; claims="$(cat)"
  [ -n "$1" ] && [ -n "$2" ] || return 1
  # A final verdict already exists → nothing to recover.
  printf '%s\n' "$claims" | orl_has_final_marker "$1" "$2" && return 1
  # An INVOKED marker (call consumed) with no final verdict → recover. A bare
  # reservation (never invoked) is intentionally left to the completion path.
  printf '%s\n' "$claims" | orl_has_consumed "$1" "$2"
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

# orl_manifest_complete <returned_count> <changed_files> — did the paginated
# files endpoint return EVERY changed file? GitHub caps that endpoint at 3000
# files, so a successful, non-empty response is not proof of completeness. The
# manifest is complete only when the returned record count EXACTLY matches the
# PR's trusted changed_files count. Any mismatch — a short (silently capped)
# count, an inflated one, or a non-numeric input — fails closed to incomplete.
# The count must be taken from API records, never from rendered filenames, since
# a newline in a filename would otherwise inflate a line count (#693).
orl_manifest_complete() { # <returned_count> <changed_files>  -> 1 (complete) or 0
  case "$1" in ''|*[!0-9]*) printf '0'; return ;; esac
  case "$2" in ''|*[!0-9]*) printf '0'; return ;; esac
  if [ "$1" -eq "$2" ]; then printf '1'; else printf '0'; fi
}

# orl_enforce_completeness <verdict> <complete_flag> — a PASS stands only on
# COMPLETE evidence. The flag is "0" when the reviewer saw the whole change and
# "1" (or anything else) otherwise. Fail closed: a PASS survives only when the
# flag is EXACTLY "0"; a "1", an empty value, or any malformed flag downgrades it
# to NOT ASSESSED. Every non-PASS verdict — a real defect, a decision owed, an
# already-NOT ASSESSED — is returned unchanged. This is the mechanical guarantee
# that incomplete evidence can never yield PASS (#693).
orl_enforce_completeness() { # <verdict> <complete_flag>
  if [ "$1" = "PASS" ] && [ "${2:-}" != "0" ]; then
    printf 'NOT ASSESSED'
  else
    printf '%s' "$1"
  fi
}

# orl_build_evidence <diff_raw> <diff_ok> <budget> <files_txt> <manifest_fetch_ok>
#                    <changed_files> <out_dir>
# Turn the already-fetched raw diff and changed-file manifest into the derived
# completeness artifacts the reviewer input needs — so the REAL handling (byte
# truncation, the fail-closed flag, and disclosure) is exercised by fixture tests
# with constructed byte inputs, not just asserted by grep. Writes, under out_dir:
#   diff.txt         the diff sent to the model: the full diff when complete, else
#                    the budget-bounded prefix (the raw sentinel when unfetchable);
#   truncated        the completeness flag consumed by orl_enforce_completeness —
#                    "0" only when the diff is COMPLETE and the manifest reached
#                    changed_files, else "1";
#   completeness.txt the trusted, machine-generated status (no filenames).
# The manifest record count is taken from files_txt only when the fetch succeeded
# (manifest_fetch_ok=1); a failed fetch counts as zero and fails closed. Pure but
# for these writes — no network, no gh, no git (#693).
orl_build_evidence() {
  local raw="$1" diff_ok="$2" budget="$3" files="$4" mfetch="$5" cfiles="$6" out="$7"
  local orig_bytes diff_state mcount manifest_ok manifest_state
  orig_bytes="$(wc -c < "$raw" | tr -d ' ')"
  if [ "$diff_ok" = "1" ] && ! orl_is_truncated "$orig_bytes" "$budget"; then
    cp "$raw" "$out/diff.txt"; diff_state="COMPLETE"
  else
    head -c "$budget" "$raw" > "$out/diff.txt"
    if [ "$diff_ok" = "0" ]; then diff_state="UNAVAILABLE"; else diff_state="TRUNCATED"; fi
  fi
  if [ "$mfetch" = "1" ]; then
    mcount="$(wc -l < "$files" | tr -d ' ')"
    manifest_ok="$(orl_manifest_complete "$mcount" "$cfiles")"
  else
    mcount=0; manifest_ok=0
  fi
  if [ "$manifest_ok" = "1" ]; then
    manifest_state="complete (${mcount} of ${cfiles} files)"
  else
    manifest_state="INCOMPLETE (${mcount} of ${cfiles:-unknown} files; the file list was capped or could not be fetched)"
  fi
  orl_evidence_truncated "$diff_state" "$manifest_ok" > "$out/truncated"
  {
    case "$diff_state" in
      COMPLETE)    printf 'DIFF COMPLETE: the full exact-HEAD diff is present (%s bytes).\n' "$orig_bytes" ;;
      TRUNCATED)   printf 'DIFF TRUNCATED: showing %s of %s bytes; hunks beyond the bound are OMITTED. An incomplete diff can never be PASS.\n' "$budget" "$orig_bytes" ;;
      UNAVAILABLE) printf 'DIFF UNAVAILABLE: the exact-HEAD diff could not be fetched; NO diff content is present. An unfetchable diff can never be PASS.\n' ;;
    esac
    printf 'CHANGED FILE MANIFEST: %s. The file list follows in the untrusted manifest section; a capped or unavailable manifest also blocks PASS.\n' "$manifest_state"
  } > "$out/completeness.txt"
}

# orl_checks_terminal <required-name>...  — stdin: check lines "name: status/conclusion".
# Returns 0 only when EVERY required check is present and EVERY run reported for it
# has status "completed". A required check that is missing, or that has ANY run
# still queued/in_progress (a re-run may add a second, non-terminal entry for the
# same name in unspecified order), makes the set non-terminal. Fail closed: the
# reviewer must consume a terminal exact-HEAD CI snapshot, never a pending one (#692).
orl_checks_terminal() { # <required...>
  local input name found line rest status
  input="$(cat)"
  for name in "$@"; do
    found=0
    while IFS= read -r line; do
      case "$line" in "$name: "*)
        found=1
        rest="${line#"$name": }"; status="${rest%%/*}"
        [ "$status" = "completed" ] || return 1 ;;
      esac
    done <<INNER
$input
INNER
    [ "$found" = 1 ] || return 1
  done
  return 0
}

# orl_checks_passed <required-name>...  — stdin: check lines "name: status/conclusion".
# Returns 0 only when EVERY required check is present and EVERY run reported for it
# is exactly "completed/success". Any non-terminal, failed, cancelled, timed-out,
# or missing run makes the set not-passed. A model PASS on a HEAD whose required
# checks are not all green is downgraded, so a failed or cancelled required check
# can never publish PASS (#692).
orl_checks_passed() { # <required...>
  local input name found line rest
  input="$(cat)"
  for name in "$@"; do
    found=0
    while IFS= read -r line; do
      case "$line" in "$name: "*)
        found=1; rest="${line#"$name": }"
        case "$rest" in completed/success) ;; *) return 1 ;; esac ;;
      esac
    done <<INNER
$input
INNER
    [ "$found" = 1 ] || return 1
  done
  return 0
}
