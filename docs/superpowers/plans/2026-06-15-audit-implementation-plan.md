# PageLumen Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Replace `- [ ]` with `- [x] completed` (and add a short note) as each item is finished.

**Date:** 2026-06-15
**Status:** Open
**Source:** Full code & product audit of the PageLumen repository at this date. See `pagelumen_prd.md` and `README.md` for the underlying product goals.

**Goal:** Address the findings of the 2026-06-15 audit by fixing correctness bugs, closing accessibility gaps, adding sandbox/entitlements so the app can ship via the Mac App Store, improving performance on large documents, expanding test coverage, and making the public surface of the app match the PRD's P0/P1 commitments.

**Architecture:** Keep `PageLumenCore` as the testable, sendable-friendly engine and `PageLumen` as the SwiftUI + AppKit shell. Introduce thin protocols (`DocumentImporting`, `DocumentPersisting`) only where they unlock testing or sandboxing. Never add network or third-party SDKs.

**Tech Stack:** Swift 6 toolchain in Swift 5 language mode, SwiftUI, AppKit, PDFKit, Vision, AVFoundation, ScreenCaptureKit, XCTest, SwiftPM app-bundle run script, XcodeGen for pbxproj regeneration.

**Conventions for this plan:**
- Every file/line reference uses `path:line` so the agent can jump straight to the source.
- The audit recommendations are split into seven numbered phases. Items in each phase are listed in the order they should be tackled; later items in a phase may depend on earlier ones in the same phase.
- A task is "completed" when: the change is implemented, `swift test` is green, the existing build still succeeds, and (where applicable) a new test exists.
- A "Verification" section at the end of each phase lists the exact commands the agent should run before marking the phase complete.

---

## Phase 1 — Build, project, and packaging hygiene

> Foundation. Get the pbxproj, entitlements, and run script in sync so every later change can be built and shipped cleanly.

### 1.1 Sync `project.yml` with the Xcode project
- [x] **1.1.1 completed** Run `xcodegen generate` against the existing `project.yml` and commit the regenerated `PageLumen.xcodeproj/project.pbxproj`. Verified that the regenerated pbxproj contains the `CODE_SIGN_ENTITLEMENTS = Config/PageLumen.entitlements` build setting (`PageLumen.xcodeproj/project.pbxproj:500, 601`) and `ENABLE_HARDENED_RUNTIME = YES` (`:503, 604`).

### 1.2 Add sandbox + screen-capture entitlements
- [x] **1.2.1 completed** `Config/PageLumen.entitlements` now contains the minimum entitlements required for an App Store sandboxed build: `app-sandbox`, `files.user-selected.read-only`, `files.user-selected.read-write`, `screen-capture`.
- [x] **1.2.2 completed** `ENABLE_HARDENED_RUNTIME = YES` is set in `project.yml:39` and confirmed in the regenerated pbxproj (`:503, 604`).
- [x] **1.2.3 completed** Verified `LSApplicationCategoryType = public.app-category.productivity` and `NSHumanReadableCopyright` are present in the generated `Info.plist` (`generated/PageLumen-Info.plist` via `project.yml:48-55`).

### 1.3 Migrate `screencapture` shell-out to ScreenCaptureKit
- [ ] **1.3.1** Replace the `Process`-based `/usr/sbin/screencapture` invocation in `Sources/PageLumen/Support/ScreenshotCaptureService.swift:32-53` with a `SCScreenshotManager` flow (or `CGRequestScreenCaptureAccess` for the prompt + `SCStreamConfiguration` for capture).
- [ ] **1.3.2** Add a first-time permission prompt UI element in `Sources/PageLumen/Views/HomeView.swift` (or a dedicated `OnboardingView`) that calls `CGRequestScreenCaptureAccess()` and explains why access is requested. The current UI assumes permission already exists. Source: `HomeView.swift:47-57`.
- [ ] **1.3.3** Add a `defer`/cleanup so partial capture temp files are removed on app launch (clean up any stale `PageLumen-Selection-*.png` / `PageLumen-Window-*.png` in `FileManager.default.temporaryDirectory`). Source: `DocumentStore.swift:323-327` and `ScreenshotCaptureService.swift:33-36`.
- [ ] **1.3.4** Add a cancellation token for in-flight capture so the user can dismiss the system screen-selection modal from inside the app. Source: `ScreenshotCaptureService.swift:32-53`.

