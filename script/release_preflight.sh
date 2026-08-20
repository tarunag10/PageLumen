#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

failures=0
check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "OK   $label"
  else
    echo "FAIL $label"
    failures=$((failures + 1))
  fi
}

check "Xcode project" test -f PageLumen.xcodeproj/project.pbxproj
check "resolved packages" test -f Package.resolved
check "release manifest" test -f docs/release-manifest-v1.json
check "privacy manifest" test -f Config/PrivacyInfo.xcprivacy
check "xcodebuild" command -v xcodebuild
check "codesign" command -v codesign
check "ditto" command -v ditto
check "hdiutil" command -v hdiutil

if security find-identity -v -p codesigning 2>/dev/null | rg -q 'Developer ID Application:'; then
  echo "OK   Developer ID Application identity"
else
  echo "WARN Developer ID Application identity unavailable (required for signed release)"
fi

for path in "${TMPDIR:-/tmp}" "DerivedData" "dist"; do
  if [[ -d "$path" && -w "$path" ]]; then
    echo "OK   writable path $path"
  else
    echo "WARN writable path unavailable: $path"
  fi
done

if (( failures > 0 )); then
  echo "Release preflight failed with $failures required prerequisite(s)." >&2
  exit 1
fi

echo "Release preflight passed required checks; signing and external Apple gates remain separate."
