#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARCHIVE_APP="$ROOT_DIR/dist/PageLumen.xcarchive/Products/Applications/PageLumen.app"

echo "== swift test =="
swift test 2>&1 | tail -n 20

echo
echo "== swift build -c release =="
swift build -c release 2>&1 | tail -n 20

if [[ -d "$ARCHIVE_APP" ]]; then
  echo
  echo "== validate_release.sh =="
  ./script/validate_release.sh "$ARCHIVE_APP"
else
  echo
  echo "Skipping validate_release.sh: $ARCHIVE_APP not found."
fi
