#!/usr/bin/env bash
set -euo pipefail

ARTIFACT="${1:-dist/PageLumen.dmg}"

if [[ ! -f "$ARTIFACT" ]]; then
  echo "Artifact not found: $ARTIFACT" >&2
  exit 1
fi

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
  cat <<'MESSAGE'
Missing notarization environment variables.

Set these from your Apple Developer account before running:

  export APPLE_ID="you@example.com"
  export APPLE_TEAM_ID="TEAMID"
  export APPLE_APP_PASSWORD="app-specific-password"

Then run:

  script/notarize_release.sh dist/PageLumen.dmg
MESSAGE
  exit 1
fi

xcrun notarytool submit "$ARTIFACT" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait

xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"
spctl -a -vv -t open --context context:primary-signature "$ARTIFACT"
