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
echo "== Privacy manifest =="
PRIVACY_MANIFEST="$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
if [[ ! -f "$PRIVACY_MANIFEST" ]]; then
  echo "Privacy manifest missing: $PRIVACY_MANIFEST" >&2
  exit 1
fi
plutil -lint "$PRIVACY_MANIFEST"
if [[ "$(plutil -extract NSPrivacyTracking raw -o - "$PRIVACY_MANIFEST")" != "false" ]]; then
  echo "NSPrivacyTracking must be false" >&2
  exit 1
fi
plutil -extract NSPrivacyAccessedAPITypes xml1 -o - "$PRIVACY_MANIFEST" >/dev/null
echo "Privacy manifest is present, valid, non-tracking, and declares accessed APIs."

echo
echo "== Gatekeeper =="
spctl -a -vv "$APP_PATH" || true
