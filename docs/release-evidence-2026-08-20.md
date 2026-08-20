# Release evidence — 2026-08-20

This record separates local artifact evidence from Apple-hosted distribution
state. It was refreshed after a successful signed universal archive and local
ZIP/DMG packaging run from the current source on 2026-08-20.

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
- Strict diagnostics regression: `swift test -Xswiftc -gnone -Xswiftc -warnings-as-errors` passed the same 332 tests with 2 documented translation-model skips and 0 failures on 2026-08-20.
- CodeDirectory CDHash: `6ab8c034116918cb02350c6b8522f54fb95087b6`
- Privacy manifest: `Contents/Resources/PrivacyInfo.xcprivacy`, valid, non-tracking, and declares the UserDefaults accessed-API reason
- Gatekeeper: rejected as `Unnotarized Developer ID` (expected before notarization)

## Distribution artifacts

- ZIP: `dist/PageLumen.zip`
  - SHA-256: `fadc9438adf8768feab37d083b7e5e8fe68b7fe3e26d0b54162957f60b9d7f4a`
- DMG: `dist/PageLumen.dmg`
  - SHA-256: `355223a1daafd07d402f0e71bb3ce1631f693c738a2e1b7aeac50930b7e894b5`

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
