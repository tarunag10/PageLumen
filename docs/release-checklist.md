# PageLumen release checklist

Use this checklist for every candidate release. Attach command output and
artifact identifiers to the release record; a local build is not evidence of
App Store review or live availability.

## Automated gates

- [ ] `swift test` passes on the minimum supported macOS and current macOS.
- [ ] `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Release -destination 'generic/platform=macOS' archive` succeeds.
- [ ] Exported artifact is validated with `codesign --verify --deep --strict`.
- [ ] `git diff --check` and dependency/license review pass.
- [ ] Fixture, malformed-input, and performance smoke tests pass.
- [x] CI validates package tests, an unsigned Xcode build, local quality gates,
      the bounded fixture manifests, and the release-evidence manifest. CI does
      not hold signing credentials or claim notarization/App Review/live-store
      evidence.

## Manual gates

- [ ] Import PDF and image, clipboard, selected screen/window capture.
- [ ] Review queue, block editing, search, App Intents, and unresolved findings.
- [ ] Every export format opens and includes the expected provenance/validation result.
- [ ] VoiceOver headings, keyboard-only navigation, light/dark appearance, large text,
      reduced motion, denied permissions, deletion/retention controls, and offline mode.
- [ ] Apple Intelligence is tested on an eligible Mac and a disabled/ineligible Mac;
      opt-in, citations, fallback, and model-download messaging are verified.

## Privacy and distribution record

- [ ] `docs/privacy.md` and App Store privacy answers match the build.
- [ ] Third-party notices and resolved versions are reviewed.
- [ ] Signing identity, entitlements, archive path, checksum, and version/build recorded.
- [ ] Upload, processing, review, and live-store states are recorded separately.
- [ ] Rollback version and user communication are prepared.
