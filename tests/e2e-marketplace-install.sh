#!/usr/bin/env bash
# End-to-end validation of the published marketplace install path (#177).
#
# Deliberately NOT a tests/test-*.sh suite: it needs network access, the
# claude CLI, and (for the skill-invocation step) working credentials — so
# the runner never picks it up. Run it by hand as a release-readiness check:
#
#   bash tests/e2e-marketplace-install.sh
#
# What it proves, from a factory-fresh HOME:
#   1. `claude plugin marketplace add jwogrady/spark` — the published path
#   2. `claude plugin install spark@spark` — the core plugin
#   3. discovery: all 9 core skills and both hooks are inventoried
#   4. the spark CLI ships and works: version, doctor, doctor --requirements
#   5. companion install (spark-audit@spark) and marketplace update
#   6. one real core-skill invocation (/spark:ideate) — only when
#      credentials are available to copy in; skipped otherwise
#
# Recovery steps for each failure mode live in the get-started guide.

set -euo pipefail

MARKETPLACE="${SPARK_E2E_MARKETPLACE:-jwogrady/spark}"

pass=0 fail=0 skip=0
ok()   { pass=$((pass + 1)); printf '  ✓ %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  ✗ %s\n' "$1"; }
note() { skip=$((skip + 1)); printf '  - %s\n' "$1"; }

# Bounded execution for the live skill invocation. GNU `timeout` is not on
# stock macOS, so pick what the platform has: `timeout` → `gtimeout`
# (coreutils) → a bare run. The bare run is a documented soft bound, not a
# hang risk: `claude -p --max-turns` already limits the work.
bounded_runner() {
  if command -v timeout >/dev/null 2>&1; then echo "timeout"
  elif command -v gtimeout >/dev/null 2>&1; then echo "gtimeout"
  else echo "none"
  fi
}

run_bounded() {
  local secs="$1"; shift
  case "$(bounded_runner)" in
    timeout)  timeout "$secs" "$@" ;;
    gtimeout) gtimeout "$secs" "$@" ;;
    *)        "$@" ;;
  esac
}

# Offline test hook: tests/test-e2e-bounded-run.sh sources only the helpers
# above — nothing below runs (and nothing below may assume it did).
if [ "${SPARK_E2E_LIB_ONLY:-0}" = "1" ]; then return 0 2>/dev/null || exit 0; fi

command -v claude >/dev/null 2>&1 || { echo "claude CLI not found — install Claude Code first"; exit 1; }

# The invoking user's home, captured before the clean-HOME override — the
# default source for credentials in step 6.
ORIG_HOME="$HOME"

CLEAN="$(mktemp -d)"
trap 'rm -rf "$CLEAN"' EXIT
export HOME="$CLEAN"
echo "Clean environment: $CLEAN"
echo

echo "[1/6] marketplace add ($MARKETPLACE)"
if claude plugin marketplace add "$MARKETPLACE" >/dev/null 2>&1; then
  ok "marketplace added from the published path"
else
  bad "marketplace add failed — check network and GitHub access (SSH key or HTTPS)"
fi

echo "[2/6] core plugin install"
if claude plugin install spark@spark >/dev/null 2>&1; then
  ok "spark@spark installed"
else
  bad "plugin install failed"
fi
listing="$(claude plugin list 2>/dev/null || true)"
case "$listing" in
  *spark@spark*) ok "plugin listed as installed" ;;
  *) bad "installed plugin missing from claude plugin list" ;;
esac

echo "[3/6] discovery"
details="$(claude plugin details spark@spark 2>/dev/null || true)"
skills_ok=1
for s in agents-md bootstrap codify ideate knowledge onboard plan ship validate; do
  case "$details" in *"$s"*) ;; *) skills_ok=0; bad "skill missing from inventory: $s" ;; esac
done
[ "$skills_ok" -eq 1 ] && ok "all 9 core skills inventoried"
case "$details" in
  *PreToolUse*SessionStart*|*SessionStart*PreToolUse*) ok "both hooks inventoried" ;;
  *) bad "hooks missing from inventory" ;;
esac

echo "[4/6] the spark CLI from the installed copy"
SPARKBIN="$(find "$CLEAN/.claude/plugins" -path '*/bin/spark' -type f 2>/dev/null | head -n1)"
if [ -z "$SPARKBIN" ]; then
  bad "bin/spark not found in the installed plugin"
else
  ok "bin/spark ships at ${SPARKBIN#"$CLEAN"/}"
  "$SPARKBIN" version >/dev/null 2>&1 && ok "spark version runs" || bad "spark version failed"
  "$SPARKBIN" doctor >/dev/null 2>&1 && ok "spark doctor healthy" || bad "spark doctor unhealthy"
  "$SPARKBIN" doctor --requirements >/dev/null 2>&1 \
    && ok "doctor --requirements: environment ready" \
    || bad "doctor --requirements reported not ready"
fi

echo "[5/6] companion install and marketplace update"
claude plugin install spark-audit@spark >/dev/null 2>&1 \
  && ok "companion spark-audit@spark installs" \
  || bad "companion install failed"
claude plugin marketplace update spark >/dev/null 2>&1 \
  && ok "marketplace update succeeds" \
  || bad "marketplace update failed"

echo "[6/6] core skill invocation (needs credentials)"
CRED="${SPARK_E2E_CREDENTIALS:-$ORIG_HOME/.claude/.credentials.json}"
if [ -f "$CRED" ]; then
  cp "$CRED" "$CLEAN/.claude/.credentials.json"
  [ "$(bounded_runner)" = "none" ] && \
    note "no timeout/gtimeout on PATH — invocation bounded only by --max-turns (install coreutils for a hard bound)"
  proj="$(mktemp -d "$CLEAN/proj-XXXX")"
  reply="$( (cd "$proj" && git init -q && run_bounded 240 claude -p --max-turns 8 \
    "Invoke the /spark:ideate skill. As soon as the skill content loads, stop and reply with exactly: SKILL-LOADED <first heading of the skill file>. Do not do any other work." \
    < /dev/null) 2>/dev/null || true)"
  case "$reply" in
    *SKILL-LOADED*ideate*) ok "/spark:ideate loads from the marketplace install" ;;
    *) bad "skill invocation did not confirm (reply: ${reply:-<empty>})" ;;
  esac
else
  note "no credentials at $CRED — skill invocation skipped (run interactively to cover it)"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "✖ $fail failed, $pass passed, $skip skipped"
  exit 1
fi
echo "✓ $pass passed, $skip skipped — the published marketplace path is verified"
