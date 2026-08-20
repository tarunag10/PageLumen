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

## Archive diagnostics and evidence boundaries

## CI evidence boundary

GitHub Actions runs package tests, the bounded fixture-corpus contract, local
quality gates, release-manifest validation, and an unsigned Xcode build. The
workflow intentionally has no Apple signing or notarization secrets. The
versioned contract is [`docs/release-manifest-v1.json`](release-manifest-v1.json)
and is checked locally with:

```sh
script/validate_release_manifest.sh
script/validate_fixture_corpus.sh
```

Passing CI proves source-level and unsigned-build checks only; it does not
prove a signed archive, notarization, Gatekeeper acceptance, App Review, or
live-store availability.

When diagnosing an archive failure, use an isolated derived-data directory and
keep the signing mode explicit:

```sh
xcodebuild -project PageLumen.xcodeproj -scheme PageLumen \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath /private/tmp/PageLumenArchiveDerived \
  -archivePath /private/tmp/PageLumenAdHocArchive.xcarchive archive \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  SKIP_INSTALL=NO ENABLE_HARDENED_RUNTIME=NO
```

An ad-hoc archive can prove that compilation, packaging, privacy resources,
entitlements, and strict on-disk validation work. It cannot prove Developer ID
trust, notarization, Gatekeeper acceptance, or live distribution. A Developer
ID archive must be separately produced with the installed identity and then
validated with `script/validate_release.sh`; if Xcode stalls during a nested
SwiftPM bundle signing step, record that as a signing/keychain diagnostic and
do not relabel the ad-hoc artifact as a distribution build.
