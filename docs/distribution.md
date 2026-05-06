# PageLumen Distribution

PageLumen is ready for local Xcode testing after the normal Debug build. Shipping it to other Macs requires a signed Release archive and notarization.

## Requirements

- Apple Developer Program membership.
- A `Developer ID Application` certificate installed in Keychain Access.
- An app-specific password for notarization.

Check local signing identities:

```sh
security find-identity -v -p codesigning
```

## Build a Release Package

```sh
script/package_release.sh
```

If the Developer ID certificate is installed, the script creates:

- `dist/PageLumen.xcarchive`
- `dist/PageLumen.zip`
- `dist/PageLumen.dmg`

For local package testing without a Developer ID certificate:

```sh
ALLOW_ADHOC=1 script/package_release.sh
```

Ad hoc output is not trusted distribution output.

## Notarize

```sh
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="TEAMID"
export APPLE_APP_PASSWORD="app-specific-password"
script/notarize_release.sh dist/PageLumen.dmg
```

The script submits the DMG, waits for notarization, staples the ticket, and runs a Gatekeeper check.

## Validate an App Bundle

```sh
script/validate_release.sh
```

The validator prints bundle metadata, signing details, entitlements, strict code-sign verification, and Gatekeeper status.
