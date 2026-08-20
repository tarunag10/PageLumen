#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
swift test -Xswiftc -gnone --enable-code-coverage >/tmp/pagelumen-coverage-tests.log

PROFDATA="$(find .build -path '*/codecov/default.profdata' -type f -print -quit)"
TEST_BINARY="$(find .build -path '*/PageLumenPackageTests.xctest/Contents/MacOS/PageLumenPackageTests' -type f -print -quit)"
if [[ -z "$PROFDATA" || -z "$TEST_BINARY" ]]; then
  echo "Coverage artifacts were not produced" >&2
  exit 1
fi

REPORT_PATH="docs/coverage-report-2026-08-20.txt"
xcrun llvm-cov report "$TEST_BINARY" -instr-profile "$PROFDATA" \
  Sources/PageLumenCore Sources/PageLumen Tests/PageLumenTests | tee "$REPORT_PATH"
rg -q '^TOTAL' "$REPORT_PATH"
echo "Coverage report written to $REPORT_PATH"
