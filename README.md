# PageLumen

PageLumen is a native macOS app for turning PDFs, screenshots, scans, slides, and images into readable, reviewable, and exportable content.

The project focuses on accessibility-first document understanding: local OCR, reading-order reconstruction, confidence warnings, editable extracted text, table and figure explanations, speech playback, and accessible export formats.

## Features

- Import PDFs, images, screenshots, clipboard images, and batches of supported files.
- Extract embedded PDF text when available and fall back to local Vision OCR for visual pages.
- Reconstruct likely reading order for single-column, multi-column, form, slide, and mixed layouts.
- Use OCR profiles for General, Legal, Academic, Receipts, and Slides workflows.
- Review extracted text beside the source preview with reading-order overlays.
- Edit OCR text, block type, reading order, table explanations, and figure descriptions.
- Track review issues and mark blocks or pages as reviewed.
- Generate summaries and use built-in macOS speech playback.
- Export Markdown, TXT, HTML, tagged HTML, readable PDF, CSV, JSON, and accessibility reports.
- Use a high-contrast SwiftUI interface designed around native macOS accessibility conventions.

## Requirements

- macOS 14 or later
- Xcode 16 or later recommended
- Swift 6 toolchain with Swift language mode 5 for targets
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) if regenerating `PageLumen.xcodeproj` from `project.yml`

## Getting Started

Clone the repository:

```sh
git clone https://github.com/tarunag10/PageLumen.git
cd PageLumen
```

Build and test with SwiftPM:

```sh
swift test
```

Build the Xcode project:

```sh
xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Debug -destination 'platform=macOS' build
```

Run from Xcode by opening `PageLumen.xcodeproj` and selecting the `PageLumen` scheme.

You can also use the project helper:

```sh
./script/build_and_run.sh --verify
```

## Project Structure

```text
Sources/PageLumen/          SwiftUI macOS app
Sources/PageLumenCore/      Testable document processing, layout, export, and review logic
Tests/PageLumenCoreTests/   XCTest coverage for core behavior
docs/                       Distribution notes and implementation plans
script/                     Build, package, validation, and notarization helpers
project.yml                 XcodeGen project definition
```

## Privacy

PageLumen is designed around local-first processing. Baseline OCR uses Apple platform APIs and does not require uploading documents to a server.

Future contributors should keep privacy-sensitive behavior explicit and avoid adding network processing without clear user control, documentation, and tests.

## Accessibility

Accessibility is the product purpose, not an afterthought. UI contributions should preserve:

- Keyboard navigability
- VoiceOver-readable labels and hints
- Non-color-only status indicators
- High-contrast system colors
- Clear focus and review workflows
- Honest export claims, especially around PDF accessibility

The app currently aims to produce more accessible, reviewable outputs, but it does not claim universal PDF/UA compliance.

## Testing

Run all tests before opening a pull request:

```sh
swift test
```

Core test coverage includes document processing, layout analysis, OCR profiles, batch import queue logic, document editing, review verification, exports, accessibility audits, and summary generation.

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), and please open an issue before large changes so the scope can stay aligned with the accessibility-first roadmap.

## License

PageLumen is available under the MIT License. See [LICENSE](LICENSE).
