# PageLumen release checklist

Use this checklist for every candidate release. Attach command output and
artifact identifiers to the release record; a local build is not evidence of
App Store review or live availability.

## Automated gates

- [ ] `swift test` passes on the minimum supported macOS and current macOS.
- [x] `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Release -destination 'generic/platform=macOS' archive` succeeds (`dist/PageLumen.xcarchive`, evidence record dated 2026-08-20).
- [x] Exported artifact is validated with `codesign --verify --deep --strict` (Developer ID, universal arm64/x86_64 archive).
- [x] `git diff --check` and dependency/license review pass for this phase.
- [x] Deterministic fixture-corpus, malformed-input, and embedded-text performance tests pass; the current regression evidence is recorded in `docs/performance-baseline-2026-08-20.md` and the full package run in `docs/release-evidence-2026-08-20.md`.
- [ ] Scanned-image OCR latency and peak resident-memory smoke tests pass on a physical supported Mac; the embedded-text guards above do not prove this device-dependent gate.
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
- [x] Signing identity, entitlements, archive path, checksums, and version/build recorded in `docs/release-evidence-2026-08-20.md`.
- [x] Upload, processing, review, and live-store states are recorded separately in `docs/release-evidence-2026-08-20.md`; each unperformed state is explicitly reported as such.
- [ ] Rollback version and user communication are prepared.