### 1.4 Unify supported file extensions
- [x] **1.4.1 completed** `DocumentProcessor.supportedExtensions: [String]` is the single source of truth (`DocumentProcessor.swift:36-38`). `BatchImportQueue.isSupportedURL` and `DocumentProcessor.process(url:)` both consult it. New test `BatchImportQueueTests.testIsSupportedURLMatchesDocumentProcessorSupportedExtensions` asserts the two call sites agree.

### 1.5 Add a project-level development helper
- [x] **1.5.1 completed** `Makefile` at repo root with `help`, `test`, `build`, `release`, `lint`, `clean`. Verified with `make -n`.
- [x] **1.5.2 completed** `script/lint.sh` runs `swift test`, `swift build -c release`, and `script/validate_release.sh` when a build artifact exists. Executable, syntax-checked with `bash -n`.

### 1.6 Fix `script/build_and_run.sh` Info.plist
- [x] **1.6.1 completed** Heredoc in `script/build_and_run.sh` now writes the same 11 keys as the Xcode-generated plist (`CFBundleDisplayName`, `CFBundleShortVersionString`, `CFBundleVersion`, `LSApplicationCategoryType = public.app-category.productivity`, `NSHumanReadableCopyright`, etc.). `bash -n` passes.

### 1.7 Add CI for the app target
- [ ] **1.7.1** Extend `.github/workflows/ci.yml` (currently runs only `swift test`) with an `xcodebuild` job that builds the `PageLumen` scheme on `macos-latest` with the `generic/platform=macOS` destination. Source: `.github/workflows/ci.yml:1-19`.

### 1.8 Phase 1 verification
- [x] **verification completed** `swift test` is green (34/34). `xcodebuild ... build` succeeds. New entitlements are visible in the regenerated pbxproj. `make test` and `make build` work.

---

## Phase 2 — Correctness, concurrency, and performance

> Fix the concrete bugs found in the audit. These are independent of UI work and should land in one focused PR.

### 2.1 Cancellation correctness in `processPDF`
- [x] **2.1.1 completed** `try Task.checkCancellation()` is the first statement of the per-page loop in `processPDF` (`DocumentProcessor.swift:102`).
- [x] **2.1.2 completed** In-loop `await onProgress?(document)` calls are now guarded with `if Task.isCancelled { return analyzedDocument(document) }` (`DocumentProcessor.swift:108, 134`). A small `analyzedDocument(_:)` helper folds the post-loop `.complete` + analyze + final snapshot into a single return path used by both happy-path and cancel-path returns.

### 2.2 Concurrency hygiene in `DocumentStore`
- [ ] **2.2.1** In `DocumentStore.importURLs` (`DocumentStore.swift:190-248`) and `pasteImageFromClipboard` (`DocumentStore.swift:264-301`), wrap the progress-callback body inside an explicit `Task { @MainActor in ... }` to make the MainActor hop unambiguous to future readers.
- [x] **2.2.2 completed** `DocumentStore` now memoizes a single `DocumentProcessor` instance (`DocumentStore.swift:44-50`). `processor` just returns the cached instance.

### 2.3 Debounce editable block writes
- [x] **2.3.1 completed** `EditableBlockRow` (`ReviewView.swift:325-336, 339-360`) now uses `@State private var commitTask: Task<Void, Never>?` and a 250 ms debounce via `Task { try? await Task.sleep(for: .milliseconds(250)); ... }`. `.onDisappear` flushes any pending edit. Comment explains the reason.
- [ ] **2.3.2** Add a unit test that asserts the store is not mutated on every keystroke (e.g. a counter test using a fake clock).

### 2.4 Cache `exportPreviewText`
- [x] **2.4.1 completed** `DocumentStore.exportPreviewText` is now cached by `(format, optionsHash, documentVersion, limit)`. `currentDocumentVersion` is a content fingerprint of `document.id` + page count + block count + every block id. Comment explains the cache key. (`DocumentStore.swift:420-475`.)
- [ ] **2.4.2** Add a unit test for the cache: same inputs return the same cached string; mutated document re-renders.

