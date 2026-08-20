# Release evidence — 2026-08-20

This record separates local artifact evidence from Apple-hosted distribution
state. It was refreshed after a successful signed universal archive and local
ZIP/DMG packaging run from the current source on 2026-08-20.

The artifact values below were refreshed at 20:45 IST after the latest UI
source commit; they supersede the earlier archive checksums in this record.

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
- Current-source unsigned Release configuration build: `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Release -sdk macosx CODE_SIGNING_ALLOWED=NO build` passed on 2026-08-20. This confirms the checked-out source compiles in Release; it does not replace the signed archive evidence above.
- Full package regression: `swift test -Xswiftc -gnone` passed 332 tests with 2 documented translation-model skips; focused export, model-comparison, and UI build gates were also rerun after this record's original archive.
- Strict diagnostics regression: a fresh `swift test -Xswiftc -gnone -Xswiftc -warnings-as-errors` run completed at 20:48 IST with 332 tests, 2 documented translation-model skips, and 0 failures.
- Latest UI source commit included: `55e603f` (readable Review Continue action)
- CodeDirectory CDHash: `3026ba12407788eacf85813c6ff99ad87e1f3dd9`
- Privacy manifest: `Contents/Resources/PrivacyInfo.xcprivacy`, valid, non-tracking, and declares the UserDefaults accessed-API reason
- Gatekeeper: rejected as `Unnotarized Developer ID` (expected before notarization)

## Distribution artifacts

- ZIP: `dist/PageLumen.zip`
  - SHA-256: `c9a56710e0708a9f5f021b01de81bd440b38cf998e61b9b06e263d705d107a61`
- DMG: `dist/PageLumen.dmg`
  - SHA-256: `b744d1f4d2cdc4ab5b584c1578ea31b79418e7ddfb58cedfb2b0f4e5615ccc62`

## Notarization and manual gates

Notarization was not submitted: no Apple notarytool credentials are configured
in this environment, and uploading a private application artifact requires
explicit authorization.

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
