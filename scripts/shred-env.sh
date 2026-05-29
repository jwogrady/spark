#!/usr/bin/env bash
# shred-env — securely delete a transient secrets file after its keys have been
# loaded into 1Password. Overwrites the bytes (not just unlinks) and verifies
# the file is gone. Never prints the file's contents.
#
# Usage: shred-env <file>   (e.g. shred-env .env)
#
# Refuses to touch reference templates (*.tmpl) — those hold only op:// refs and
# are meant to be committed.

set -euo pipefail

file="${1:-}"
[ -n "$file" ] || { echo "usage: shred-env <file>" >&2; exit 2; }

case "$file" in
  *.tmpl|*.tmpl.example)
    echo "✖ refusing to shred '$file' — templates hold only references and should be kept." >&2
    exit 2
    ;;
esac

if [ ! -e "$file" ]; then
  echo "nothing to do — '$file' does not exist." >&2
  exit 0
fi
if [ ! -f "$file" ]; then
  echo "✖ '$file' is not a regular file." >&2
  exit 2
fi

# Secure-delete: prefer shred / gshred; fall back to overwrite-then-remove.
if command -v shred >/dev/null 2>&1; then
  shred -u -z "$file"
elif command -v gshred >/dev/null 2>&1; then
  gshred -u -z "$file"
else
  # Portable fallback: overwrite with random bytes the size of the file, then
  # truncate and remove.
  size="$(wc -c < "$file" | tr -d '[:space:]')"
  if [ "${size:-0}" -gt 0 ]; then
    dd if=/dev/urandom of="$file" bs=1 count="$size" conv=notrunc >/dev/null 2>&1 || true
  fi
  : > "$file"
  rm -f "$file"
fi

# Verify absence.
if [ -e "$file" ]; then
  echo "✖ failed to remove '$file'." >&2
  exit 1
fi
echo "✓ shredded '$file' — verify the keys are readable from 1Password before relying on this."