### 2.5 Move PDF rendering off `lockFocus`
- [ ] **2.5.1** Replace `image.lockFocus` / `pdfPage.draw(with:to:)` in `DocumentProcessor.render` (`DocumentProcessor.swift:277-290`) with an off-screen `CGContext` render. Avoid retaining a backing bitmap the size of the page.
- [ ] **2.5.2** Replace `NSImage.pngData(maxPixelSize:)` in `DocumentProcessor.swift:298-316` with `CGImageSourceCreateThumbnailAtIndex` + `CGImageDestination` to avoid main-thread `lockFocus`.

### 2.6 Parallelize per-page OCR
- [ ] **2.6.1** In `DocumentProcessor.processPDF` (`DocumentProcessor.swift:97-131`), after pre-rendering every page to an image, run OCR in parallel using `TaskGroup` with a concurrency cap of `max(1, ProcessInfo.processInfo.activeProcessorCount / 2)`. Preserve per-page ordering on assembly.
- [ ] **2.6.2** Add a performance test that processes a 10-page fixture PDF and asserts it completes in < 60 s on the CI runner (with `continueAfterFailure = true` and a generous upper bound so it does not flake).

### 2.7 Fix `mergeAdjacentOCRLines` scaling
- [ ] **2.7.1** Replace the `O(n²)` `mergeAdjacentOCRLines` implementation in `LayoutAnalyzer.swift:167-186` with a sweep-line algorithm that groups by quantized y-coordinate buckets, then merges within a bucket by x-overlap. Keep the existing test (`LayoutAnalyzerTests.testAdjacentOCRLinesAreMergedIntoReadableParagraphs`) green.

### 2.8 Phase 2 verification
- [x] **verification completed** `swift test` is green (34/34). `xcodebuild build` succeeds (`** BUILD SUCCEEDED **`). Manual smoke test on a 50-page PDF is left for the developer to run interactively.

---

## Phase 3 — Models, protocols, and testability

> Make the engine injectable and add the missing test surface. This unlocks Phase 4 and Phase 5.

### 3.1 Introduce a `DocumentImporting` protocol
- [ ] **3.1.1** Extract a `DocumentImporting` protocol that returns a stream of `ReaderDocument` snapshots and a final `ReaderDocument`. `DocumentProcessor` should conform.
- [ ] **3.1.2** Change `DocumentStore.processor` (`DocumentStore.swift:44-46`) to be of type `any DocumentImporting` and accept an injected instance for tests.

### 3.2 Introduce a `DocumentPersisting` protocol
- [ ] **3.2.1** Define a `DocumentPersisting` protocol with `save(_:)`, `load(id:)`, `recentDocuments()`, and `forgetAll()`. Provide a `UserDefaultsPersisting` implementation backed by a JSON file in `Application Support/PageLumen/Library/`. Source: `DocumentStore.swift:456-462` (currently in-memory only).
- [ ] **3.2.2** Wire `DocumentStore.init` to load persisted recent documents on launch.

### 3.3 Enums for block metadata
- [x] **3.3.1 completed** `BlockSource: String, Codable, Sendable` enum added to `Models.swift:61-76` (cases: `visionOCR`, `embeddedPDF`, `receiptProfile`, `userEdited`). `metadataValue` computed property centralizes the raw-value cast. `TextBlock.blockSource` reads `metadata["source"]` and maps to the enum. Write sites at `DocumentProcessor.swift:116, 215` and `LayoutAnalyzer.swift:124, 192-193` use the enum.
- [ ] **3.3.2** Decide whether to add a typed `source: BlockSource` field to `TextBlock` (`Models.swift:101-130`) and migrate existing call sites.

### 3.4 Add `DocumentStoreTests`
- [ ] **3.4.1** Create `Tests/PageLumenCoreTests/DocumentStoreTests.swift` (or a new `Tests/PageLumenTests/` target) with at least:
  - `testLoadSampleResetsDocumentAndNavigatesToReview` — uses the in-memory `SampleDataFactory` and a fake `DocumentImporting`.
  - `testMoveBlockUpdatesReadingOrderAndTriggersSummaryRegeneration`.
  - `testMarkBlockReviewedUpdatesReviewProgress`.
  - `testForgetAllRecentDocumentsEmptiesLibrary`.

