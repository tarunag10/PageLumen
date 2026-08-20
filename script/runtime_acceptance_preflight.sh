#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_APP="$ROOT_DIR/dist/PageLumen.xcarchive/Products/Applications/PageLumen.app"
strict=0
if [[ "${1:-}" == "--strict" ]]; then
  strict=1
fi

failures=0
report() {
  local state="$1"; shift
  printf '%-5s %s\n' "$state" "$*"
  if [[ "$state" == "FAIL" ]]; then
    failures=$((failures + 1))
  fi
  return 0
}

if [[ -d "$ARCHIVE_APP" ]]; then
  report OK "signed archive exists: $ARCHIVE_APP"
  if codesign --verify --deep --strict "$ARCHIVE_APP" >/dev/null 2>&1; then
    report OK "archive passes deep code-signature verification"
  else
    report FAIL "archive failed deep code-signature verification"
  fi
else
  report FAIL "signed archive not found: $ARCHIVE_APP"
fi

if command -v sw_vers >/dev/null 2>&1; then
  report OK "macOS $(sw_vers -productVersion)"
else
  report FAIL "sw_vers is unavailable"
fi

process_check() {
  local process_name="$1"
  local label="$2"
  local output
  if output="$(pgrep -x "$process_name" 2>&1)" && [[ -n "$output" ]]; then
    report OK "$label is running"
  else
    report WARN "$label is unavailable to this shell; use a logged-in GUI session"
  fi
}

process_check WindowServer "WindowServer"
process_check sysmond "sysmond"

if [[ "$strict" -eq 1 && "$failures" -gt 0 ]]; then
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Runtime acceptance preflight completed. WARN entries require the physical GUI/participant gate."
