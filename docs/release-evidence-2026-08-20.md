# Release evidence — 2026-08-20

This record separates local artifact evidence from Apple-hosted distribution
state.

## Local artifact

- Archive: `/private/tmp/PageLumenDevIDArchive.xcarchive`
- App: `/private/tmp/PageLumenDevIDArchive.xcarchive/Products/Applications/PageLumen.app`
- Signing identity: `Developer ID Application: Tarun Agarwal (UFUL3BBCP7)`
- Team ID: `UFUL3BBCP7`
- `xcodebuild ... archive`: succeeded
- `codesign --verify --deep --strict`: passed
- Privacy manifest: present, valid, non-tracking, and accessed-API declarations valid
- Gatekeeper: rejected as `Unnotarized Developer ID` (expected before notarization)

## Distribution artifacts

- ZIP: `/private/tmp/PageLumen-2026-08-20.zip`
  - SHA-256: `1cdbe6d1fc68fe1abd2f9428b10db6f862678f8d73fdf4b61dee296c5e1d7a7c`
- DMG: `/private/tmp/PageLumen-2026-08-20.dmg`
  - SHA-256: `10c4fddea82996937932b7ae26f130792730ee249cafe5d1d72251abdca7d031`

## Notarization and manual gates

Notarization was not submitted: `APPLE_ID`, `APPLE_TEAM_ID`, and
`APPLE_APP_PASSWORD` are absent, and uploading a private application artifact
requires explicit authorization. No notarization, stapling, App Store review,
or live-store claim is made.

VoiceOver, Switch Control, participant usability, large-text,
contrast/transparency, and reduced-motion sessions remain manual acceptance
work and require a human tester on the target Mac.
