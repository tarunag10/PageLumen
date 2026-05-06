#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${ROOT_DIR}/DerivedData/Release"
DIST_DIR="${ROOT_DIR}/dist"
ARCHIVE_PATH="${DIST_DIR}/PageLumen.xcarchive"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/PageLumen.app"
DMG_PATH="${DIST_DIR}/PageLumen.dmg"
ZIP_PATH="${DIST_DIR}/PageLumen.zip"

cd "$ROOT_DIR"

mkdir -p "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$DMG_PATH" "$ZIP_PATH"

IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application/ {print $2; exit}')"
fi

if [[ -z "$IDENTITY" ]]; then
  cat <<'MESSAGE'
No Developer ID Application signing certificate was found.

Install a Developer ID Application certificate from your Apple Developer account,
or pass one explicitly:

  DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" script/package_release.sh

For a local-only unsigned package, run:

  ALLOW_ADHOC=1 script/package_release.sh
MESSAGE
  if [[ "${ALLOW_ADHOC:-0}" != "1" ]]; then
    exit 1
  fi
fi

COMMON_BUILD_ARGS=(
  -project PageLumen.xcodeproj
  -scheme PageLumen
  -configuration Release
  -destination "generic/platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  SKIP_INSTALL=NO
  ENABLE_HARDENED_RUNTIME=YES
)

if [[ -n "$IDENTITY" ]]; then
  COMMON_BUILD_ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$IDENTITY"
    OTHER_CODE_SIGN_FLAGS="--timestamp"
  )
else
  COMMON_BUILD_ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="-"
  )
fi

xcodebuild "${COMMON_BUILD_ARGS[@]}" archive -archivePath "$ARCHIVE_PATH"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Archive succeeded, but PageLumen.app was not found at $APP_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n '1,24p'

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
hdiutil create -volname "PageLumen" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"

cat <<MESSAGE

Release artifacts created:
  $APP_PATH
  $ZIP_PATH
  $DMG_PATH

Next notarization step:
  script/notarize_release.sh "$DMG_PATH"
MESSAGE
