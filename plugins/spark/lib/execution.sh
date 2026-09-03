# Spark runtime module: execution (#614)
#
# The five v0.23 execution verbs — telemetry, budget, evidence, route, ci — and
# the helpers only they use. The seam is not a line-count convenience: the
# structural baseline shows this cluster's forty-odd helpers are referenced by
# no verb outside it, while several are shared ACROSS it, which is what makes it
# one module rather than five files.
#
# What crosses the boundary stays in the dispatcher and is never restated here:
# red/green/yellow, usage, git_root, check_json, prefs_operator_path, and the
# footprint timing helpers. One canonical implementation per fact was the point
# of decomposing; a module that re-implemented a primitive to stand alone would
# have defeated it.
#
# This file is sourced, never executed. It is the shipped implementation — there
# is no build step and no generated artifact, so source and behaviour cannot
# diverge.

# ---------------------------------------------------------------------------
# spark telemetry — run facts as a by-product of execution (#574)
#
# The operator cannot optimize what is not visible; but observability that costs
# model tokens to produce is itself the inefficiency it was meant to expose. So
# this verb records only facts the executing process ALREADY KNOWS, deterministically,
# with no model call anywhere in the path.
#
# Three mechanical rules give that contract teeth, so it survives contact with a
# hurried caller instead of living in a style guide:
#
#   1. The field set is an ALLOWLIST. A raw prompt, transcript, hidden reasoning,
#      full diff or test log has no key to live under, so it cannot enter the
#      stream by accident — the schema refuses it rather than a reviewer catching it.
#   2. Every value is one short line. An Actions URL fits; a pasted log does not.
#      Deep evidence stays in GitHub and is LINKED, which is also why the record
#      stays cheap enough to carry into a model context when it is genuinely needed.
#   3. Credential-shaped values are refused whatever key they claim.
#
# What was not recorded reports as NOT ASSESSED. A missing provider metric is an
# unknown, and an unknown rendered as a number is a lie the operator would then
# optimize against.
TELEMETRY_KEYS="run_id attempt trigger pr head_sha actions_run provider model routing_reason effort preflight_tokens input_tokens output_tokens cache_write_tokens cache_read_tokens cache_reason tool_schema_tokens cost_usd wall_seconds tool_calls api_requests full_suite_runs targeted_checks iterations batch_usage compaction_events context_before context_after failing_before failing_after verdict overhead_ms certified_at ci_state runtime_source_bytes runtime_modules_loaded"

# Counts and measurements are integers. A field that must be a number and is not
# is a recording error: taking it anyway would put a value in a comparison column
# that cannot be compared.
TELEMETRY_INT_KEYS="attempt pr preflight_tokens input_tokens output_tokens cache_write_tokens cache_read_tokens tool_schema_tokens wall_seconds tool_calls api_requests full_suite_runs targeted_checks iterations compaction_events context_before context_after failing_before failing_after overhead_ms runtime_source_bytes"

# The verdict vocabulary is closed and matches the lifecycle's own answers, so a
# run's outcome is comparable across runs. NOT ASSESSED is a legitimate verdict —
# it is what a run reports when it could not tell, and it must never render as PASS.
TELEMETRY_VERDICTS="PASS|CHANGES REQUIRED|DECISION REQUIRED|NOT ASSESSED|FAIL"

# One line, and short enough that only a reference fits. This is the number that
# makes "link deep evidence, never duplicate it" enforceable instead of advisory.
TELEMETRY_MAX_VALUE="${TELEMETRY_MAX_VALUE:-200}"
# Budget for the observability overhead itself (--timing), in the spirit of the
# footprint gate: measuring the work must stay negligible against doing it.
TELEMETRY_OVERHEAD_MS="${TELEMETRY_OVERHEAD_MS:-400}"

tm_is_key()     { case " $TELEMETRY_KEYS "     in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
tm_is_int_key() { case " $TELEMETRY_INT_KEYS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# tm_secret_shaped <value> — true when a value looks like a credential. Spark
# cannot know every secret, but it can refuse the shapes that are never a
# legitimate metric, whatever field they are handed to.
tm_secret_shaped() {
  case "$1" in
    ghp_*|gho_*|ghu_*|ghs_*|ghr_*|github_pat_*|sk-ant-*|sk-*|xoxb-*|xoxp-*|xoxa-*|xoxr-*|*'PRIVATE KEY'*)
      return 0 ;;
  esac
  printf '%s' "$1" | grep -Eq 'AKIA[0-9A-Z]{16}'
}

# tm_valid_run <id> — the run id becomes a filename, so the alphabet is closed.
tm_valid_run() {
  case "$1" in
    ''|.|..) return 1 ;;
    *[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

tm_dir()  { printf '%s/.spark/telemetry' "$1"; }
tm_file() { printf '%s/.spark/telemetry/%s.tsv' "$1" "$2"; }

# tm_exec_count <top> <run> <kind> — the AUTHORITATIVE execution count for a run,
# derived from its append-only .spark/telemetry/<run>.executions log. That log is
# the source of truth for full_suite_runs/targeted_checks: a short append is
# atomic under arbitrary overlap, so the log never loses a concurrent execution,
# while the counters stored on the .tsv record are a last-write-wins projection a
# stale publish can leave low. Every read that reports these two counters derives
# them here so a lost publish race can never surface a regressed count (#665).
# Prints the count and succeeds when the log exists; fails (no output) when it
# does not, so a counter set directly, without the runner, keeps its stored value.
tm_exec_count() {
  local elog; elog="$(tm_dir "$1")/$2.executions"
  [ -f "$elog" ] || return 1
  awk -F'\t' -v k="$3" '$1 == k { n++ } END { print n+0 }' "$elog"
}

# tm_get <file> <key> — the recorded value, or empty. Last write wins, so
# re-recording a field supersedes it rather than leaving two truths on disk.
tm_get() {
  [ -f "$1" ] || return 0
  awk -F'\t' -v k="$2" '$1 == k { v = $2 } END { if (v != "") print v }' "$1"
}

# tm_load <file> — fill tmv_<key> for every schema key, empty when unrecorded.
tm_load() {
  local f="$1" k v
  for k in $TELEMETRY_KEYS; do eval "tmv_$k=''"; done
  [ -f "$f" ] || return 0
  while IFS=$'\t' read -r k v; do
    tm_is_key "$k" && eval "tmv_$k=\$v"
  done < "$f"
  return 0
}

# tm_cache_ratio <read> <write> — cache hit ratio as a percentage. BOTH halves
# are required: a ratio derived from one of them is invention, and the whole
# point of the field is to tell a cached loop from one rebuilding the cache.
tm_cache_ratio() {
  local r="$1" w="$2" tot
  case "$r" in ''|*[!0-9]*) printf 'NOT ASSESSED'; return 0 ;; esac
  case "$w" in ''|*[!0-9]*) printf 'NOT ASSESSED'; return 0 ;; esac
  tot=$((r + w))
  [ "$tot" -gt 0 ] || { printf 'NOT ASSESSED'; return 0; }
  awk -v r="$r" -v t="$tot" 'BEGIN { printf "%.1f%%", (r * 100) / t }'
}

# tm_delta <before> <after> — signed change, or NOT ASSESSED without both ends.
tm_delta() {
  case "$1" in ''|*[!0-9]*) printf 'NOT ASSESSED'; return 0 ;; esac
  case "$2" in ''|*[!0-9]*) printf 'NOT ASSESSED'; return 0 ;; esac
  printf '%+d' "$(( $2 - $1 ))"
}

# tm_no_progress <full-suite-runs> <failing-before> <failing-after> — the signal
# #558 acts on: expensive verification repeated while the failing set stood
# still. Missing evidence is NOT ASSESSED, never read as "fine" — a silent
# no-progress loop is exactly the thing this is here to make visible.
tm_no_progress() {
  local runs="$1" fb="$2" fa="$3"
  case "$runs" in ''|*[!0-9]*) printf 'NOT ASSESSED'; return 0 ;; esac
  case "$fb"   in ''|*[!0-9]*) printf 'NOT ASSESSED'; return 0 ;; esac
  case "$fa"   in ''|*[!0-9]*) printf 'NOT ASSESSED'; return 0 ;; esac
  if [ "$runs" -ge 2 ] && [ "$fb" = "$fa" ]; then
    printf 'yes — %s full-suite runs left the failing set at %s' "$runs" "$fa"
  else
    printf 'no'
  fi
}

# tm_binding_status <recorded-sha> <live-sha> — whether this record still
# describes the PR's current head. A run bound to a superseded commit is not
# evidence about the code under review, and without a live head to compare
# against the answer is unknown — which is not the same as current.
tm_binding_status() {
  local rec="$1" live="$2"
  [ -n "$rec" ]  || { printf 'NOT ASSESSED — no head_sha recorded'; return 0; }
  [ -n "$live" ] || { printf 'NOT ASSESSED — the live head could not be read'; return 0; }
  if [ "$rec" = "$live" ]; then printf 'current'
  else printf 'superseded — the live head is %s' "$live"; fi
}

# tm_live_head <pr> — the PR's current head SHA, or empty when it cannot be read.
# Failing to read it yields NOT ASSESSED upstream; it never yields "current".
tm_live_head() {
  local pr="$1"
  [ -n "$pr" ] || return 0
  command -v gh >/dev/null 2>&1 || return 0
  gh pr view "$pr" --json headRefOid --jq .headRefOid 2>/dev/null || true
}

# tm_hot_cycle — one record+show round trip, the unit --timing measures.
tm_hot_cycle() {
  "$SPARK_ROOT/bin/spark" telemetry record --run "$TM_TIMING_RUN" tool_calls=1 >/dev/null 2>&1
  "$SPARK_ROOT/bin/spark" telemetry show   --run "$TM_TIMING_RUN" >/dev/null 2>&1
}

cmd_telemetry() {
  local usage_line="usage: spark telemetry [record key=value ...|show|relay|compare <run> <run>|list] [--run <id>] [--head <sha>] [--json] [--timing]"
  local action="show"
  case "${1:-}" in
    record|show|relay|list|compare) action="$1"; shift ;;
  esac

  local run="" head="" json="" timing="" pairs="" argv=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --run)    shift; run="${1:-}" ;;
      --run=*)  run="${1#--run=}" ;;
      --head)   shift; head="${1:-}" ;;
      --head=*) head="${1#--head=}" ;;
      --json)   json=1 ;;
      --timing) timing=1 ;;
      -h|--help) echo "$usage_line"; return 0 ;;
      *=*)  pairs="${pairs}$1
" ;;
      -*)   red "unknown option: $1"; echo "$usage_line"; return 1 ;;
      *)    argv="${argv}$1
" ;;
    esac
    shift
  done

  local top
  top="$(git_root)"; if [ -z "$top" ]; then
    red "spark telemetry needs a git repo — run it from inside the project."
    return 1
  fi

  # The run a command addresses: an explicit --run, then $SPARK_RUN_ID (so a
  # workflow step can export it once instead of threading it through every
  # call), then "current".
  [ -n "$run" ] || run="${SPARK_RUN_ID:-current}"
  if ! tm_valid_run "$run"; then
    red "invalid run id: '$run' (letters, digits, dot, dash and underscore only — the id becomes a filename)"
    return 1
  fi

  if [ -n "$timing" ]; then
    local ms
    TM_TIMING_RUN="spark-telemetry-timing"
    ms=$(fp_median3_ms tm_hot_cycle) || ms=""
    rm -f "$(tm_file "$top" "$TM_TIMING_RUN")"
    if [ -n "$json" ]; then
      printf '{"method":"median-of-3 wall-clock ms for one record+show cycle (null = no ms-resolution clock)","overhead":{"ms":%s,"budget":%s}}\n' \
        "${ms:-null}" "$TELEMETRY_OVERHEAD_MS"
    elif [ -z "$ms" ]; then
      echo "Telemetry overhead: not measured (no ms-resolution clock on this host)"
    else
      printf 'Telemetry overhead: %s ms per record+show cycle (budget %s)%s\n' \
        "$ms" "$TELEMETRY_OVERHEAD_MS" \
        "$([ "$ms" -gt "$TELEMETRY_OVERHEAD_MS" ] && echo '  OVER BUDGET')"
    fi
    [ -z "$ms" ] && return 0
    [ "$ms" -le "$TELEMETRY_OVERHEAD_MS" ]
    return $?
  fi

  local file; file="$(tm_file "$top" "$run")"

  case "$action" in
    record)
      if [ -z "$pairs" ]; then
        red "spark telemetry record needs at least one key=value pair"
        echo "$usage_line"; return 1
      fi
      # Validate EVERY pair before writing ANY of them. A half-recorded run is a
      # falsifiable record that later reads as fact, so this fails closed.
      local pair key val
      while IFS= read -r pair; do
        [ -n "$pair" ] || continue
        key="${pair%%=*}"; val="${pair#*=}"
        if ! tm_is_key "$key"; then
          red "unknown telemetry key: $key"
          yellow "  the schema is an allowlist so raw prompts, transcripts, diffs and logs have nowhere to land."
          yellow "  valid keys: $TELEMETRY_KEYS"
          return 1
        fi
        case "$val" in
          *$'\n'*|*$'\r'*|*$'\t'*)
            red "telemetry values are one line ($key contains a newline/tab) — link deep evidence instead of pasting it"
            return 1 ;;
        esac
        if [ "${#val}" -gt "$TELEMETRY_MAX_VALUE" ]; then
          red "telemetry value for $key is ${#val} characters (limit $TELEMETRY_MAX_VALUE) — record a link, not the content"
          return 1
        fi
        if tm_secret_shaped "$val"; then
          red "refusing to record $key: the value is credential-shaped, and telemetry is a published surface"
          return 1
        fi
        if tm_is_int_key "$key"; then
          case "$val" in
            ''|*[!0-9]*)
              red "$key must be a whole number (got '$val') — an unmeasured field is left unrecorded and reports NOT ASSESSED"
              return 1 ;;
          esac
        fi
        if [ "$key" = "cost_usd" ]; then
          case "$val" in
            ''|*[!0-9.]*|*.*.*)
              red "cost_usd must be a decimal number (got '$val')"
              return 1 ;;
          esac
        fi
        if [ "$key" = "verdict" ]; then
          case "|$TELEMETRY_VERDICTS|" in
            *"|$val|"*) ;;
            *) red "unknown verdict: '$val' (one of: ${TELEMETRY_VERDICTS//|/, })"; return 1 ;;
          esac
        fi
      done <<EOF
