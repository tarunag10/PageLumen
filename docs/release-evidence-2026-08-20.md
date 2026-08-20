# Release evidence — 2026-08-20

This record separates local artifact evidence from Apple-hosted distribution
state. It was refreshed after correcting the Xcode project resource phase so
the app-level privacy manifest is included in the signed archive.

## Local artifact

- Archive: `dist/PageLumen.xcarchive`
- App: `dist/PageLumen.xcarchive/Products/Applications/PageLumen.app`
- Bundle: `com.pagelumen.PageLumen`, version `1.0` (build `1`)
- Architectures: universal `arm64` + `x86_64`
- Signing identity: `Developer ID Application: Tarun Agarwal (UFUL3BBCP7)`
- Team ID: `UFUL3BBCP7`
- Runtime: hardened runtime enabled; sandbox and user-selected file entitlements present
- `script/package_release.sh`: succeeded
- `script/validate_release.sh`: passed bundle, strict deep signature, privacy-manifest, and checksum gates
- CodeDirectory CDHash: `40dcbc871bdad318082782f66df2970bf53eec4a`
- Privacy manifest: `Contents/Resources/PrivacyInfo.xcprivacy`, valid, non-tracking, and declares the UserDefaults accessed-API reason
- Gatekeeper: rejected as `Unnotarized Developer ID` (expected before notarization)

## Distribution artifacts

- ZIP: `dist/PageLumen.zip`
  - SHA-256: `b103e54825d034154d506cea5fea0854b4a6dfb48e2f68a0b124345abb990796`
- DMG: `dist/PageLumen.dmg`
  - SHA-256: `c31263f1684ced4b126cf75b9ba950a68fd102f2c95b508cd4387661926fb0b1`

## Notarization and manual gates

Notarization was not submitted: `APPLE_ID`, `APPLE_TEAM_ID`, and
`APPLE_APP_PASSWORD` are absent, and uploading a private application artifact
requires explicit authorization.

The external release states are intentionally recorded separately:

| State | Evidence/status |
| --- | --- |
| Local archive, ZIP, DMG | Completed and validated above |
| Notarization/stapling | Not submitted; no notarization ticket exists |
| Upload/processing | Not performed; no Apple-hosted artifact exists |
| App Store/TestFlight review | Not submitted; no review state exists |
| Live store availability | Not released or claimed |

No notarization, stapling, App Store review, or live-store claim is made.

VoiceOver, Switch Control, participant usability, large-text,
contrast/transparency, reduced-motion, physical-Mac smoke, and App Review
validation remain manual acceptance work and require a human tester or
Apple-hosted release evidence on the target Mac.