### 3.5 Add a fixture corpus
- [ ] **3.5.1** Create `Tests/Fixtures/` containing at least: a screenshot PNG, a 2-column academic-style PDF, a slide-style PDF, and a receipt-style PNG. Each fixture is paired with a `*.expected.json` file in `Tests/Fixtures/Expected/`.
- [ ] **3.5.2** Add a `FixtureCorpusTests.swift` that loads each fixture, runs `DocumentProcessor`, and asserts the produced `ReaderDocument` decodes to the expected JSON (ignoring `id`, `createdAt`, and `thumbnailData`).

### 3.6 Snapshot tests for exports
- [ ] **3.6.1** Add a Markdown snapshot test that locks down the current output for the sample document. Source: existing `ExportEngineTests.testMarkdownExportIncludesHeadingsPageMarkersTablesAndFigures` (`ExportEngineTests.swift:6-16`).
- [ ] **3.6.2** Add a tagged-HTML snapshot test. Source: `AdvancedExportTests.testTaggedHTMLExportIncludesAccessibilityLandmarksAndAuditMetadata` (`AdvancedExportTests.swift:129-140`).
- [ ] **3.6.3** Add a CSV snapshot test that locks down row order and formula-injection behavior.

### 3.7 Phase 3 verification
- [ ] `swift test` is green.
- [ ] New tests fail when their corresponding behavior is broken (sanity check by deliberately breaking one).

---

## Phase 4 — Accessibility

> The audit identified concrete a11y gaps. Land them in small, reviewable PRs.

### 4.1 Make editable rows screen-reader friendly
- [x] **4.1.1 completed** `.accessibilityValue(block.text)` is on the `TextEditor` in `EditableBlockRow` (`ReviewView.swift:317-333`).
- [x] **4.1.2 completed** Label is now `"\(block.type.rawValue.capitalized) block, confidence \(percent) percent"`, hint is `"Edit text, change type, or toggle reviewed."` (`ReviewView.swift:330-332`).

### 4.2 Label the reading-order overlay
- [x] **4.2.1 completed** Each overlay rectangle now has `.accessibilityElement()`, `.accessibilityLabel("Block \(index + 1)")`, and `.accessibilityValue(block.text.prefix(80))`. The `ForEach` is wrapped in `.accessibilityElement(children: .contain)` with `.accessibilityLabel("Reading order overlay, \(page.blocks.count) blocks")` (`PreviewPane.swift:78-84`).

### 4.3 Add Dynamic Type / scaled font support
- [ ] **4.3.1** Audit every hard-coded `Font` literal across the views (`HomeView.swift`, `ReviewView.swift`, `SummaryExportView.swift`, `ContentView.swift`, `SettingsView.swift`, `SidebarView.swift`, `PreviewPane.swift`, `ProcessingView.swift`) and switch to semantic styles (`Font.body`, `Font.title3`, etc.) where appropriate. Keep the existing `fontWeight` and `lineLimit`.
- [ ] **4.3.2** For sizes that genuinely need a fixed value (e.g. workflow step pill numbers), wrap with `ScaledMetric` and document the choice.

### 4.4 Reduce-motion and reduce-transparency support
- [ ] **4.4.1** If any view-level animations are added in the future, gate them on `@Environment(\.accessibilityReduceMotion)`.
- [ ] **4.4.2** Ensure surfaces that use `.regularMaterial` / `.ultraThinMaterial` fall back to solid `AccessibleStyle.panelBackground` when `accessibilityReduceTransparency` is true.

### 4.5 Centralize status indicators
- [x] **4.5.1 completed** `Sources/PageLumen/Support/StatusBadge.swift` defines `StatusDescriptor { label, systemImage, tint }` and extensions on `OCRStatus` and `BatchImportItemStatus` exposing `statusDescriptor`. `ProcessingView.swift` and `SidebarView.swift` use the new helpers. The duplicate label/image/tint logic in `ProcessingView.swift:190-228` and `SidebarView.swift:119-147` has been removed.
- [ ] **4.5.2** Add an `AccessibilityAudit: "All status indicators include both an icon and a text label"` test that walks the view tree.

### 4.6 Announce drop-zone activity
- [ ] **4.6.1** When the user drops files in `HomeView` (`HomeView.swift:75-97`), post a `NSAccessibility.post(...announcementRequested...)` with the number of accepted files and their summary. The current UI does not announce the result.

