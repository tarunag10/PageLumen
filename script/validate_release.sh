#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-dist/PageLumen.xcarchive/Products/Applications/PageLumen.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

echo "== Bundle =="
plutil -p "$APP_PATH/Contents/Info.plist" | sed -n '1,80p'

echo
echo "== Signature =="
codesign -dvvv --entitlements :- "$APP_PATH"

echo
echo "== Verification =="
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo
echo "== Gatekeeper =="
spctl -a -vv "$APP_PATH" || true
