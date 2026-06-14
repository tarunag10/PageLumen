# Changelog

All notable changes to PageLumen will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Sandbox + screen-capture entitlements for App Store distribution.
- `DocumentProcessor.supportedExtensions` to unify supported file types.
- `StatusBadge` helper that pairs color with an SF Symbol and a text label.
- `.accessibilityValue` on editable text blocks and labeled reading-order overlay.
- Debounced block edits to keep large documents responsive.
- Cached export previews.
- `CHANGELOG.md`, `Makefile`, `script/lint.sh`.
- `docs/architecture.md`, `docs/privacy.md`, `docs/accessibility.md`.

### Changed
- `script/build_and_run.sh` writes a complete `Info.plist` matching the Xcode-generated one.
- `Docs/superpowers/plans/*` files renamed/updated to use the PageLumen name.

### Fixed
- Cancellation in `processPDF` now short-circuits before any work.
- `DocumentStore` no longer recomputes `DocumentProcessor` on every access.

## [1.0.0] - 2026-06-14

### Added
- Initial public release: local PDF/image import, Vision OCR fallback, reading-order reconstruction, OCR profiles, review workflow, summaries, system speech playback, and Markdown/TXT/HTML/accessible-PDF/CSV/JSON exports.
