#!/usr/bin/env bash
# Regression tests for the bounded-run selection logic in
# tests/e2e-marketplace-install.sh (#193). The e2e script itself needs
# network and credentials; these tests source only its helpers
# (SPARK_E2E_LIB_ONLY=1) and pin the timeout → gtimeout → bare-run
# selection offline, so the runner covers the macOS-portability contract.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
e2e="$here/e2e-marketplace-install.sh"

check() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "  ✖ $desc — want '$want', got '$got'"
  fi
}

# Sourcing with the lib-only hook must define the helpers and run nothing.
# The e2e preamble initializes its own pass/fail counters, so this suite's
# counters are set only after the source — order is load-bearing.
SPARK_E2E_LIB_ONLY=1 . "$e2e"
pass=0 fail=0
command -v bounded_runner >/dev/null && command -v run_bounded >/dev/null \
  && pass=$((pass + 1)) \
  || { fail=$((fail + 1)); echo "  ✖ helpers not defined after lib-only source"; }

# Stub PATHs: one dir per scenario, each holding only the wrappers that
# scenario provides. The stubs log their argv then run the real command, so
# run_bounded's dispatch (including the seconds argument) is observable.
stubs="$(mktemp -d)"
trap 'rm -rf "$stubs"' EXIT
log="$stubs/log"

make_stub() { # <dir> <name>
  mkdir -p "$1"
  # /bin/sh by absolute path: the stubs run under deliberately-stripped PATHs
  # where `env` cannot find an interpreter.
  printf '#!/bin/sh\necho "%s $*" >> "%s"\nshift\nexec "$@"\n' "$2" "$log" > "$1/$2"
  chmod +x "$1/$2"
}
make_stub "$stubs/both" "timeout"
make_stub "$stubs/both" "gtimeout"
make_stub "$stubs/gnu-only" "timeout"
make_stub "$stubs/mac-brew" "gtimeout"
mkdir -p "$stubs/bare"

# command -v is a builtin, so a stub-only PATH is enough for bounded_runner;
# run_bounded gets /bin/echo by absolute path so the stubs' exec needs no
# PATH lookup.
check "selects timeout when both exist" "timeout" \
  "$(PATH="$stubs/both" bounded_runner)"
check "selects timeout when only timeout" "timeout" \
  "$(PATH="$stubs/gnu-only" bounded_runner)"
check "falls back to gtimeout (stock macOS + coreutils)" "gtimeout" \
  "$(PATH="$stubs/mac-brew" bounded_runner)"
check "reports none when neither exists (stock macOS)" "none" \
  "$(PATH="$stubs/bare" bounded_runner)"

: > "$log"
out="$(PATH="$stubs/gnu-only" run_bounded 240 /bin/echo bounded-ok)"
check "run_bounded output passes through (timeout)" "bounded-ok" "$out"
check "timeout stub received the seconds" "timeout 240 /bin/echo bounded-ok" "$(cat "$log")"

: > "$log"
out="$(PATH="$stubs/mac-brew" run_bounded 240 /bin/echo bounded-ok)"
check "run_bounded output passes through (gtimeout)" "bounded-ok" "$out"
check "gtimeout stub received the seconds" "gtimeout 240 /bin/echo bounded-ok" "$(cat "$log")"

: > "$log"
out="$(PATH="$stubs/bare" run_bounded 240 /bin/echo bounded-ok)"
check "bare run still executes the command" "bounded-ok" "$out"
check "bare run bypasses both wrappers" "" "$(cat "$log")"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