### 4.7 High-contrast / boost-contrast toggle
- [ ] **4.7.1** Add a "Boost contrast" toggle to `SettingsView` (`SettingsView.swift:23-28`) that swaps the `AccessibleStyle.border` / `panelBackground` colors for high-contrast alternates.
- [ ] **4.7.2** Document the choice in `SettingsView`'s "Privacy" section so users know what it changes.

### 4.8 Phase 4 verification
- [ ] Run the app with VoiceOver enabled and complete the four-step workflow: add → process → review → export.
- [ ] Run with Increase Contrast enabled and verify the new tokens render.
- [ ] `swift test` is green.

---

## Phase 5 — Privacy, security, and data hygiene

### 5.1 Sanitize exports
- [ ] **5.1.1** Add an `ExportSanitizer` that strips `ReaderDocument.sourceURL` from JSON output (`Models.swift:243` is serialized by `ExportEngine.jsonData` via Codable at `ExportEngine.swift:447-460`). Add a `redactSourceURL` option to `ExportOptions`.
- [ ] **5.1.2** Truncate or hash the OCR text snippet in `AccessibilityAuditor.audit` messages (`ExportEngine.swift:144`). The 80-character preview is a privacy smell for legal/medical PDFs.
- [ ] **5.1.3** Add a "Save export anonymously" toggle in `SummaryExportView` that flips the new sanitizer options on. Source: `SummaryExportView.swift:107-139`.

### 5.2 Security-scoped URLs
- [ ] **5.2.1** Wrap every URL read in `DocumentProcessor` and the Save Panel with `url.startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`. Source: `DocumentStore.swift:179-181` and the panel at `DocumentStore.swift:425-440`.
- [ ] **5.2.2** Add a test that asserts the security-scoped lifecycle is balanced (e.g. via a `URLProtocol` stub or a fake resource).

### 5.3 Forget-all action
- [ ] **5.3.1** Add `DocumentStore.forgetAllRecentDocuments()` and a corresponding entry in `SettingsView` under a new "Library" section. Source: `DocumentStore.swift:456-462`, `SettingsView.swift:53-64`.
- [ ] **5.3.2** Persist a `lastClearedAt` timestamp via the new `DocumentPersisting` protocol and surface it in the Library section so users can see when they last cleared.

### 5.4 Onboarding
- [ ] **5.4.1** Add a one-screen `OnboardingView` that explains the local-first promise, requests screen-capture permission if needed, and points the user at the "Try Demo" button. Source: app boots straight into the sample demo (`DocumentStore.swift:24`).
- [ ] **5.4.2** Show the onboarding only on first launch (gated on the `DocumentPersisting` store).

### 5.5 Move `SampleData.swift` out of the production framework
- [ ] **5.5.1** Wrap `SampleDataFactory` in `#if DEBUG` (or move it to a `Tests/`-only test fixture) so it does not ship in the App Store binary. Source: `SampleData.swift:1-74`.

### 5.6 Phase 5 verification
- [ ] `swift test` is green.
- [ ] Manual review: a sandboxed build of the app reads only user-selected files and writes only user-selected paths.
- [ ] Exported JSON does not contain `sourceURL` when "Save export anonymously" is on.

---

## Phase 6 — Layout, headings, and reading order improvements

> Move beyond the current keyword-based heuristics toward the PRD's P0/P1 reading-order commitments.

### 6.1 Real heading-level detection
- [ ] **6.1.1** Replace the `^\d+\.\d+` regex in `LayoutAnalyzer.headingLevel` (`LayoutAnalyzer.swift:324-326`) with a font-size + position + numbering + capitalization model. Use Vision's `recognitionLanguages` for known section labels.
- [ ] **6.1.2** Add tests for: numbered sections (`1.`, `1.1`, `1.1.1`), Roman numerals, all-caps headings, and short bold-looking lines.

### 6.2 3-column and sidebar reading order
- [ ] **6.2.1** Extend `LayoutAnalyzer.classifyLayout` and `orderedBlocks` (`LayoutAnalyzer.swift:69-96, 152-165`) to handle 3+ column layouts and sidebars (blocks with very narrow width, persistent across pages, occupying < 20% of the page width).
- [ ] **6.2.2** Add a layout test for 3-column and 2-column-with-sidebar fixtures.