$pairs
EOF

      tm_load "$file"
      while IFS= read -r pair; do
        [ -n "$pair" ] || continue
        key="${pair%%=*}"; val="${pair#*=}"
        eval "tmv_$key=\$val"
      done <<EOF
$pairs
EOF
      # The record always knows which run it is; storing it keeps the file
      # self-describing once it is copied out of .spark/telemetry.
      tmv_run_id="$run"

      mkdir -p "$(tm_dir "$top")" || { red "could not create $(tm_dir "$top")"; return 1; }
      local k v
      {
        for k in $TELEMETRY_KEYS; do
          eval "v=\$tmv_$k"
          if [ -n "$v" ]; then printf '%s\t%s\n' "$k" "$v"; fi
        done
      } > "$file" || { red "could not write $file"; return 1; }
      green "telemetry: $file"
      ;;

    list)
      local any=0 f id
      for f in "$(tm_dir "$top")"/*.tsv; do
        [ -f "$f" ] || continue
        any=1; id="$(basename "$f" .tsv)"
        local lv lh
        lv="$(tm_get "$f" verdict)"; lh="$(tm_get "$f" head_sha)"
        printf '%-28s %-16s %s\n' "$id" "${lv:-NOT ASSESSED}" "${lh:-NOT ASSESSED}"
      done
      [ "$any" -eq 1 ] || yellow "no telemetry records under .spark/telemetry"
      ;;

    compare)
      local a b
      a="$(printf '%s' "$argv" | sed -n '1p')"
      b="$(printf '%s' "$argv" | sed -n '2p')"
      if [ -z "$a" ] || [ -z "$b" ]; then
        red "spark telemetry compare needs two run ids"; echo "$usage_line"; return 1
      fi
      tm_valid_run "$a" && tm_valid_run "$b" || { red "invalid run id"; return 1; }
      local fa fb
      fa="$(tm_file "$top" "$a")"; fb="$(tm_file "$top" "$b")"
      [ -f "$fa" ] || { red "no telemetry record for run '$a'"; return 1; }
      [ -f "$fb" ] || { red "no telemetry record for run '$b'"; return 1; }
      echo "Spark run comparison — $a vs $b"
      printf '  %-22s %-22s %-22s %s\n' field "$a" "$b" change
      local k va vb ch ekind da db
      for k in $TELEMETRY_KEYS; do
        [ "$k" = "run_id" ] && continue
        va="$(tm_get "$fa" "$k")"; vb="$(tm_get "$fb" "$k")"
        # The execution counters are authoritative in each run's append-only log,
        # not its .tsv projection — derive them so a comparison never reports a
        # count a stale publish left low (#665).
        case "$k" in
          full_suite_runs|targeted_checks)
            ekind=full; [ "$k" = "targeted_checks" ] && ekind=targeted
            da="$(tm_exec_count "$top" "$a" "$ekind")" && va="$da"
            db="$(tm_exec_count "$top" "$b" "$ekind")" && vb="$db"
            ;;
        esac
        [ -z "$va" ] && [ -z "$vb" ] && continue
        ch="—"
        tm_is_int_key "$k" && ch="$(tm_delta "$va" "$vb")"
        printf '  %-22s %-22s %-22s %s\n' "$k" "${va:-NOT ASSESSED}" "${vb:-NOT ASSESSED}" "$ch"
      done
      echo
      echo "Cost, latency, tokens, cache, tool/API/full-suite counts and outcome are all above —"
      echo "the execution counts derive from each run's append-only log, never a raw scan here."
      ;;

    show|relay)
      [ -f "$file" ] || { yellow "no telemetry record for run '$run' (.spark/telemetry/$run.tsv)"; return 0; }
      tm_load "$file"
      # The execution counters are DERIVED from the append-only log at read time,
      # never trusted from the last-write-wins projection on the record, so a
      # stale publish that lost a race can never surface here — for the human
      # table, the JSON, the relay projection, and the convergence signal below,
      # which all read the tmv_ counters set here (#665).
      local dfull dtarg
      dfull="$(tm_exec_count "$top" "$run" full)"     && tmv_full_suite_runs="$dfull"
      dtarg="$(tm_exec_count "$top" "$run" targeted)" && tmv_targeted_checks="$dtarg"
      local live ratio cdelta fdelta noprog binding
      live="$head"; [ -n "$live" ] || live="$(tm_live_head "$tmv_pr")"
      binding="$(tm_binding_status "$tmv_head_sha" "$live")"
      ratio="$(tm_cache_ratio "$tmv_cache_read_tokens" "$tmv_cache_write_tokens")"
      cdelta="$(tm_delta "$tmv_context_before" "$tmv_context_after")"
      fdelta="$(tm_delta "$tmv_failing_before" "$tmv_failing_after")"
      noprog="$(tm_no_progress "$tmv_full_suite_runs" "$tmv_failing_before" "$tmv_failing_after")"

      if [ -n "$json" ] && [ "$action" = "show" ]; then
        local first=1 k v
        json_escape_out() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
        printf '{"run":"%s","fields":{' "$(json_escape_out "$run")"
        for k in $TELEMETRY_KEYS; do
          eval "v=\$tmv_$k"
          [ "$first" -eq 1 ] && first=0 || printf ','
          if [ -z "$v" ]; then printf '"%s":null' "$k"
          elif tm_is_int_key "$k"; then printf '"%s":%s' "$k" "$v"
          else printf '"%s":"%s"' "$k" "$(json_escape_out "$v")"; fi
        done
        printf '},"derived":{"cache_hit_ratio":"%s","context_delta":"%s","failing_delta":"%s","no_progress":"%s","binding":"%s"}}\n' \
          "$ratio" "$cdelta" "$fdelta" "$(json_escape_out "$noprog")" "$(json_escape_out "$binding")"
        return 0
      fi

      if [ "$action" = "relay" ]; then
        # The projection the Agent Relay Discussion (#578) can carry. It links
        # its evidence and summarizes nothing it cannot point at, which is what
        # keeps the Discussion a window onto the PR rather than a rival source
        # of truth.
        local prshow="NOT ASSESSED"
        if [ -n "$tmv_pr" ]; then prshow="#$tmv_pr"; fi
        printf '### Run `%s` — %s\n\n' "$run" "${tmv_verdict:-NOT ASSESSED}"
        printf 'PR %s @ `%s` · %s\n\n' "$prshow" \
          "${tmv_head_sha:-NOT ASSESSED}" "$binding"
        printf '| metric | value |\n|---|---|\n'
        printf '| model / effort | %s / %s |\n' "${tmv_model:-NOT ASSESSED}" "${tmv_effort:-NOT ASSESSED}"
        printf '| routing reason | %s |\n' "${tmv_routing_reason:-NOT ASSESSED}"
        printf '| tokens in / out | %s / %s |\n' "${tmv_input_tokens:-NOT ASSESSED}" "${tmv_output_tokens:-NOT ASSESSED}"
        printf '| cache hit ratio | %s |\n' "$ratio"
        printf '| estimated cost (USD) | %s |\n' "${tmv_cost_usd:-NOT ASSESSED}"
        printf '| wall seconds | %s |\n' "${tmv_wall_seconds:-NOT ASSESSED}"
        printf '| tool calls / API requests | %s / %s |\n' "${tmv_tool_calls:-NOT ASSESSED}" "${tmv_api_requests:-NOT ASSESSED}"
        printf '| full-suite / targeted runs | %s / %s |\n' "${tmv_full_suite_runs:-NOT ASSESSED}" "${tmv_targeted_checks:-NOT ASSESSED}"
        printf '| failing set before → after | %s → %s (%s) |\n' \
          "${tmv_failing_before:-NOT ASSESSED}" "${tmv_failing_after:-NOT ASSESSED}" "$fdelta"
        printf '| repeated work with no progress | %s |\n' "$noprog"
        printf '\n%s\n' "Authoritative evidence: the PR, its checks, and ${tmv_actions_run:-the Actions run}. This projection links them and is not itself authority."
        return 0
      fi

      tm_row() { printf '  %-24s %s\n' "$1" "$2"; }
      printf 'Spark run telemetry — run %s\n\n' "$run"
      echo "binding"
      tm_row "pr"                 "${tmv_pr:-NOT ASSESSED}"
      tm_row "head sha"           "${tmv_head_sha:-NOT ASSESSED}"
      tm_row "status"             "$binding"
      tm_row "attempt"            "${tmv_attempt:-NOT ASSESSED}"
      tm_row "trigger"            "${tmv_trigger:-NOT ASSESSED}"
      tm_row "actions run"        "${tmv_actions_run:-NOT ASSESSED}"
      echo
      echo "routing"
      tm_row "provider / model"   "${tmv_provider:-NOT ASSESSED} / ${tmv_model:-NOT ASSESSED}"
      tm_row "effort"             "${tmv_effort:-NOT ASSESSED}"
      tm_row "escalation reason"  "${tmv_routing_reason:-NOT ASSESSED}"
      echo
      echo "tokens"
      tm_row "preflight estimate" "${tmv_preflight_tokens:-NOT ASSESSED}"
      tm_row "input / output"     "${tmv_input_tokens:-NOT ASSESSED} / ${tmv_output_tokens:-NOT ASSESSED}"
      tm_row "cache write / read" "${tmv_cache_write_tokens:-NOT ASSESSED} / ${tmv_cache_read_tokens:-NOT ASSESSED}"
      tm_row "cache hit ratio"    "$ratio"
      tm_row "cache rebuild cause" "${tmv_cache_reason:-NOT ASSESSED}"
      tm_row "tool-schema tokens" "${tmv_tool_schema_tokens:-NOT ASSESSED}"
      echo
      echo "economics"
      tm_row "estimated cost USD" "${tmv_cost_usd:-NOT ASSESSED}"
      tm_row "wall seconds"       "${tmv_wall_seconds:-NOT ASSESSED}"
      echo
      echo "work"
      tm_row "tool calls"         "${tmv_tool_calls:-NOT ASSESSED}"
      tm_row "api requests"       "${tmv_api_requests:-NOT ASSESSED}"
      tm_row "full-suite runs"    "${tmv_full_suite_runs:-NOT ASSESSED}"
      tm_row "targeted checks"    "${tmv_targeted_checks:-NOT ASSESSED}"
      tm_row "iterations"         "${tmv_iterations:-NOT ASSESSED}"
      tm_row "batch usage"        "${tmv_batch_usage:-NOT ASSESSED}"
      echo
      echo "context"
      tm_row "before / after"     "${tmv_context_before:-NOT ASSESSED} / ${tmv_context_after:-NOT ASSESSED}"
      tm_row "change"             "$cdelta"
      tm_row "compaction events"  "${tmv_compaction_events:-NOT ASSESSED}"
      echo
      echo "convergence"
      tm_row "failing before/after" "${tmv_failing_before:-NOT ASSESSED} / ${tmv_failing_after:-NOT ASSESSED}"
      tm_row "change"             "$fdelta"
      tm_row "repeated, no progress" "$noprog"
      echo
      echo "outcome"
      tm_row "verdict"            "${tmv_verdict:-NOT ASSESSED}"
      tm_row "telemetry overhead" "${tmv_overhead_ms:-NOT ASSESSED}"
      echo
      echo "Deep evidence — logs, diffs, tool output — stays in GitHub and Actions."
      echo "This record links it and never copies it."
      ;;
    *)
      red "unknown telemetry action: $action"; echo "$usage_line"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# spark budget — bounded autonomous execution and convergence (#558)
#
# A repository can be fully deterministic and the RUN inside it still be
# unbounded: expensive certification invoked again and again, findings
# rediscovered instead of carried as a shrinking failing set, and no boundary
# anywhere except the agent's own judgement about when it has done enough.
#
# This makes the boundary explicit and external. A work unit DECLARES its
# convergence condition and its envelope before it starts, then asks `check`
# before each expensive act. The answer is one of five, and it is the exit code
# as well as the text, so a loop that reads only the status still terminates:
#
#   PROCEED (0)   within the envelope, and something material changed
#   STOP (2)      a hard bound was reached, or a soft one with no movement
#   ESCALATE (3)  the same expensive work repeated with no material change
#   CONVERGED (4) the declared condition is met — the loop is finished
#   error (1)     usage; an undeclared run cannot be authorized to spend
#
# The facts come from the #574 telemetry record for the same run id; only the
# BOUNDS live here. Two files, one run: what happened, and what was permitted.
#
# Budgets are guardrails around convergence, never a substitute for it, and
# never authority. Reaching one stops the work — it can never drop a blocker,
# mark a failing set clean, or resolve a DECISION REQUIRED. A budget that could
# silence a failure would be a worse defect than the unbounded run it replaced.
BUDGET_DECLARED="convergence max_iterations max_full_suite max_targeted max_tool_calls max_api_requests max_wall_seconds max_cost_usd max_no_progress per_request_output_cap preflight_tokens model effort"
BUDGET_STATE="failing failing_prev expensive_runs targeted_runs no_progress_runs last_expensive_failing last_targeted_failing reopen_count reopen_reason"
BUDGET_KEYS="$BUDGET_DECLARED $BUDGET_STATE"
BUDGET_INT_KEYS="max_iterations max_full_suite max_targeted max_tool_calls max_api_requests max_wall_seconds max_no_progress per_request_output_cap preflight_tokens failing failing_prev expensive_runs targeted_runs no_progress_runs last_expensive_failing last_targeted_failing reopen_count"

# How many times equivalent expensive verification may repeat with nothing
# material having changed before the run is escalated rather than continued.
BUDGET_DEFAULT_NO_PROGRESS="${BUDGET_DEFAULT_NO_PROGRESS:-1}"

# The record-format stamp (#642). It is always line one of a written file, and
# it can only ever be there honestly: every accepted text field is rejected
# below if it contains the newline a forged line would need, so a file that
# has this exact stamp was necessarily produced by validated writes end to
# end. A multi-line file WITHOUT it predates that guarantee, and there is no
# honest parser-only way to tell its later lines apart from ones a pre-fix
# text value smuggled in — see bg_ambiguous.
BUDGET_FORMAT_KEY="__format"
BUDGET_FORMAT_VAL="1"

bg_is_key()     { case " $BUDGET_KEYS "     in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
bg_is_int_key() { case " $BUDGET_INT_KEYS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# bg_reject_framing <field> <value> — the boundary #642 gives every budget
# text field: a newline, CR or tab could serialize as an extra TSV line,
# turning prose into an unauthorized budget key. Mirrors the telemetry record
# path's fail-closed check (tm record, above) rather than inventing a second
# rule for the same threat.
bg_reject_framing() {
  case "$2" in
    *$'\n'*|*$'\r'*|*$'\t'*)
      red "budget $1 must be one line ($1 contains a newline/tab/CR) — a multi-line value could inject another budget key"
      return 1 ;;
  esac
  return 0
}

# bg_stage <key> <value> — the one path cmd_budget's parser uses to queue a
# pending `declare` assignment. Earlier this joined "key=value" pairs with a
# literal newline into a single string and re-split it on read; a value that
# reached that join un-checked (a future text option that forgot its own
# bg_reject_framing call) could plant its own newline and have `read` split it
# into an extra "key=value" line, forging a second assignment before
# bg_reject_framing ever saw the combined value. Giving every pair its
# own shell variable — never joined, never re-split — removes that class by
# construction: bg_apply_staged always validates each value exactly as staged.
bg_stage() {
  bg_pairs_n=$((bg_pairs_n + 1))
  eval "bg_pair_key_$bg_pairs_n=\$1"
  eval "bg_pair_val_$bg_pairs_n=\$2"
}

# bg_apply_staged — consume every pair bg_stage queued into bgv_<key>,
# rejecting an unknown key or framing violation exactly as `declare` always
# has. Split out from cmd_budget so the full stage→validate→assign path is
# reachable on its own, including for a key no CLI flag defines yet.
bg_apply_staged() {
  local i=1 key val
  while [ "$i" -le "$bg_pairs_n" ]; do
    eval "key=\$bg_pair_key_$i"
    eval "val=\$bg_pair_val_$i"
    if ! bg_is_key "$key"; then
      red "unknown budget bound: ${key#max_} (valid: $(printf '%s' "$BUDGET_DECLARED" | tr ' ' '\n' | sed -n 's/^max_//p' | tr '\n' ' '))"
      return 1
    fi
    if bg_is_int_key "$key"; then
      case "$val" in ''|*[!0-9]*) red "$key must be a whole number (got '$val')"; return 1 ;; esac
    else
      bg_reject_framing "$key" "$val" || return 1
    fi
    eval "bgv_$key=\$val"
    i=$((i + 1))
  done
  return 0
}

bg_dir()  { printf '%s/.spark/budgets' "$1"; }
bg_file() { printf '%s/.spark/budgets/%s.tsv' "$1" "$2"; }

bg_get() {
  [ -f "$1" ] || return 0
  awk -F'\t' -v k="$2" '$1 == k { v = $2 } END { if (v != "") print v }' "$1"
}

# bg_ambiguous <file> — true only when a file both (a) has more than one line,
# so a forged extra line is even possible, and (b) lacks the format stamp that
# proves it came from validated writes. A single-line file can never be
# ambiguous: there is nowhere for an injected key to hide.
bg_ambiguous() {
  local f="$1" lines first
  [ -f "$f" ] || return 1
  lines="$(awk 'END { print NR }' "$f")"
  [ "${lines:-0}" -gt 1 ] || return 1
  IFS= read -r first < "$f"
  [ "$first" = "$(printf '%s\t%s' "$BUDGET_FORMAT_KEY" "$BUDGET_FORMAT_VAL")" ] && return 1
  return 0
}

# bg_load <file> — fill bgv_<key> for every key, empty when unset. Sets
# bg_load_ambiguous when the file cannot be proven free of pre-fix injection
# (see bg_ambiguous); callers must fail closed on that rather than trust it.
bg_load() {
  local f="$1" k v
  bg_load_ambiguous=""
  for k in $BUDGET_KEYS; do eval "bgv_$k=''"; done
  [ -f "$f" ] || return 0
  if bg_ambiguous "$f"; then
    bg_load_ambiguous=1
    return 0
  fi
  while IFS=$'\t' read -r k v; do
    bg_is_key "$k" && eval "bgv_$k=\$v"
  done < "$f"
  return 0
}

# bg_write <file> — the one path that serializes bgv_* into the TSV record.
# Every accepted value is re-checked for framing HERE, not trusted from
# whatever set it: a caller that adds a new bgv_<key> and forgets to call
# bg_reject_framing at parse time still cannot smuggle a newline/tab/CR into
# the file, because nothing reaches disk without passing this boundary first.
bg_write() {
  local f="$1" k v
  mkdir -p "$(dirname "$f")" || return 1
  for k in $BUDGET_KEYS; do
    eval "v=\$bgv_$k"
    [ -n "$v" ] || continue
    bg_reject_framing "$k" "$v" || return 1
  done
  {
    printf '%s\t%s\n' "$BUDGET_FORMAT_KEY" "$BUDGET_FORMAT_VAL"
    for k in $BUDGET_KEYS; do
      eval "v=\$bgv_$k"
      if [ -n "$v" ]; then printf '%s\t%s\n' "$k" "$v"; fi
    done
  } > "$f"
}

# bg_over <used> <max> — true only when a bound EXISTS and has been reached.
# An undeclared bound is not a bound of zero; it is simply not declared, and
# treating absence as a limit would stop every run that declined to guess.
bg_over() {
  case "$2" in ''|*[!0-9]*) return 1 ;; esac
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -ge "$2" ]
}

# bg_over_cost <used> <max> — the same rule for the one decimal bound.
bg_over_cost() {
  case "$1" in '') return 1 ;; esac
  case "$2" in '') return 1 ;; esac
  awk -v u="$1" -v m="$2" 'BEGIN { exit !(u + 0 >= m + 0) }'
}

cmd_budget() {
  local usage_line="usage: spark budget [declare|record|check|status|reopen] --run <id> [--convergence <text>] [--max-<bound> <n>] [--failing <n>] [--kind full|targeted] [--reason <text>] [--json]"
  local action=""
  case "${1:-}" in
    declare|record|check|status|reopen) action="$1"; shift ;;
    *) action="status" ;;
  esac

  local run="" kind="" json="" reason="" failing="" convergence="" bg_pairs_n=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --run)   shift; run="${1:-}" ;;
      --run=*) run="${1#--run=}" ;;
      --kind)  shift; kind="${1:-}" ;;
      --kind=*) kind="${1#--kind=}" ;;
      --reason) shift; reason="${1:-}" ;;
      --reason=*) reason="${1#--reason=}" ;;
      --failing) shift; failing="${1:-}" ;;
      --failing=*) failing="${1#--failing=}" ;;
      --convergence) shift; convergence="${1:-}" ;;
      --convergence=*) convergence="${1#--convergence=}" ;;
      --json) json=1 ;;
      -h|--help) echo "$usage_line"; return 0 ;;
      --max-*)
        local mk="${1#--max-}"; mk="max_$(printf '%s' "$mk" | tr '-' '_')"
        shift
        # Checked here, on the raw argv value, so a bad --max-* flag is named
        # in the error instead of a generic write failure. This is a UX
        # nicety, not the guarantee: bg_stage never joins values into a
        # splittable string, so bg_apply_staged re-validates the exact same
        # unsplit value regardless of whether this precheck ran.
        bg_reject_framing "$mk" "${1:-}" || return 1
        bg_stage "$mk" "${1:-}" ;;
      --per-request-output-cap)
        shift; bg_reject_framing per_request_output_cap "${1:-}" || return 1
        bg_stage per_request_output_cap "${1:-}" ;;
      --preflight-tokens)
        shift; bg_reject_framing preflight_tokens "${1:-}" || return 1
        bg_stage preflight_tokens "${1:-}" ;;
      --model)
        shift; bg_reject_framing model "${1:-}" || return 1
        bg_stage model "${1:-}" ;;
      --effort)
        shift; bg_reject_framing effort "${1:-}" || return 1
        bg_stage effort "${1:-}" ;;
      *) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
    esac
    shift
  done

  local top
  top="$(git_root)"; if [ -z "$top" ]; then
    red "spark budget needs a git repo — run it from inside the project."
    return 1
  fi
  [ -n "$run" ] || run="${SPARK_RUN_ID:-current}"
  if ! tm_valid_run "$run"; then
    red "invalid run id: '$run' (letters, digits, dot, dash and underscore only)"
    return 1
  fi

  local file tfile
  file="$(bg_file "$top" "$run")"
  tfile="$(tm_file "$top" "$run")"
  bg_load "$file"

  # A pre-fix multi-line record with no format stamp cannot be told apart from
  # one whose extra lines were injected through an unsanitized text value
  # (#642). `declare` is the repair path — it replaces the file outright from
  # freshly validated input, which is the one migration that is mechanically
  # unambiguous. Every other action would otherwise trust unverifiable state,
  # so it fails closed with repair guidance instead.
  if [ -n "$bg_load_ambiguous" ] && [ "$action" != "declare" ]; then
    red "budget record for run '$run' predates the text-injection fix (#642) and cannot be verified safe"
    yellow "  it has more than one line but no format stamp, so an injected line cannot be told apart from a legitimate one."
    yellow "  repair: inspect and back up $file first — 'declare' replaces the record outright, it does not read the old one."
    yellow "  redeclare EVERY intended bound: 'spark budget declare --run $run --convergence \"...\"' plus every --max-... / --model / --effort the run depends on, or remove $file and declare fresh."
    return 1
  fi

  case "$action" in
    declare)
      if [ -z "$convergence" ] && [ -z "$bgv_convergence" ]; then
        red "a bounded run must declare its convergence condition first (--convergence)"
        yellow "  budgets bound a run; they do not tell it what finishing means."
        return 1
      fi
      if [ -n "$convergence" ]; then
        bg_reject_framing convergence "$convergence" || return 1
        bgv_convergence="$convergence"
      fi
      bg_apply_staged || return 1
      [ -n "$bgv_max_no_progress" ] || bgv_max_no_progress="$BUDGET_DEFAULT_NO_PROGRESS"
      bg_write "$file" || { red "could not write $file"; return 1; }
      green "budget: $file"
      ;;

    record)
      case "$failing" in
        ''|*[!0-9]*) red "spark budget record needs --failing <n>, the size of the known failing set"; return 1 ;;
      esac
      # The previous size is kept so "is it shrinking?" is answerable without
      # re-deriving it from a log that may no longer exist.
      # A first record has no previous size. Inventing one would make the very
      # first reading report "static", which is an opinion about a trend that
      # does not exist yet.
      local first_record=""
      if [ -z "$bgv_failing" ]; then first_record=1; fi
      if [ -n "$bgv_failing" ] && [ "$bgv_failing" != "$failing" ]; then
        bgv_failing_prev="$bgv_failing"
      fi
      bgv_failing="$failing"
      bg_write "$file" || { red "could not write $file"; return 1; }
      if [ -n "$first_record" ]; then
        green "failing set: $failing (first record)"
      else
        green "failing set: $failing (was ${bgv_failing_prev:-$failing})"
      fi
      ;;

    reopen)
      if [ -z "$reason" ]; then
        red "reopening a converged or stopped run needs --reason: the new release-critical evidence"
        return 1
      fi
      bg_reject_framing reason "$reason" || return 1
      [ -n "$bgv_convergence" ] || { red "no budget declared for run '$run'"; return 1; }
      bgv_reopen_count="$(( ${bgv_reopen_count:-0} + 1 ))"
      bgv_reopen_reason="$reason"
      # A deliberate reopen clears the no-progress escalation and buys one more
      # expensive verification. It never clears the failing set: new evidence
      # reopens the work, it does not absolve it.
      bgv_no_progress_runs=0
      bgv_last_expensive_failing=""
      if [ -n "$bgv_max_full_suite" ]; then
        bgv_max_full_suite="$(( bgv_max_full_suite + 1 ))"
      fi
      bg_write "$file" || { red "could not write $file"; return 1; }
      yellow "REOPENED (#${bgv_reopen_count}) — $reason"
      echo "The failing set is unchanged at ${bgv_failing:-NOT ASSESSED}; reopening admits new work, it does not clear old findings."
      ;;

    check)
      if [ -z "$bgv_convergence" ]; then
        red "STOP — run '$run' has no declared convergence condition, so no spend can be authorized"
        yellow "  declare one first: spark budget declare --run $run --convergence \"...\""
        return 1
      fi
      case "$kind" in
        full|targeted) ;;
        '') red "spark budget check needs --kind full|targeted"; return 1 ;;
        *) red "unknown check kind: $kind (full|targeted)"; return 1 ;;
      esac

      # Facts come from the run's telemetry record — the same run id, recorded
      # by whoever did the work. The budget never re-measures them.
      local t_iter t_tool t_api t_wall t_cost
      t_iter="$(tm_get "$tfile" iterations)"
      t_tool="$(tm_get "$tfile" tool_calls)"
      t_api="$(tm_get "$tfile" api_requests)"
      t_wall="$(tm_get "$tfile" wall_seconds)"
      t_cost="$(tm_get "$tfile" cost_usd)"

      # Convergence is checked before any bound: a run that has finished is not
      # stopped by a budget, it is simply done.
      if [ "$kind" = "full" ] && [ "$bgv_failing" = "0" ]; then
        green "CONVERGED — $bgv_convergence"
        echo "  the failing set is empty; the autonomous repair loop is finished"
        return 4
      fi

      local hard=""
      if [ "$kind" = "full" ] && bg_over "${bgv_expensive_runs:-0}" "$bgv_max_full_suite"; then
        hard="full-suite verifications (${bgv_expensive_runs:-0} of $bgv_max_full_suite)"
      fi
      if [ -z "$hard" ] && bg_over "$t_iter" "$bgv_max_iterations"; then
        hard="repair iterations ($t_iter of $bgv_max_iterations)"
      fi
      if [ -z "$hard" ] && bg_over "$t_tool" "$bgv_max_tool_calls"; then
        hard="tool calls ($t_tool of $bgv_max_tool_calls)"
      fi
      if [ -z "$hard" ] && bg_over "$t_api" "$bgv_max_api_requests"; then
        hard="remote API requests ($t_api of $bgv_max_api_requests)"
      fi
      if [ -z "$hard" ] && bg_over "$t_wall" "$bgv_max_wall_seconds"; then
        hard="wall seconds ($t_wall of $bgv_max_wall_seconds)"
      fi
      if [ -z "$hard" ] && bg_over_cost "$t_cost" "$bgv_max_cost_usd"; then
        hard="estimated cost ($t_cost of $bgv_max_cost_usd)"
      fi
      if [ -n "$hard" ]; then
        red "STOP — budget boundary reached: $hard"
        echo "  remaining failing set: ${bgv_failing:-NOT ASSESSED} — a budget stops work, it never clears it"
        return 2
      fi

      if [ "$kind" = "targeted" ]; then
        # Targeted checks are the cheap half, so their bound is a SOFT signal:
        # crossing it while the failing set is still shrinking is productive
        # work, not a runaway, and stopping it would punish the behaviour the
        # whole contract is trying to encourage.
        local soft=""
        if bg_over "${bgv_targeted_runs:-0}" "$bgv_max_targeted"; then soft=1; fi
        # Movement is measured against the failing set at the LAST TARGETED
        # CHECK, not the last time anyone recorded one. Comparing against a
        # stale record lets a run cross the signal once and then coast on that
        # single improvement forever, which is the runaway in a costume.
        if [ -n "$soft" ]; then
          if [ -n "$bgv_failing" ] && [ -n "$bgv_last_targeted_failing" ] && \
             [ "$bgv_failing" -lt "$bgv_last_targeted_failing" ]; then
            bgv_targeted_runs="$(( ${bgv_targeted_runs:-0} + 1 ))"
            yellow "PROCEED (over soft signal) — targeted checks ${bgv_targeted_runs} of $bgv_max_targeted"
            echo "  the failing set is shrinking ($bgv_last_targeted_failing -> $bgv_failing), so the run is converging"
            bgv_last_targeted_failing="$bgv_failing"
            bg_write "$file"
            return 0
          fi
          red "STOP — targeted checks ${bgv_targeted_runs:-0} of $bgv_max_targeted with no movement in the failing set"
          echo "  remaining failing set: ${bgv_failing:-NOT ASSESSED} — a budget stops work, it never clears it"
          return 2
        fi
        bgv_targeted_runs="$(( ${bgv_targeted_runs:-0} + 1 ))"
        bgv_last_targeted_failing="${bgv_failing:-}"
        bg_write "$file"
        green "PROCEED — targeted check ${bgv_targeted_runs}"
        return 0
      fi

      # An expensive verification repeated over an unchanged failing set is the
      # exact waste this issue names. Allow it once (the failing set can be
      # unchanged for a legitimate reason), then escalate rather than let the
      # loop keep buying the same answer.
      local material=1
      if [ -n "$bgv_last_expensive_failing" ] && [ "$bgv_last_expensive_failing" = "${bgv_failing:-}" ]; then
        material=""
      fi
      if [ -z "$material" ]; then
        bgv_no_progress_runs="$(( ${bgv_no_progress_runs:-0} + 1 ))"
        if [ "${bgv_no_progress_runs}" -gt "${bgv_max_no_progress:-$BUDGET_DEFAULT_NO_PROGRESS}" ]; then
          bg_write "$file"
          red "ESCALATE — ${bgv_no_progress_runs} full verifications with the failing set static at ${bgv_failing:-NOT ASSESSED}"
          echo "  repeating it will buy the same answer; a human decision or new evidence is needed"
          return 3
        fi
        bgv_expensive_runs="$(( ${bgv_expensive_runs:-0} + 1 ))"
        bg_write "$file"
        yellow "PROCEED (no material change) — full verification ${bgv_expensive_runs}, failing set static at ${bgv_failing:-NOT ASSESSED}"
        return 0
      fi

      bgv_no_progress_runs=0
      bgv_expensive_runs="$(( ${bgv_expensive_runs:-0} + 1 ))"
      bgv_last_expensive_failing="${bgv_failing:-}"
      bg_write "$file"
      green "PROCEED — full verification ${bgv_expensive_runs}"
      if [ -n "$bgv_failing" ]; then echo "  known failing set: $bgv_failing"; fi
      return 0
      ;;

    status)
      [ -f "$file" ] || { yellow "no budget declared for run '$run'"; return 0; }
      local shrinking="NOT ASSESSED"
      if [ -n "$bgv_failing" ] && [ -n "$bgv_failing_prev" ]; then
        if   [ "$bgv_failing" -lt "$bgv_failing_prev" ]; then shrinking="yes ($bgv_failing_prev -> $bgv_failing)"
        elif [ "$bgv_failing" -gt "$bgv_failing_prev" ]; then shrinking="no — it grew ($bgv_failing_prev -> $bgv_failing)"
        else shrinking="no — static at $bgv_failing"; fi
      fi
      if [ -n "$json" ]; then
        local k v first=1
        bg_json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
        printf '{"run":"%s","declared":{' "$(bg_json_escape "$run")"
        for k in $BUDGET_DECLARED; do
          eval "v=\$bgv_$k"
          [ "$first" -eq 1 ] && first=0 || printf ','
          if [ -z "$v" ]; then printf '"%s":null' "$k"
          elif bg_is_int_key "$k"; then printf '"%s":%s' "$k" "$v"
          else printf '"%s":"%s"' "$k" "$(bg_json_escape "$v")"; fi
        done
        printf '},"state":{'
        first=1
        for k in $BUDGET_STATE; do
          eval "v=\$bgv_$k"
          [ "$first" -eq 1 ] && first=0 || printf ','
          if [ -z "$v" ]; then printf '"%s":null' "$k"
          elif bg_is_int_key "$k"; then printf '"%s":%s' "$k" "$v"
          else printf '"%s":"%s"' "$k" "$(bg_json_escape "$v")"; fi
        done
        printf '},"shrinking":"%s"}\n' "$(bg_json_escape "$shrinking")"
        return 0
      fi
      bg_row() { printf '  %-26s %s\n' "$1" "$2"; }
      printf 'Spark run budget — run %s\n\n' "$run"
      bg_row "convergence condition" "${bgv_convergence:-NOT ASSESSED}"
      echo
      echo "envelope"
      bg_row "repair iterations"    "${bgv_max_iterations:-not bounded}"
      bg_row "full verifications"   "${bgv_max_full_suite:-not bounded}"
      bg_row "targeted checks"      "${bgv_max_targeted:-not bounded}"
      bg_row "tool calls"           "${bgv_max_tool_calls:-not bounded}"
      bg_row "remote API requests"  "${bgv_max_api_requests:-not bounded}"
      bg_row "wall seconds"         "${bgv_max_wall_seconds:-not bounded}"
      bg_row "estimated cost USD"   "${bgv_max_cost_usd:-not bounded}"
      bg_row "no-progress repeats"  "${bgv_max_no_progress:-not bounded}"
      echo
      echo "routing inputs (not budgets)"
      bg_row "model / effort"       "${bgv_model:-NOT ASSESSED} / ${bgv_effort:-NOT ASSESSED}"
      bg_row "preflight tokens"     "${bgv_preflight_tokens:-NOT ASSESSED}"
      # A provider cap bounds ONE request. An episode is many requests and many
      # tool calls, so this can never be read as the task's budget; it is
      # printed apart from the envelope so the two cannot be confused.
      bg_row "per-request output cap" "${bgv_per_request_output_cap:-NOT ASSESSED} (bounds one request, not this run)"
      echo
      echo "progress"
      bg_row "known failing set"    "${bgv_failing:-NOT ASSESSED}"
      bg_row "shrinking"            "$shrinking"
      bg_row "full verifications"   "${bgv_expensive_runs:-0}"
      bg_row "targeted checks"      "${bgv_targeted_runs:-0}"
      bg_row "no-progress repeats"  "${bgv_no_progress_runs:-0}"
      if [ -n "$bgv_reopen_count" ]; then
        echo
        echo "deliberate reopens"
        bg_row "count"  "$bgv_reopen_count"
        bg_row "reason" "$bgv_reopen_reason"
      fi
      ;;
    *)
      red "unknown budget action: $action"; echo "$usage_line"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# spark evidence — capture a fact once, share it, and know when it went stale (#576)
#
# Autonomous runs pay repeatedly for the same facts: the same remote read
# performed by each consumer that needs it, whole surfaces re-fetched when a
# range would do, and evidence carried forward past the moment it stopped being
# true. The first two are waste. The third is a correctness bug wearing the
# costume of an optimization, and it is the one this is built around.
#
#   capture once -> project -> many consumers -> invalidate on named inputs
#
# Freshness is decided by INVALIDATORS the caller states outright -- the commit,
# the governing contract, the model, the effort class, the tool surface. A
# capture is reusable only while every one of them is unchanged, and when one
# has moved the refusal NAMES IT, because "stale" without a cause is a thing
# nobody can act on.
#
# Completeness is decided by a declared bound. A capture that hit its bound is
# marked NOT ASSESSED and says so on every read: partial evidence presented as
# whole evidence is how a run concludes something false cheaply. Reducing cost
# is never a licence to reduce truth -- a smaller answer that might be wrong is
# not an optimization.
EVIDENCE_INVALIDATORS="head contract model effort tools"
EVIDENCE_FIELDS="$EVIDENCE_INVALIDATORS bound count truncated consumers captured"

ev_dir()     { printf '%s/.spark/evidence' "$1"; }
ev_file()    { printf '%s/.spark/evidence/%s.tsv' "$1" "$2"; }
ev_payload() { printf '%s/.spark/evidence/%s.data' "$1" "$2"; }

ev_get() {
  [ -f "$1" ] || return 0
  awk -F'\t' -v k="$2" '$1 == k { v = $2 } END { if (v != "") print v }' "$1"
}

ev_load() {
  local f="$1" k v
  for k in $EVIDENCE_FIELDS; do eval "evv_$k=''"; done
  [ -f "$f" ] || return 0
  while IFS=$'\t' read -r k v; do
    case " $EVIDENCE_FIELDS " in *" $k "*) eval "evv_$k=\$v" ;; esac
  done < "$f"
  return 0
}

ev_write() {
  local f="$1" k v
  mkdir -p "$(dirname "$f")" || return 1
  {
    for k in $EVIDENCE_FIELDS; do
      eval "v=\$evv_$k"
      if [ -n "$v" ]; then printf '%s\t%s\n' "$k" "$v"; fi
    done
  } > "$f"
}

# ev_drift <field> <recorded> <asked> — one line naming what moved, or empty when
# the field is not an invalidator for this read. An invalidator the caller did NOT
# state cannot invalidate: absence on the READER side is not a mismatch, or every
# consumer would have to restate the whole fingerprint to read anything. But when
# the reader DOES state a field the capture never recorded, that is NOT a match: the
# capture was never bound to what the reader requires, so it drifts and is stale
# (#647) — a capture made without --head is not fresh to a reader asking for a HEAD.
ev_drift() {
  [ -n "$3" ] || return 0
  if [ -z "$2" ]; then
    printf 'the %s was requested (%s) but the capture never recorded it' "$1" "$3"
    return 0
  fi
  [ "$2" = "$3" ] && return 0
  printf 'the %s changed (%s -> %s)' "$1" "$2" "$3"
}

# ev_tokens <file...> — the same bytes/FOOTPRINT_CPT heuristic the footprint
# gate uses, so a preflight estimate and a footprint report cannot disagree
# about what a surface costs.
ev_tokens() {
  local total=0 f b
  for f in "$@"; do
    [ -f "$f" ] || continue
    b=$(wc -c < "$f" | tr -d ' ')
    total=$((total + b))
  done
  printf '%s' $((total / FOOTPRINT_CPT))
}

cmd_evidence() {
  local usage_line="usage: spark evidence [put|get|preflight|status|forget] --key <name> [--head <sha>] [--contract <id>] [--model <m>] [--effort <e>] [--tools <digest>] [--bound <n>] [--count <n>] [--from <file>] [--budget <n>] [--json] [--force]"
  local action=""
  case "${1:-}" in
    put|get|preflight|status|forget) action="$1"; shift ;;
    *) action="status" ;;
  esac

  local key="" head="" contract="" model="" effort="" tools=""
  local bound="" count="" from="" budget="" json="" force="" files=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --key)      shift; key="${1:-}" ;;
      --key=*)    key="${1#--key=}" ;;
      --head)     shift; head="${1:-}" ;;
      --head=*)   head="${1#--head=}" ;;
      --contract) shift; contract="${1:-}" ;;
      --contract=*) contract="${1#--contract=}" ;;
      --model)    shift; model="${1:-}" ;;
      --model=*)  model="${1#--model=}" ;;
      --effort)   shift; effort="${1:-}" ;;
      --effort=*) effort="${1#--effort=}" ;;
      --tools)    shift; tools="${1:-}" ;;
      --tools=*)  tools="${1#--tools=}" ;;
      --bound)    shift; bound="${1:-}" ;;
      --bound=*)  bound="${1#--bound=}" ;;
      --count)    shift; count="${1:-}" ;;
      --count=*)  count="${1#--count=}" ;;
      --from)     shift; from="${1:-}" ;;
      --from=*)   from="${1#--from=}" ;;
      --budget)   shift; budget="${1:-}" ;;
      --budget=*) budget="${1#--budget=}" ;;
      --json)     json=1 ;;
      --force)    force=1 ;;
      -h|--help)  echo "$usage_line"; return 0 ;;
      -*) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
      *)  files="${files}$1
" ;;
    esac
    shift
  done

  local top
  top="$(git_root)"; if [ -z "$top" ]; then
    red "spark evidence needs a git repo — run it from inside the project."
    return 1
  fi

  if [ "$action" = "preflight" ]; then
    # Estimating BEFORE dispatch is the whole point: discovering that a bundle
    # was too large after paying for generation is the failure this prevents.
    local list="" f est
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ ! -f "$f" ]; then red "no such file: $f"; return 1; fi
      list="$list $f"
    done <<EOF
$files
EOF
    if [ -z "$list" ]; then
      red "spark evidence preflight needs one or more files to estimate"
      return 1
    fi
    est="$(ev_tokens $list)"
    case "$budget" in
      ''|*[!0-9]*)
        if [ -n "$json" ]; then
          printf '{"estimate":%s,"budget":null,"verdict":"NOT ASSESSED"}\n' "$est"
        else
          echo "Preflight estimate: ~$est tokens (bytes ÷ $FOOTPRINT_CPT; heuristic, not a tokenizer)"
          echo "  no --budget given, so whether it fits is NOT ASSESSED"
        fi
        return 0 ;;
    esac
    if [ "$est" -gt "$budget" ]; then
      if [ -n "$json" ]; then
        printf '{"estimate":%s,"budget":%s,"verdict":"OVER BUDGET"}\n' "$est" "$budget"
      else
        red "OVER BUDGET — ~$est tokens against a budget of $budget"
        echo "  reroute or reduce the evidence set before dispatch, not after generation"
      fi
      return 2
    fi
    if [ -n "$json" ]; then
      printf '{"estimate":%s,"budget":%s,"verdict":"WITHIN BUDGET"}\n' "$est" "$budget"
    else
      green "WITHIN BUDGET — ~$est tokens of $budget"
    fi
    return 0
  fi

  if [ "$action" = "status" ]; then
    local any=0 f k
    for f in "$(ev_dir "$top")"/*.tsv; do
      [ -f "$f" ] || continue
      any=1; k="$(basename "$f" .tsv)"
      if [ -n "$json" ]; then
        printf '{"key":"%s","head":"%s","consumers":%s,"truncated":"%s"}\n' \
          "$k" "$(ev_get "$f" head)" "$(ev_get "$f" consumers)" "$(ev_get "$f" truncated)"
      else
        printf '%-24s head=%-12s consumers=%-4s %s\n' "$k" \
          "$(ev_get "$f" head)" "$(ev_get "$f" consumers)" \
          "$([ "$(ev_get "$f" truncated)" = "yes" ] && echo 'NOT ASSESSED (bound exceeded)' || echo complete)"
      fi
    done
    [ "$any" -eq 1 ] || yellow "no captures under .spark/evidence"
    return 0
  fi

  if [ -z "$key" ]; then red "spark evidence $action needs --key <name>"; return 1; fi
  if ! tm_valid_run "$key"; then
    red "invalid key: '$key' (letters, digits, dot, dash and underscore only — the key becomes a filename)"
    return 1
  fi

  local file payload
  file="$(ev_file "$top" "$key")"
  payload="$(ev_payload "$top" "$key")"
  ev_load "$file"

  case "$action" in
    forget)
      [ -f "$file" ] || { yellow "no capture for key '$key'"; return 0; }
      rm -f "$file" "$payload"
      green "forgot capture '$key'"
      ;;

    put)
      # A second producer of a fact that is already captured and still fresh is
      # the duplicate collection this is meant to make detectable. Say so and
      # reuse it rather than paying for the same remote read again.
      if [ -f "$file" ] && [ -z "$force" ]; then
        local drift="" d
        for d in $EVIDENCE_INVALIDATORS; do
          local recorded asked
          eval "recorded=\$evv_$d"
          eval "asked=\$$d"
          local msg; msg="$(ev_drift "$d" "$recorded" "$asked")"
          if [ -n "$msg" ]; then drift="$msg"; break; fi
        done
        if [ -z "$drift" ]; then
          yellow "already captured — reusing '$key' (${evv_consumers:-0} consumer(s) so far)"
          echo "  one capture, many consumers: pass --force to deliberately recapture"
          return 0
        fi
      fi

      local data
      if [ -n "$from" ]; then
        [ -f "$from" ] || { red "no such file: $from"; return 1; }
        data="$(cat "$from")"
      else
        data="$(cat)"
      fi

      for d in $EVIDENCE_INVALIDATORS; do eval "evv_$d=\$$d"; done
      evv_bound="$bound"; evv_count="$count"
      evv_consumers=0
      evv_captured="$(date +%F)"
      evv_truncated="no"
      # A capture that reached its declared bound is incomplete, and incomplete
      # evidence must announce itself on every single read.
      if [ -n "$bound" ] && [ -n "$count" ]; then
        case "$bound$count" in
          *[!0-9]*) red "--bound and --count must be whole numbers"; return 1 ;;
        esac
        if [ "$count" -ge "$bound" ]; then evv_truncated="yes"; fi
      fi

      mkdir -p "$(ev_dir "$top")" || { red "could not create $(ev_dir "$top")"; return 1; }
      printf '%s\n' "$data" > "$payload" || { red "could not write $payload"; return 1; }
      ev_write "$file" || { red "could not write $file"; return 1; }
      if [ "$evv_truncated" = "yes" ]; then
        yellow "captured '$key' — NOT ASSESSED: the capture hit its bound ($count of $bound)"
      else
        green "captured '$key'"
      fi
      ;;

    get)
      # get is a data-producing command: stdout carries the payload and nothing
      # else, so a consumer can pipe it straight into whatever needed the fact.
      # Diagnostics go to stderr or they end up inside the evidence.
      if [ ! -f "$file" ]; then
        yellow "no capture for key '$key' — collect it once, then share it" >&2
        return 1
      fi
      local d drift=""
      for d in $EVIDENCE_INVALIDATORS; do
        local recorded asked msg
        eval "recorded=\$evv_$d"
        eval "asked=\$$d"
        msg="$(ev_drift "$d" "$recorded" "$asked")"
        if [ -n "$msg" ]; then drift="$msg"; break; fi
      done
      if [ -n "$drift" ]; then
        red "STALE — $drift" >&2
        echo "  the capture describes an earlier state; a reused capture can never make an old verdict valid" >&2
        return 2
      fi
      evv_consumers="$(( ${evv_consumers:-0} + 1 ))"
      ev_write "$file"
      if [ "$evv_truncated" = "yes" ]; then
        yellow "NOT ASSESSED — this capture hit its bound (${evv_count} of ${evv_bound}); it is partial evidence" >&2
        cat "$payload"
        return 4
      fi
      cat "$payload"
      ;;
    *)
      red "unknown evidence action: $action"; echo "$usage_line"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# spark route — capability, cost and escalation policy (#575)
#
# Sending every task to the strongest model wastes money and latency; sending
# everything to the cheapest risks correctness. Neither is a policy. This makes
# the tradeoff governed DATA: the code resolves classes, and the policy file
# says what a class currently means.
#
# Nothing here names a provider model. Model ids, effort levels, availability
# and prices are configuration that changes underneath a stable semantics; a
# model id compiled into routing logic becomes product truth the day it ships
# and a lie the day the model is retired.
#
# Two rules matter more than the arithmetic:
#
#   * The human class is not a strength tier. Escalation walks one rank at a
#     time and STOPS at the decision boundary — a DECISION REQUIRED that could
#     be escalated into an autonomous attempt is not a boundary at all.
#   * A failed cheap attempt is still spend. The comparison that decides whether
#     a two-stage route was worth it must carry the wasted attempt, or "start
#     cheap and escalate" wins every argument by not counting its losses.
ROUTE_POLICY_BASENAME="routing-classes.tsv"

# route_policy_file — the project's override, else the shipped default. One
# file, wholly replaced, because a half-overridden policy is harder to reason
# about than a different one.
route_policy_file() {
  local top="$1"
  if [ -n "$top" ] && [ -f "$top/.spark/$ROUTE_POLICY_BASENAME" ]; then
    printf '%s' "$top/.spark/$ROUTE_POLICY_BASENAME"
    return 0
  fi
  printf '%s' "$SPARK_ROOT/preferences/$ROUTE_POLICY_BASENAME"
}

route_rows() {  # route_rows <file> <kind> — comment-stripped records of one kind
  awk -F'\t' -v want="$2" '/^[[:space:]]*(#|$)/ { next } $1 == want' "$1"
}

route_class_rank() { route_rows "$1" class | awk -F'\t' -v c="$2" '$2 == c { print $3; exit }'; }
route_class_desc() { route_rows "$1" class | awk -F'\t' -v c="$2" '$2 == c { print $4; exit }'; }
route_model()      { route_rows "$1" model | awk -F'\t' -v c="$2" '$2 == c { print $3; exit }'; }
route_effort()     { route_rows "$1" model | awk -F'\t' -v c="$2" '$2 == c { print $4; exit }'; }

# The rank reserved for the point where routing stops rather than strengthens.
ROUTE_HUMAN_RANK=9

rt_dir()    { printf '%s/.spark/routing' "$1"; }
rt_run()    { printf '%s/.spark/routing/%s.tsv' "$1" "$2"; }
rt_ledger() { printf '%s/.spark/routing/ledger.tsv' "$1"; }

rt_get() {
  [ -f "$1" ] || return 0
  awk -F'\t' -v k="$2" '$1 == k { v = $2 } END { if (v != "") print v }' "$1"
}

cmd_route() {
  local usage_line="usage: spark route [policy|select|escalate|attempt|benchmark] [--task <kind>] [--run <id>] [--reason <text>] [--outcome pass|fail] [--json] [--rebuild-cache]"
  local action=""
  case "${1:-}" in
    policy|select|escalate|attempt|benchmark) action="$1"; shift ;;
    *) action="policy" ;;
  esac

  local task="" run="" reason="" outcome="" json="" rebuild=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --task)    shift; task="${1:-}" ;;
      --task=*)  task="${1#--task=}" ;;
      --run)     shift; run="${1:-}" ;;
      --run=*)   run="${1#--run=}" ;;
      --reason)  shift; reason="${1:-}" ;;
      --reason=*) reason="${1#--reason=}" ;;
      --outcome) shift; outcome="${1:-}" ;;
      --outcome=*) outcome="${1#--outcome=}" ;;
      --json)    json=1 ;;
      --rebuild-cache) rebuild=1 ;;
      -h|--help) echo "$usage_line"; return 0 ;;
      *) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
    esac
    shift
  done

  # A run id becomes a repository-local filename (.spark/routing/<run>.tsv and the
  # run's telemetry), so it must pass the one canonical rule BEFORE any action reads
  # or writes with it — a traversal or separator would escape the runtime-state
  # directory and overwrite tracked files (#648). Empty is allowed (select without a
  # run simply does not record); a stated id must validate, for every action.
  if [ -n "$run" ] && ! tm_valid_run "$run"; then
    red "spark route: invalid run id '$run' (letters, digits, dot, dash, underscore only — it becomes a filename)"
    return 1
  fi

  local top policy
  top="$(git_root)"
  policy="$(route_policy_file "$top")"
  if [ ! -f "$policy" ]; then
    red "no routing policy at $policy"
    return 1
  fi

  case "$action" in
    policy)
      if [ -n "$json" ]; then
        local first=1 c r d
        printf '{"policy":"%s","classes":[' "$policy"
        while IFS=$'\t' read -r _ c r d; do
          [ "$first" -eq 1 ] && first=0 || printf ','
          printf '{"class":"%s","rank":%s,"model":"%s","effort":"%s"}' \
            "$c" "$r" "$(route_model "$policy" "$c")" "$(route_effort "$policy" "$c")"
        done < <(route_rows "$policy" class)
        printf ']}\n'
        return 0
      fi
      echo "Spark routing policy — $policy"
      echo
      printf '  %-16s %5s %-30s %s\n' class rank model effort
      local c r d cm ce
      while IFS=$'\t' read -r _ c r d; do
        cm="$(route_model "$policy" "$c")"; ce="$(route_effort "$policy" "$c")"
        # A class with no model row is not misconfigured — it is the boundary
        # where routing stops, and printing an empty column would read as one.
        if [ -z "$cm" ]; then cm="(not routed to a model)"; ce="—"; fi
        printf '  %-16s %5s %-30s %s\n' "$c" "$r" "$cm" "$ce"
      done < <(route_rows "$policy" class)
      echo
      echo "task routes"
      route_rows "$policy" route | awk -F'\t' '{ printf "  %-20s %-16s %s\n", $2, $3, $4 }'
      echo
      echo "escalation rules (one rank at a time)"
      route_rows "$policy" escalate | awk -F'\t' '{ printf "  %-16s -> %-16s %s\n", $2, $3, $4 }'
      ;;

    select)
      if [ -z "$task" ]; then
        red "spark route select needs --task <kind>"
        echo "  known kinds: $(route_rows "$policy" route | awk -F'\t' '{ printf "%s%s", (n++ ? ", " : ""), $2 }')"
        return 1
      fi
      local class why
      class="$(route_rows "$policy" route | awk -F'\t' -v t="$task" '$2 == t { print $3; exit }')"
      why="$(route_rows "$policy" route | awk -F'\t' -v t="$task" '$2 == t { print $4; exit }')"
      if [ -z "$class" ]; then
        red "no route declared for task kind '$task'"
        echo "  known kinds: $(route_rows "$policy" route | awk -F'\t' '{ printf "%s%s", (n++ ? ", " : ""), $2 }')"
        return 1
      fi
      local rank model effort
      rank="$(route_class_rank "$policy" "$class")"
      model="$(route_model "$policy" "$class")"
      effort="$(route_effort "$policy" "$class")"

      # The decision boundary is not a cheap tier to be upgraded past. Routing
      # reports that a person owns this and declines to name a model at all.
      if [ "$rank" = "$ROUTE_HUMAN_RANK" ]; then
        if [ -n "$json" ]; then
          printf '{"task":"%s","class":"%s","model":null,"effort":null,"reason":"%s","autonomous":false}\n' \
            "$task" "$class" "$why"
        else
          yellow "DECISION REQUIRED — '$task' routes to the human class"
          echo "  $why"
          echo "  no model is selected: this boundary is not a capability tier to escalate past"
        fi
        return 5
      fi

      # Effort is a cache invalidator. Changing it mid-conversation silently
      # rebuilds the prefix, which is a cost that does not appear on the line
      # item that motivated the change.
      local tfile prev
      if [ -n "$run" ] && [ -n "$top" ]; then
        tfile="$(tm_file "$top" "$run")"
        prev="$(tm_get "$tfile" effort)"
        if [ -n "$prev" ] && [ "$prev" != "$effort" ] && [ -z "$rebuild" ]; then
          red "STOP — run '$run' is already at effort '$prev'; routing '$task' would move it to '$effort'"
          echo "  changing effort mid-conversation invalidates the cached prefix."
          echo "  route this between work units, or pass --rebuild-cache to accept the rebuild."
          return 2
        fi
        mkdir -p "$(rt_dir "$top")" 2>/dev/null || true
        {
          printf 'class\t%s\n' "$class"
          printf 'task\t%s\n' "$task"
        } > "$(rt_run "$top" "$run")" 2>/dev/null || true
        # The route and its reason belong in the run's telemetry, so cost and
        # cache effect are read beside the decision that caused them.
        "$SPARK_ROOT/bin/spark" telemetry record --run "$run" \
          model="$model" effort="$effort" routing_reason="$why" >/dev/null 2>&1 || true
      fi

      if [ -n "$json" ]; then
        printf '{"task":"%s","class":"%s","model":"%s","effort":"%s","reason":"%s","autonomous":true}\n' \
          "$task" "$class" "$model" "$effort" "$why"
      else
        green "route: $task -> $class"
        printf '  %-10s %s\n' model "$model"
        printf '  %-10s %s\n' effort "$effort"
        printf '  %-10s %s\n' reason "$why"
        echo "  the cheapest adequate class for this kind of work; strength is bought deliberately"
      fi
      ;;

    escalate)
      if [ -z "$run" ]; then red "spark route escalate needs --run <id>"; return 1; fi
      if [ -z "$reason" ]; then
        red "escalation needs --reason: what evidence showed the cheaper path was insufficient"
        yellow "  escalating without a recorded cause is just starting at the top one step later."
        return 1
      fi
      [ -n "$top" ] || { red "spark route escalate needs a git repo"; return 1; }
      local rfile from
      rfile="$(rt_run "$top" "$run")"
      from="$(rt_get "$rfile" class)"
      if [ -z "$from" ]; then
        red "run '$run' has no selected route to escalate from"
        return 1
      fi
      local frank; frank="$(route_class_rank "$policy" "$from")"
      if [ "$frank" = "$ROUTE_HUMAN_RANK" ]; then
        red "STOP — run '$run' is at the human decision boundary"
        echo "  a decision that belongs to a person is not escalated by spending more on a model"
        return 5
      fi
      local to rule
      to="$(route_rows "$policy" escalate | awk -F'\t' -v f="$from" '$2 == f { print $3; exit }')"
      rule="$(route_rows "$policy" escalate | awk -F'\t' -v f="$from" '$2 == f { print $4; exit }')"
      if [ -z "$to" ]; then
        red "no escalation declared from '$from' — it is already the strongest routed class"
        echo "  a run that cannot converge at the top class is a human decision, not a bigger model"
        return 2
      fi
      local trank; trank="$(route_class_rank "$policy" "$to")"
      if [ "$trank" = "$ROUTE_HUMAN_RANK" ]; then
        red "STOP — escalation from '$from' reaches the human decision boundary"
        echo "  the run stops here for a person; it does not attempt the decision autonomously"
        return 5
      fi
      local model effort
      model="$(route_model "$policy" "$to")"
      effort="$(route_effort "$policy" "$to")"
      {
        printf 'class\t%s\n' "$to"
        printf 'task\t%s\n' "$(rt_get "$rfile" task)"
        printf 'escalated_from\t%s\n' "$from"
        printf 'escalation_reason\t%s\n' "$reason"
      } > "$rfile"
      "$SPARK_ROOT/bin/spark" telemetry record --run "$run" \
        model="$model" effort="$effort" routing_reason="escalated from $from: $reason" >/dev/null 2>&1 || true
      if [ -n "$json" ]; then
        printf '{"run":"%s","from":"%s","to":"%s","model":"%s","effort":"%s","reason":"%s"}\n' \
          "$run" "$from" "$to" "$model" "$effort" "$reason"
      else
        yellow "ESCALATED — $from -> $to"
        printf '  %-10s %s\n' rule "$rule"
        printf '  %-10s %s\n' reason "$reason"
        printf '  %-10s %s (%s)\n' now "$model" "$effort"
      fi
      ;;

    attempt)
      if [ -z "$run" ]; then red "spark route attempt needs --run <id>"; return 1; fi
      case "$outcome" in
        pass|fail) ;;
        *) red "spark route attempt needs --outcome pass|fail"; return 1 ;;
      esac
      [ -n "$top" ] || { red "spark route attempt needs a git repo"; return 1; }
      local rfile class efrom cost wall
      rfile="$(rt_run "$top" "$run")"
      class="$(rt_get "$rfile" class)"
      [ -n "$class" ] || { red "run '$run' has no selected route"; return 1; }
      efrom="$(rt_get "$rfile" escalated_from)"
      # Cost and latency come from the run's telemetry — the routing ledger
      # never re-measures what the run already recorded.
      cost="$(tm_get "$(tm_file "$top" "$run")" cost_usd)"
      wall="$(tm_get "$(tm_file "$top" "$run")" wall_seconds)"
      mkdir -p "$(rt_dir "$top")" || { red "could not create $(rt_dir "$top")"; return 1; }
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$class" "$outcome" "${cost:-}" "${wall:-}" "${efrom:-}" >> "$(rt_ledger "$top")"
      green "attempt recorded: $run $class $outcome (cost ${cost:-NOT ASSESSED}, wall ${wall:-NOT ASSESSED}s)"
      ;;

    benchmark)
      [ -n "$top" ] || { red "spark route benchmark needs a git repo"; return 1; }
      local ledger; ledger="$(rt_ledger "$top")"
      if [ ! -f "$ledger" ]; then
        yellow "no routing attempts recorded — nothing to compare"
        return 0
      fi
      # Cost per COMPLETED task, not price per token: a cheap class that fails
      # half its attempts is not cheap, and the failures are what make the
      # difference visible.
      local report
      report="$(awk -F'\t' '
        {
          cls = $2; out = $3; cost = $4; wall = $5; from = $6
          att[cls]++
          if (cost != "") { csum[cls] += cost; chave[cls] = 1 }
          if (wall != "") { wsum[cls] += wall }
          if (out == "pass") ok[cls]++
          if (from != "") {
            path = from "->" cls
            patt[path]++
            if (cost != "") { pcost[path] += cost }
            if (out == "pass") pok[path]++
            wasted[path] = from
          }
          if (out == "fail" && cost != "") failcost[cls] += cost
          order[cls] = 1
        }
        END {
          for (c in order) {
            printf "class\t%s\t%d\t%d\t%s\t%s\n", c, att[c], ok[c],
              (chave[c] ? sprintf("%.4f", csum[c]) : ""), (ok[c] > 0 && chave[c] ? sprintf("%.4f", csum[c] / ok[c]) : "")
          }
          for (p in patt) {
            split(p, parts, "->")
            f = parts[1]
            total = pcost[p] + failcost[f]
            printf "path\t%s\t%d\t%d\t%.4f\t%s\n", p, patt[p], pok[p], total,
              (pok[p] > 0 ? sprintf("%.4f", total / pok[p]) : "")
          }
        }
      ' "$ledger" | LC_ALL=C sort)"

      if [ -n "$json" ]; then
        local first=1 kind name a s tot per
        printf '{"rows":['
        while IFS=$'\t' read -r kind name a s tot per; do
          [ -n "$kind" ] || continue
          [ "$first" -eq 1 ] && first=0 || printf ','
          printf '{"kind":"%s","name":"%s","attempts":%s,"successes":%s,"cost":%s,"cost_per_completed":%s}' \
            "$kind" "$name" "$a" "$s" "${tot:-null}" "${per:-null}"
        done <<EOF
$report
EOF
        printf ']}\n'
        return 0
      fi

      echo "Spark routing benchmark — cost per COMPLETED task"
      printf '  %-32s %9s %10s %10s %18s\n' route attempts successes cost 'cost/completed'
      local kind name a s tot per
      while IFS=$'\t' read -r kind name a s tot per; do
        [ -n "$kind" ] || continue
        printf '  %-32s %9s %10s %10s %18s\n' \
          "$([ "$kind" = path ] && printf '%s (two-stage)' "$name" || printf '%s' "$name")" \
          "$a" "$s" "${tot:-NOT ASSESSED}" "${per:-NOT ASSESSED}"
      done <<EOF
$report
EOF
      echo
      echo "A two-stage route carries the cost of the cheap attempt that failed."
      echo "Without that, starting cheap always looks cheaper than it was."
      ;;
    *)
      red "unknown route action: $action"; echo "$usage_line"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# spark ci — hand off at the CI boundary instead of polling (#636)
#
# When local certification is finished and a PR is pushed, the only thing still
# changing is GitHub. An agent that sits in `gh pr checks` burns wall time and
# remote calls to re-learn the same answer, and stays occupied while having no
# productive work left.
#
#   local work complete -> record the boundary -> STOP -> resume on a transition
#
# The boundary is recorded so stopping is safe: the PR, the exact HEAD, the
# required checks and their state at handoff. Resuming then needs no replay of
# the episode, because the question "what changed?" is answered against that
# snapshot rather than against memory.
#
# A pending check is NOT a failure. It is an unfinished external fact, and a
# run that reports FAIL because CI has not answered yet would send someone to
# debug their own correct work.
#
# And an unchanged read is recorded as exactly that. Polling is not forbidden --
# it is COUNTED, so the waste is visible in the same telemetry that already
# knows how many remote calls this run has made.
CI_FIELDS="pr head required state digest polls unchanged certified_at observed_at observed_head"

ci_dir()  { printf '%s/.spark/ci' "$1"; }
ci_file() { printf '%s/.spark/ci/%s.tsv' "$1" "$2"; }

ci_get() {
  [ -f "$1" ] || return 0
  awk -F'\t' -v k="$2" '$1 == k { v = $2 } END { if (v != "") print v }' "$1"
}

ci_load() {
  local f="$1" k v
  for k in $CI_FIELDS; do eval "civ_$k=''"; done
  [ -f "$f" ] || return 0
  while IFS=$'\t' read -r k v; do
    case " $CI_FIELDS " in *" $k "*) eval "civ_$k=\$v" ;; esac
  done < "$f"
  return 0
}

ci_write() {
  local f="$1" k v
  mkdir -p "$(dirname "$f")" || return 1
  {
    for k in $CI_FIELDS; do
      eval "v=\$civ_$k"
      if [ -n "$v" ]; then printf '%s\t%s\n' "$k" "$v"; fi
    done
  } > "$f"
}

# ci_live <pr> — ONE coherent read of the PR's current head AND the check rollup
# that describes it. Sets CI_LIVE_HEAD to the head SHA the rollup covers (empty if
# unreadable) and prints the rollup as "<name>\t<state>" lines, or the literal
# __unreadable__ / __nochecks__. The head and the rollup come from a single
# observation so the caller can never pair one PR's checks with another head's
# recorded certification (#658). Never guessed: a rollup that cannot be read is an
# unknown, and an unknown that renders as "passing" would authorize a merge.
# Sets the globals CI_LIVE_HEAD (the head SHA the rollup covers, empty if the head
# is unreadable) and CI_LIVE_LINES (the sorted "<name>\t<state>" rollup, or the
# literal __unreadable__ / __nochecks__). It sets globals rather than printing so
# the head reaches the caller — a value returned on stdout and captured in a
# command substitution would be trapped in a subshell.
ci_live() {
  CI_LIVE_HEAD=""; CI_LIVE_LINES=""
  command -v gh >/dev/null 2>&1 || { CI_LIVE_LINES="__unreadable__"; return 0; }
  # One request returns both the head and the rollup. The head is emitted first,
  # tagged with a sentinel field name AND pinned to row one by construction (the
  # jq query emits it before the rollup array). Both must hold for the row to be
  # read as the head: position alone would misread a headless response's first
  # check row as the head, and name alone would let a real check legitimately
  # named the same as the sentinel be mistaken for it (or stripped below). A
  # rollup holds two disjoint shapes: a CheckRun reports .status while running
  # and .conclusion once finished; a StatusContext reports only .state.
  # conclusion-then-status-then-state covers both — a finished run's verdict
  # wins, a running one says it is running.
  local raw
  raw="$(gh pr view "$1" --json headRefOid,statusCheckRollup \
        --jq '"__civ_head__\t" + (.headRefOid // ""), (.statusCheckRollup[] | [(.name // .context), (.conclusion // .status // .state)] | @tsv)' 2>/dev/null)" \
    || { CI_LIVE_LINES="__unreadable__"; return 0; }
  CI_LIVE_HEAD="$(printf '%s\n' "$raw" | awk -F'\t' 'NR==1 && $1=="__civ_head__"{print $2; exit}')"
  # A coherent observation MUST carry the head the rollup describes. A missing or
  # empty headRefOid — even alongside readable check rows — is not a usable
  # observation: without the head, the rollup cannot be bound to the certified
  # commit, so it is unreadable, never evidence (#658).
  [ -n "$CI_LIVE_HEAD" ] || { CI_LIVE_LINES="__unreadable__"; return 0; }
  local out
  # The head sentinel is always row 1 by construction (the jq query emits it
  # before the rollup array) — dropped by POSITION, never by matching the name
  # column, because GitHub check names are user-controlled and a real check
  # legitimately named "__civ_head__" must not be filtered out of the rollup.
  out="$(printf '%s\n' "$raw" | awk -F'\t' 'NR>1 && NF{print}')"
  # No checks at all is a different fact from being unable to ask, and a caller
  # that cannot tell them apart will treat one as the other.
  [ -n "$out" ] || { CI_LIVE_LINES="__nochecks__"; return 0; }
  CI_LIVE_LINES="$(printf '%s' "$out" | LC_ALL=C sort)"
}

# ci_sentinel_state <lines> — the state name when a read produced no check rows
# at all, or empty when these are real rows. Both sentinels refuse to become a
# pass; they differ only in what they tell the operator to do about it.
ci_sentinel_state() {
  case "$1" in
    __unreadable__) printf 'unreadable' ;;
    __nochecks__)   printf 'no-checks' ;;
  esac
}

# ci_sentinel_report <state> — the human explanation for a sentinel state.
ci_sentinel_report() {
  if [ "$1" = "no-checks" ]; then
    yellow "NOT ASSESSED — this PR has no checks registered"
    echo "  nothing has reported, which is not the same as everything having passed"
  else
    yellow "NOT ASSESSED — the check rollup could not be read"
    echo "  an unreadable rollup is an unknown, never a pass"
  fi
}

# ci_verdict <lines> — the state of the whole rollup: pending until every
# required check has answered, then passing or failing.
ci_verdict() {
  printf '%s\n' "$1" | awk -F'\t' '
    NF == 0 { next }
    {
      s = toupper($2)
      if (s == "SUCCESS" || s == "NEUTRAL" || s == "SKIPPED") { pass++ }
      else if (s == "PENDING" || s == "QUEUED" || s == "IN_PROGRESS" || s == "EXPECTED" || s == "") { pend++ }
      else { fail++ }
      n++
    }
    END {
      if (n == 0) { print "unreadable"; exit }
      if (fail > 0) { print "failing"; exit }
      if (pend > 0) { print "pending"; exit }
      print "passing"
    }'
}

ci_failing_set() {
  printf '%s\n' "$1" | awk -F'\t' '
    NF == 0 { next }
    {
      s = toupper($2)
      if (s != "SUCCESS" && s != "NEUTRAL" && s != "SKIPPED" && s != "PENDING" &&
          s != "QUEUED" && s != "IN_PROGRESS" && s != "EXPECTED" && s != "") print "  " $1 " — " $2
    }'
}

# ci_observe <run> <file> — one live read, counted. BOTH status and resume go
# through here, because `resume` is the default action and the one the runbook
# shows: an anti-polling guarantee that only holds for the verb nobody reaches
# for is not a guarantee, it is a decoration. Sets CI_OBS_LINES, CI_OBS_VERDICT,
# CI_OBS_SENT and CI_OBS_CHANGED.
ci_observe() {
  local run="$1" file="$2" newdigest
  ci_live "$civ_pr"
  CI_OBS_LINES="$CI_LIVE_LINES"
  CI_OBS_HEAD="$CI_LIVE_HEAD"                 # the head the rollup actually described
  CI_OBS_SENT=""                             # defined on every path (stale returns early)
  civ_polls="$(( ${civ_polls:-0} + 1 ))"
  civ_observed_at="$(date -u +%FT%TZ)"
  civ_observed_head="$CI_OBS_HEAD"           # record which head this observation covered
  # A readable head that has moved off the certified commit is STALE — decided
  # BEFORE any sentinel classification, so a moved PR whose new head has no checks
  # yet is reported stale, not "no checks" (#658). Those checks are not evidence
  # for civ_head; a green replacement head must never report the old head READY.
  # An UNREADABLE head (CI_OBS_HEAD empty) cannot be compared and falls through to
  # the sentinel path below.
  if [ -n "$CI_OBS_HEAD" ] && [ "$CI_OBS_HEAD" != "$civ_head" ]; then
    CI_OBS_VERDICT="stale"; CI_OBS_CHANGED=1
    civ_state="stale"
    ci_write "$file"
    return 0
  fi
  CI_OBS_SENT="$(ci_sentinel_state "$CI_OBS_LINES")"
  if [ -n "$CI_OBS_SENT" ]; then
    CI_OBS_VERDICT="$CI_OBS_SENT"; CI_OBS_CHANGED=1
    civ_state="$CI_OBS_SENT"
    ci_write "$file"
    return 0
  fi
  CI_OBS_VERDICT="$(ci_verdict "$CI_OBS_LINES")"
  newdigest="$(printf '%s' "$CI_OBS_LINES" | cksum | awk '{ print $1 }')"
  if [ "$newdigest" = "$civ_digest" ]; then
    CI_OBS_CHANGED=0
    civ_unchanged="$(( ${civ_unchanged:-0} + 1 ))"
  else
    CI_OBS_CHANGED=1
    civ_digest="$newdigest"
  fi
  civ_state="$CI_OBS_VERDICT"
  ci_write "$file"
  # Every read is a remote request, whichever verb asked for it.
  "$SPARK_ROOT/bin/spark" telemetry record --run "$run" \
    api_requests="$civ_polls" ci_state="$CI_OBS_VERDICT" >/dev/null 2>&1 || true
  return 0
}

cmd_ci() {
  local usage_line="usage: spark ci [handoff|status|resume] --run <id> [--pr <n>] [--head <sha>] [--json]"
  local action=""
  case "${1:-}" in
    handoff|status|resume) action="$1"; shift ;;
    *) action="resume" ;;
  esac

  local run="" pr="" head="" json=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --run)   shift; run="${1:-}" ;;
      --run=*) run="${1#--run=}" ;;
      --pr)    shift; pr="${1:-}" ;;
      --pr=*)  pr="${1#--pr=}" ;;
      --head)  shift; head="${1:-}" ;;
      --head=*) head="${1#--head=}" ;;
      --json)  json=1 ;;
      -h|--help) echo "$usage_line"; return 0 ;;
      *) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
    esac
    # A flag whose value was the last token has already consumed everything.
    # A bare `shift` at $# = 0 returns 1, and under `set -e` that aborts the
    # process silently — the worst possible answer to a typo, because the user
    # sees no output at all and cannot tell a bad flag from a crash.
    if [ "$#" -gt 0 ]; then shift; fi
  done

  local top
  top="$(git_root)"; if [ -z "$top" ]; then
    red "spark ci needs a git repo — run it from inside the project."
    return 1
  fi
  [ -n "$run" ] || run="${SPARK_RUN_ID:-current}"
  if ! tm_valid_run "$run"; then
    red "invalid run id: '$run'"; return 1
  fi

  local file; file="$(ci_file "$top" "$run")"
  ci_load "$file"

  case "$action" in
    handoff)
      case "$pr" in ''|*[!0-9]*) red "spark ci handoff needs --pr <number>"; return 1 ;; esac
      if [ -z "$head" ]; then
        red "spark ci handoff needs --head <sha> — the exact commit the local certification covered"
        yellow "  without it, a later resume cannot tell whether CI answered about this work or newer work."
        return 1
      fi
      local lines verdict sent
      ci_live "$pr"; lines="$CI_LIVE_LINES"
      # The certification must cover the PR's CURRENT head, so the live head must be
      # readable to verify --head against it. An unreadable head is not "assume it
      # matches" — without it a later resume cannot tell this commit's CI from work
      # pushed since, so refuse to record an unverifiable certification (#658).
      if [ -z "$CI_LIVE_HEAD" ]; then
        red "spark ci handoff: could not read the PR's current head — refusing to record an unverifiable certification"
        yellow "  retry once GitHub answers; a certification that cannot be bound to a commit is not one."
        return 1
      fi
      # If a readable live head differs from the supplied --head, recording it would
      # let CI for newer work masquerade as this commit's evidence. Refuse, and name
      # both SHAs.
      if [ "$CI_LIVE_HEAD" != "$head" ]; then
        red "spark ci handoff: --head $head is not the PR's current head ($CI_LIVE_HEAD)"
        yellow "  certify the commit the PR actually points at, or re-run local certification on it."
        return 1
      fi
      sent="$(ci_sentinel_state "$lines")"
      if [ -n "$sent" ]; then
        civ_state="$sent"; civ_required=""; civ_digest=""
      else
        civ_state="$(ci_verdict "$lines")"
        civ_required="$(printf '%s\n' "$lines" | awk -F'\t' 'NF { printf "%s%s", (n++ ? "," : ""), $1 }')"
        civ_digest="$(printf '%s' "$lines" | cksum | awk '{ print $1 }')"
      fi
      civ_pr="$pr"; civ_head="$head"; civ_observed_head="$CI_LIVE_HEAD"
      civ_polls=0; civ_unchanged=0
      civ_certified_at="$(date -u +%FT%TZ)"
      civ_observed_at="$civ_certified_at"
      ci_write "$file" || { red "could not write $file"; return 1; }
      "$SPARK_ROOT/bin/spark" telemetry record --run "$run" \
        pr="$pr" head_sha="$head" certified_at="$civ_certified_at" ci_state="$civ_state" >/dev/null 2>&1 || true

      if [ -n "$json" ]; then
        printf '{"run":"%s","pr":%s,"head":"%s","state":"%s","checks":"%s"}\n' \
          "$run" "$pr" "$head" "$civ_state" "$civ_required"
      else
        green "handoff recorded — local certification is complete for $head"
        printf '  %-12s #%s\n' pr "$pr"
        printf '  %-12s %s\n' checks "${civ_required:-NOT ASSESSED}"
        printf '  %-12s %s\n' state "$civ_state"
        echo
        echo "Nothing local remains. Stop here and resume on a CI transition —"
        echo "re-reading an unchanged rollup buys the same answer at the same price."
      fi
      ;;

    status)
      [ -f "$file" ] || { red "no CI handoff recorded for run '$run'"; return 1; }
      ci_observe "$run" "$file"
      if [ -n "$CI_OBS_SENT" ]; then
        if [ -n "$json" ]; then
          printf '{"run":"%s","state":"%s","transition":null,"polls":%s,"unchanged":%s}\n' \
            "$run" "$CI_OBS_SENT" "${civ_polls:-0}" "${civ_unchanged:-0}"
        else
          ci_sentinel_report "$CI_OBS_SENT"
        fi
        return 1
      fi
      # A moved head is its own outcome here too — not a transition of the certified
      # head's checks. Machine callers see state=stale with a distinct exit (#658).
      if [ "$CI_OBS_VERDICT" = "stale" ]; then
        if [ -n "$json" ]; then
          printf '{"run":"%s","state":"stale","observed_head":"%s","transition":null,"polls":%s,"unchanged":%s}\n' \
            "$run" "${civ_observed_head:-}" "${civ_polls:-0}" "${civ_unchanged:-0}"
        else
          red "STALE — the PR head moved off the certified commit $civ_head (now ${civ_observed_head:-a different head})"
          echo "  re-certify the new head; these checks are not evidence for $civ_head"
        fi
        return 5
      fi
      if [ -n "$json" ]; then
        printf '{"run":"%s","state":"%s","observed_head":"%s","transition":%s,"polls":%s,"unchanged":%s}\n' \
          "$run" "$CI_OBS_VERDICT" "${civ_observed_head:-}" \
          "$([ "$CI_OBS_CHANGED" -eq 1 ] && printf true || printf false)" \
          "${civ_polls:-0}" "${civ_unchanged:-0}"
        if [ "$CI_OBS_CHANGED" -eq 1 ]; then return 0; fi
        return 3
      fi
      if [ "$CI_OBS_CHANGED" -eq 0 ]; then
        yellow "NO TRANSITION — this read produced no new information (${civ_unchanged} unchanged of ${civ_polls} reads)"
        echo "  state is still '$CI_OBS_VERDICT'; waiting is free, asking again is not"
        return 3
      fi
      green "TRANSITION — the rollup changed; state is now '$CI_OBS_VERDICT'"
      return 0
      ;;

    resume)
      [ -f "$file" ] || { red "no CI handoff recorded for run '$run'"; return 1; }
      local lines verdict
      ci_observe "$run" "$file"
      if [ -n "$CI_OBS_SENT" ]; then
        ci_sentinel_report "$CI_OBS_SENT"
        return 1
      fi
      lines="$CI_OBS_LINES"; verdict="$CI_OBS_VERDICT"

      if [ -n "$json" ]; then
        printf '{"run":"%s","pr":%s,"head":"%s","observed_head":"%s","state":"%s","polls":%s,"unchanged":%s}\n' \
          "$run" "$civ_pr" "$civ_head" "${civ_observed_head:-}" "$verdict" "${civ_polls:-0}" "${civ_unchanged:-0}"
      fi

      case "$verdict" in
        stale)
          # The PR moved off the certified commit. Its checks describe a different
          # head, so this is neither READY nor a failure of the certified work — it
          # is a re-certification signal with its own exit code (#658).
          [ -z "$json" ] && {
            red "STALE — the PR head moved off the certified commit $civ_head"
            echo "  the live rollup now describes ${civ_observed_head:-a different head}, which local certification did not cover"
            echo "  re-run local certification on the new head and hand off again; this is not a pass for $civ_head"
          }
          return 5 ;;
        pending)
          # Deliberately not a failure. A run that reported FAIL here would send
          # someone to debug work that is correct and simply unfinished elsewhere.
          [ -z "$json" ] && {
            yellow "PENDING — CI has not answered yet for $civ_head"
            echo "  this is not a failure and not a reason to poll; resume on the transition"
          }
          return 4 ;;
        failing)
          [ -z "$json" ] && {
            red "CHANGES REQUIRED — CI failed on $civ_head"
            echo "  the failing set, from GitHub rather than from replaying the episode:"
            ci_failing_set "$lines"
            echo "  repair these; do not re-run the whole local certification to find them"
          }
          return 2 ;;
        passing)
          [ -z "$json" ] && {
            green "READY — every required check passed on $civ_head"
            echo "  local certification already covered this commit; do not re-run it"
            if [ "${civ_unchanged:-0}" -gt 0 ]; then
              yellow "  note: ${civ_unchanged} of ${civ_polls} reads produced no new information"
            fi
          }
          return 0 ;;
        *)
          yellow "NOT ASSESSED — the rollup state could not be classified"
          return 1 ;;
      esac
      ;;
    *)
      red "unknown ci action: $action"; echo "$usage_line"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Crossroad classification (#690)
#
# The autonomous orchestrator's most expensive stop mistake is not running past a
# real human boundary — it is INVENTING one. A genuine Crossroad exists only when
# the next motion needs an authority a durable surface reserves to the human.
# Activating an implementation the owning issue already authorized is not a new
# grant; substituting one form of evidence for another (an independent exact-HEAD
# review standing in for a bootstrap that cannot self-review) is a verification
# question, not a governance decision; and social caution — co-authorship,
# perceived presumptuousness, "this feels consequential" — is never authority.
#
# So a stop is admitted ONLY for a recognised boundary kind that also NAMES the
# missing authority and CITES the durable surface reserving it. Everything else
# continues. This fails toward CONTINUE on purpose: the defect (#688) was a false
# stop, so an unnamed or unrecognised reason must never manufacture one. It does
# not touch UNKNOWN/NOT ASSESSED, stale-head protection, review, or CI — those
# stop work on their own evidence; this governs only the human-handoff decision.

# Kinds that ARE human-owned boundaries — a real stop, but only when the missing
# authority is named and its reserving surface cited.
XR_BOUNDARY_KINDS="new-authority product-governance-semantics release-policy destructive-external decision-required"
# Kinds that are NOT authority boundaries — activating already-authorized work,
# verification/evidence mechanics, or social/psychological caution. These continue.
XR_NON_BOUNDARY_KINDS="activate-authorized evidence-substitution co-authorship operator-courtesy presumptuousness consequentiality general-caution"

# xr_stop_check <kind> [authority] [surface]
# Echoes the verdict on the first line — CONTINUE or DECISION REQUIRED — then the
# reason. Returns 0 for CONTINUE, 3 for a genuine DECISION REQUIRED Crossroad.
xr_stop_check() {
  local kind="${1:-}" authority="${2:-}" surface="${3:-}"
  case " $XR_NON_BOUNDARY_KINDS " in
    *" $kind "*)
      echo "CONTINUE"
      echo "reason: '$kind' is not an authority boundary — activating already-authorized work, evidence substitution, or social caution is never a human gate; continue the authorized close-out"
      return 0 ;;
  esac
  case " $XR_BOUNDARY_KINDS " in
    *" $kind "*)
      # Whitespace is not a name. A value must carry at least one non-whitespace
      # character to count as a named authority / cited surface, or " " could
      # pose as one and manufacture exactly the false stop this guards against.
      local a_named=0 s_named=0
      case "$authority" in *[![:space:]]*) a_named=1 ;; esac
      case "$surface"   in *[![:space:]]*) s_named=1 ;; esac
      if [ "$a_named" = 1 ] && [ "$s_named" = 1 ]; then
        # STRUCTURAL, not semantic. This confirms the stop carries a named
        # authority and a cited surface — turning an unfalsifiable "it felt
        # consequential" stop into a claim a human can check. It does NOT (and a
        # pure classifier cannot) verify that the cited surface actually reserves
        # the authority; that substance is the agent's honest judgment and the
        # human's to confirm. So the verdict reports the claim, it does not
        # assert it as verified fact.
        echo "DECISION REQUIRED"
        echo "claimed authority: $authority — cited as reserved to the human by $surface (kind: $kind); confirm the citation holds before stopping"
        return 3
      fi
      local lack
      if   [ "$a_named" = 0 ] && [ "$s_named" = 0 ]; then lack="a named authority and a cited surface"
      elif [ "$a_named" = 0 ];                       then lack="a named authority"
      else                                                lack="a cited surface"
      fi
      echo "CONTINUE"
      echo "reason: a '$kind' stop needs $lack, which was not given — name the specific missing human authority and cite the durable surface reserving it, or continue rather than manufacture a Crossroad"
      return 0 ;;
  esac
  echo "CONTINUE"
  echo "reason: unrecognised stop kind '$kind' — name the exact reserved authority and its durable surface, or continue"
  return 0
}

# cmd_crossroad <kind> [authority] [surface] — expose xr_stop_check on the CLI so
# an agent can check itself before a human handoff. Exits 0 to continue, 3 at a
# genuine Crossroad.
cmd_crossroad() {
  if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "usage: spark crossroad <kind> [authority] [surface]"
    echo "  boundary kinds (stop only when authority AND surface are named):"
    echo "    $XR_BOUNDARY_KINDS"
    echo "  non-boundary kinds (always continue):"
    echo "    $XR_NON_BOUNDARY_KINDS"
    return 0
  fi
  local rc=0
  xr_stop_check "$@" || rc=$?
  return "$rc"
}