### 6.3 Footnote and caption detection
- [ ] **6.3.1** Add a "footnote" / "caption" classifier that looks for short text near the bottom of pages (footnotes) or near figures (captions). Promote the type to `caption` and exclude by default from speech (`DocumentEditing.fullText` at `DocumentEditing.swift:111-117` should get a new `includeCaptions` option).

### 6.4 Drag-and-drop block reordering
- [ ] **6.4.1** Replace the up/down buttons in `EditableBlockRow` (`ReviewView.swift:285-299`) with a SwiftUI `.onDrag` / `.onDrop` pair. Keep the keyboard move-up/down shortcuts.
- [ ] **6.4.2** Add an accessibility hint that explains the new gesture.

### 6.5 Phase 6 verification
- [ ] `swift test` is green.
- [ ] Manual test on a 3-column academic PDF and a 2-column paper with a sidebar.
- [ ] Manual test on a document with footnotes — confirm they are captioned and can be excluded from the spoken summary.

---

## Phase 7 — Product gaps vs PRD

> Each item traces back to a `pagelumen_prd.md` reference. Tackle in priority order; some depend on earlier phases.

### 7.1 Audio export
- [ ] **7.1.1** Add an "Export audio" action that uses `AVSpeechSynthesizer.write(_:toBufferCallback:)` to produce a `.m4a` or `.wav` file. Source: PRD P1, `pagelumen_prd.md:412`.
- [ ] **7.1.2** Wire the new format into `ExportFormat` (`ExportEngine.swift:4-27`) and add a UI button in `SummaryExportView` (`SummaryExportView.swift:107-139`).

### 7.2 DOCX export
- [ ] **7.2.1** Add a small DOCX writer (heading + paragraph + table + image + alt-text) and a `case docx = "DOCX"` in `ExportFormat`. Update `ExportEngine.data` switch.
- [ ] **7.2.2** Add unit tests for the DOCX writer (verifies the `word/document.xml` payload and zip structure).

### 7.3 Multi-language OCR
- [ ] **7.3.1** Set `request.recognitionLanguages` and `request.automaticallyDetectsLanguage = true` on `VNRecognizeTextRequest` in `DocumentProcessor.swift:182-219`. Wire the user-selected language hint from `SettingsView` (`SettingsView.swift:40-50`) into the request.
- [ ] **7.3.2** Add a fixture test for an image with non-English text and assert the language is detected.

### 7.4 Audio-friendly summary improvements
- [ ] **7.4.1** The current `ExplanationEngine.summary` (`ExplanationEngine.swift:32-58`) just concatenates the first N blocks. Add a real summary generator that:
  - Joins full paragraphs across pages.
  - Detects heading text to anchor the summary.
  - Avoids reading visible-only references.
- [ ] **7.4.2** Add a snapshot test for short/medium/detailed summaries.

### 7.5 First-run and recents UI
- [ ] **7.5.1** Persist recent documents to disk via the new `DocumentPersisting` protocol. Source: `DocumentStore.swift:456-462` (in-memory only today).
- [ ] **7.5.2** Add a "Recent documents" section to the sidebar (`SidebarView.swift:48-72`) and the home view with thumbnail previews and last-opened dates.

### 7.6 Search across the whole document
- [ ] **7.6.1** Move the search index from a per-keystroke `localizedCaseInsensitiveContains` (`DocumentStore.swift:119-125`) into a precomputed token index built once per document. Wire it into `filteredSelectedPageBlocks` and `jumpToNextSearchMatch`.
- [ ] **7.6.2** Add a "Find in preview" overlay that highlights the current match in `PreviewPane` (`PreviewPane.swift:5-95`).

### 7.7 Tagged accessible PDF
- [ ] **7.7.1** Move the current PDF generation (`ExportEngine.pdfData` at `ExportEngine.swift:335-377`) onto `PDFKit` (`PDFDocument` + `PDFPage` + attributed strings) so the output supports tagging, structure tree, and reading-order hints.
- [ ] **7.7.2** Add `/Title`, `/Author`, `/Lang`, and `/Producer` metadata via the `kCGPDFContextTitleDictionary` keys. Source: `ExportEngine.swift:339-340`.
- [ ] **7.7.3** Add a `pdfua-lint` style self-check (basic structure tree, language tag, title presence) and surface the result in the accessibility audit.

### 7.8 Shortcuts and AppleScript support
- [ ] **7.8.1** Add an `AppIntents` target with an `OpenDocumentIntent` and a `GetSummaryIntent`. The app should accept dropped URLs from Shortcuts and return extracted text.
- [ ] **7.8.2** Add a minimal `PageLumen.applescript` dictionary so power users can drive the app from Script Editor.

### 7.9 In-app onboarding
- [ ] **7.9.1** Add a small `OnboardingView` that introduces the four-step workflow and links to the privacy / accessibility documentation. Source: PRD mentions onboarding (`pagelumen_prd.md:511`).
- [ ] **7.9.2** Add a "Show this on launch" toggle in `SettingsView`.

### 7.10 Assets and icon
- [ ] **7.10.1** Create an `Assets.xcassets` with an `AppIcon.appiconset` and a `Contents.json`. Source: no `Assets.xcassets` exists today.
- [ ] **7.10.2** Wire the asset catalog into `project.yml` (XcodeGen) and the regenerated pbxproj.

### 7.11 Phase 7 verification
- [ ] `swift test` is green.
- [ ] `xcodebuild build` succeeds.
- [ ] Manual smoke test of the new exports (audio, DOCX).
- [ ] Tagged PDF passes a basic structure-tree self-check.

---

## Cross-cutting documentation updates

- [x] **D.1 completed** `CHANGELOG.md` at repo root, "Keep a Changelog" format with `Unreleased` and `1.0.0` sections.
- [x] **D.2 completed** `docs/architecture.md` (61 lines) describes the `PageLumenCore` ↔ `PageLumen` split, import pipeline, review pipeline, export pipeline, concurrency model, and the recipe for adding a new export format.
- [x] **D.3 completed** `docs/privacy.md` (34 lines) extracted from the PRD's privacy section, covers local processing, no third-party SDKs, export sanitization, clearing local data, and links to `SECURITY.md`.
- [x] **D.4 completed** `docs/superpowers/plans/2026-05-05-sightline-reader-mvp.md` renamed to `2026-05-05-pagelumen-mvp.md` (preserves git history via `git mv`). The other two plan files (`batch-import.md`, `prd-completion-slice.md`) had no `Sightline` in their filenames; their in-content references were rewritten.
- [ ] **D.5** Update `CONTRIBUTING.md` to mention the rename and to point at the new docs.
- [x] **D.6 completed** `docs/accessibility.md` (38 lines) summarizes the app's accessibility posture and known limitations.
- [ ] **D.7** Add a public contact email to `SECURITY.md` (currently says "contact the maintainer directly").

---

## Final verification (run before declaring the plan complete)

- [ ] `swift test` — all suites green, including new fixture corpus and snapshot tests.
- [ ] `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Debug -destination 'generic/platform=macOS' build` — succeeds.
- [ ] `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Release -destination 'generic/platform=macOS' archive -archivePath dist/PageLumen.xcarchive` — succeeds with the new entitlements and hardened runtime.
- [ ] `script/validate_release.sh dist/PageLumen.xcarchive/Products/Applications/PageLumen.app` — passes.
- [ ] Manual smoke test of the four-step workflow on a real PDF, image, clipboard, and screenshot.
- [ ] Manual VoiceOver pass on the four-step workflow.
- [ ] Manual sandbox launch: the app reads/writes only user-selected paths and requests screen-capture permission before capturing.

---

## Self-review

- All audit findings (Sections 1–11 of the audit) are covered by at least one task above. Each task references the relevant file and line range so it can be picked up by an agent without re-reading the audit.
- No task introduces network code, third-party SDKs, or PDF/UA compliance claims.
- Phase order is chosen so each phase leaves the app in a buildable, testable state. The "Quick wins" subset (1.1, 1.2, 1.4, 1.5, 1.6, 1.8, 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 4.5, 5.3, 5.5) is intentionally compact and can ship in a single PR.
- The plan respects the existing `PageLumenCore` / `PageLumen` split and the Swift 5 language mode in `Package.swift:18, 25, 32`.
- Tasks 3.1 and 3.2 are the only structural changes to public APIs. Everything else is internal or additive.
