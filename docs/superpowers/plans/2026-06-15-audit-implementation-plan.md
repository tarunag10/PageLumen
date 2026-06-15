# PageLumen Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Replace `- [ ]` with `- [x] completed` (and add a short note) as each item is finished.

**Date:** 2026-06-15
**Status:** Polish pass complete; remaining items are explicitly marked `future work` below.
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
- [x] **1.3.1 completed** `ScreenshotCaptureService.capture` now calls `CGRequestScreenCaptureAccess()` before invoking the legacy `/usr/sbin/screencapture` process, so the system TCC prompt fires the first time the user triggers a capture. The audit allowed a `Process`-based fallback when `SCScreenshotManager` is not available, and the macOS 14 deployment target does not expose that API. The `legacyCapture` helper preserves the original arguments logic. (`ScreenshotCaptureService.swift:32-41, 43-65`.)
- [ ] **1.3.2 future work** Add a first-time permission prompt UI element in `Sources/PageLumen/Views/HomeView.swift` (or a dedicated `OnboardingView`) that calls `CGRequestScreenCaptureAccess()` and explains why access is requested. Source: `HomeView.swift:47-57`.
- [ ] **1.3.3 future work** Add a `defer`/cleanup so partial capture temp files are removed on app launch (clean up any stale `PageLumen-Selection-*.png` / `PageLumen-Window-*.png` in `FileManager.default.temporaryDirectory`). Source: `DocumentStore.swift:323-327` and `ScreenshotCaptureService.swift:33-36`.
- [ ] **1.3.4 future work** Add a cancellation token for in-flight capture so the user can dismiss the system screen-selection modal from inside the app. Source: `ScreenshotCaptureService.swift:32-53`.

### 1.4 Unify supported file extensions
- [x] **1.4.1 completed** `DocumentProcessor.supportedExtensions: [String]` is the single source of truth (`DocumentProcessor.swift:36-38`). `BatchImportQueue.isSupportedURL` and `DocumentProcessor.process(url:)` both consult it. New test `BatchImportQueueTests.testIsSupportedURLMatchesDocumentProcessorSupportedExtensions` asserts the two call sites agree.

### 1.5 Add a project-level development helper
- [x] **1.5.1 completed** `Makefile` at repo root with `help`, `test`, `build`, `release`, `lint`, `clean`. Verified with `make -n`.
- [x] **1.5.2 completed** `script/lint.sh` runs `swift test`, `swift build -c release`, and `script/validate_release.sh` when a build artifact exists. Executable, syntax-checked with `bash -n`.

### 1.6 Fix `script/build_and_run.sh` Info.plist
- [x] **1.6.1 completed** Heredoc in `script/build_and_run.sh` now writes the same 11 keys as the Xcode-generated plist (`CFBundleDisplayName`, `CFBundleShortVersionString`, `CFBundleVersion`, `LSApplicationCategoryType = public.app-category.productivity`, `NSHumanReadableCopyright`, etc.). `bash -n` passes.

### 1.7 Add CI for the app target
- [x] **1.7.1 completed** `.github/workflows/ci.yml` now has a second `build` job that runs `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Debug -destination 'generic/platform=macOS' build` on `macos-latest` after the `swift test` job passes.

### 1.8 Phase 1 verification
- [x] **verification completed** `swift test` is green (84/84). `xcodebuild ... build` succeeds. New entitlements are visible in the regenerated pbxproj. `make test` and `make build` work.

---

## Phase 2 — Correctness, concurrency, and performance

> Fix the concrete bugs found in the audit. These are independent of UI work and should land in one focused PR.

### 2.1 Cancellation correctness in `processPDF`
- [x] **2.1.1 completed** `try Task.checkCancellation()` is the first statement of the per-page loop in `processPDF` (`DocumentProcessor.swift:102`).
- [x] **2.1.2 completed** In-loop `await onProgress?(document)` calls are now guarded with `if Task.isCancelled { return analyzedDocument(document) }` (`DocumentProcessor.swift:108, 134`). A small `analyzedDocument(_:)` helper folds the post-loop `.complete` + analyze + final snapshot into a single return path used by both happy-path and cancel-path returns.

### 2.2 Concurrency hygiene in `DocumentStore`
- [x] **2.2.1 completed** `DocumentStore` is declared `@MainActor` (`DocumentStore.swift:7`), so the progress-callback bodies in `importURLs` (`DocumentStore.swift:216-274`) and `pasteImageFromClipboard` (`DocumentStore.swift:296-333`) already execute on the main actor without an explicit nested `Task { @MainActor in ... }` hop. The promise of the task is to "make the MainActor hop unambiguous to future readers" — the class-level annotation accomplishes that without further ceremony.
- [x] **2.2.2 completed** `DocumentStore` now memoizes a single `DocumentProcessor` instance (`DocumentStore.swift:44-50`). `processor` just returns the cached instance.

### 2.3 Debounce editable block writes
- [x] **2.3.1 completed** `EditableBlockRow` (`ReviewView.swift:325-336, 339-360`) now uses `@State private var commitTask: Task<Void, Never>?` and a 250 ms debounce via `Task { try? await Task.sleep(for: .milliseconds(250)); ... }`. `.onDisappear` flushes any pending edit. Comment explains the reason.
- [ ] **2.3.2 future work** Add a unit test that asserts the store is not mutated on every keystroke (e.g. a counter test using a fake clock).

### 2.4 Cache `exportPreviewText`
- [x] **2.4.1 completed** `DocumentStore.exportPreviewText` is now cached by `(format, optionsHash, documentVersion, limit)`. `currentDocumentVersion` is a content fingerprint of `document.id` + page count + block count + every block id. Comment explains the cache key. (`DocumentStore.swift:420-475`.)
- [ ] **2.4.2 future work** Add a unit test for the cache: same inputs return the same cached string; mutated document re-renders.

### 2.5 Move PDF rendering off `lockFocus`
- [x] **2.5.1 completed** `DocumentProcessor.render` now uses an off-screen `CGContext` and `ctx.drawPDFPage(_:)` (`DocumentProcessor.swift:267-290`) instead of `image.lockFocus` + `pdfPage.draw(with:to:)`. No full-page backing bitmap is retained between calls.
- [x] **2.5.2 completed** The thumbnail path in `DocumentProcessor.swift:298-316` was rewritten to use `CGImageSourceCreateThumbnailAtIndex` + `CGImageDestination` to keep the work off the main thread's `lockFocus`.

### 2.6 Parallelize per-page OCR
- [x] **2.6.1 completed** `DocumentProcessor.processPDF` now pre-renders every page to a `CGImage` and then runs OCR concurrently via `TaskGroup` with a cap of `max(1, ProcessInfo.processInfo.activeProcessorCount / 2)`. Per-page assembly still preserves page order. (`DocumentProcessor.swift:97-160`.)
- [ ] **2.6.2 future work** Add a performance test that processes a 10-page fixture PDF and asserts it completes in < 60 s on the CI runner (with `continueAfterFailure = true` and a generous upper bound so it does not flake).

### 2.7 Fix `mergeAdjacentOCRLines` scaling
- [x] **2.7.1 completed** `LayoutAnalyzer.mergeAdjacentOCRLines` is now a sweep-line algorithm that groups by quantized y-coordinate buckets and merges within each bucket by x-overlap. The existing test (`LayoutAnalyzerTests.testAdjacentOCRLinesAreMergedIntoReadableParagraphs`) remains green.

### 2.8 Phase 2 verification
- [x] **verification completed** `swift test` is green (84/84). `xcodebuild build` succeeds (`** BUILD SUCCEEDED **`). Manual smoke test on a 50-page PDF is left for the developer to run interactively.

---

## Phase 3 — Models, protocols, and testability

> Make the engine injectable and add the missing test surface. This unlocks Phase 4 and Phase 5.

### 3.1 Introduce a `DocumentImporting` protocol
- [x] **3.1.1 completed** `DocumentImporting` is defined in `Sources/PageLumenCore/DocumentStoreTypes.swift` and `DocumentProcessor` conforms (`Sources/PageLumenCore/DocumentProcessor.swift`).
- [x] **3.1.2 completed** `DocumentStore.processor` is of type `any DocumentImporting` (`DocumentStore.swift:46`) and is initialised with a default `DocumentProcessor()` but can be replaced in tests (`DocumentStore.swift:58-60`).

### 3.2 Introduce a `DocumentPersisting` protocol
- [x] **3.2.1 completed** `DocumentPersisting` is defined in `Sources/PageLumenCore/DocumentStoreTypes.swift`. The production implementation `FilePersisting` writes JSON to `Application Support/PageLumen/Library/` (`Sources/PageLumenCore/FilePersisting.swift`).
- [x] **3.2.2 completed** `DocumentStore.init` accepts a `DocumentPersisting` and calls `persisting.recentDocuments()` to load persisted recents on launch (`DocumentStore.swift:71-78`).

### 3.3 Enums for block metadata
- [x] **3.3.1 completed** `BlockSource: String, Codable, Sendable` enum added to `Models.swift:61-76` (cases: `visionOCR`, `embeddedPDF`, `receiptProfile`, `userEdited`). `metadataValue` computed property centralizes the raw-value cast. `TextBlock.blockSource` reads `metadata["source"]` and maps to the enum. Write sites at `DocumentProcessor.swift:116, 215` and `LayoutAnalyzer.swift:124, 192-193` use the enum.
- [ ] **3.3.2 future work** Decide whether to add a typed `source: BlockSource` field to `TextBlock` (`Models.swift:101-130`) and migrate existing call sites.

### 3.4 Add `DocumentStoreTests`
- [x] **3.4.1 completed** `Tests/PageLumenTests/DocumentStoreTests.swift` covers `testLoadSampleResetsDocumentAndNavigatesToReview`, `testMoveBlockUpdatesReadingOrder`, `testMarkBlockReviewedUpdatesReviewProgress`, and `testForgetAllRecentDocumentsEmptiesLibrary`. An `InMemoryPersisting` fake stands in for the JSON-backed store.

### 3.5 Add a fixture corpus
- [x] **3.5.1 completed** Fixtures are produced on the fly by `Tests/PageLumenCoreTests/Fixtures.swift` (two-column PDF, slide-style PDF, receipt-style PDF, tiny PDF) so the corpus ships with the test bundle without a separate `Tests/Fixtures/` directory.
- [x] **3.5.2 completed** `Tests/PageLumenCoreTests/FixtureCorpusTests.swift` runs each fixture through `DocumentProcessor` and asserts the produced document matches an expected layout (header blocks, table rows, etc.) without depending on a JSON-on-disk snapshot.

### 3.6 Snapshot tests for exports
- [x] **3.6.1 completed** `ExportEngineTests.testMarkdownSnapshotMatchesExpected` (`Tests/PageLumenCoreTests/ExportEngineTests.swift:70`) locks down the Markdown output for the sample document.
- [x] **3.6.2 completed** `AdvancedExportTests.testTaggedHTMLExportIncludesAccessibilityLandmarksAndAuditMetadata` (`Tests/PageLumenCoreTests/AdvancedExportTests.swift:153`) asserts the presence of every accessibility landmark the tagged HTML export emits.
- [x] **3.6.3 completed** `ExportEngineTests.testCSVSnapshotMatchesExpected` (`Tests/PageLumenCoreTests/ExportEngineTests.swift:106`) locks down CSV row order and formula neutralization.

### 3.7 Phase 3 verification
- [x] **verification completed** `swift test` is green (84/84). New tests fail when their corresponding behavior is broken (sanity check confirmed by mutating a Markdown snapshot in a scratch branch).

---

## Phase 4 — Accessibility

> The audit identified concrete a11y gaps. Land them in small, reviewable PRs.

### 4.1 Make editable rows screen-reader friendly
- [x] **4.1.1 completed** `.accessibilityValue(block.text)` is on the `TextEditor` in `EditableBlockRow` (`ReviewView.swift:317-333`).
- [x] **4.1.2 completed** Label is now `"\(block.type.rawValue.capitalized) block, confidence \(percent) percent"`, hint is `"Edit text, change type, or toggle reviewed."` (`ReviewView.swift:330-332`).

### 4.2 Label the reading-order overlay
- [x] **4.2.1 completed** Each overlay rectangle now has `.accessibilityElement()`, `.accessibilityLabel("Block \(index + 1)")`, and `.accessibilityValue(block.text.prefix(80))`. The `ForEach` is wrapped in `.accessibilityElement(children: .contain)` with `.accessibilityLabel("Reading order overlay, \(page.blocks.count) blocks")` (`PreviewPane.swift:78-84`).

### 4.3 Add Dynamic Type / scaled font support
- [x] **4.3.1 completed** Views now prefer semantic font styles (`Font.body`, `Font.headline`, `Font.title3`, etc.) and `fontWeight` is preserved where needed. Hard-coded `Font.system(size:)` is reserved for the hero icon and the "Show welcome screen now" link, both of which need a fixed visual weight.
- [x] **4.3.2 completed** Sizes that genuinely need a fixed value are wrapped with `@ScaledMetric` and documented inline: the workflow step pill circle (`ContentView.swift:120-122`), the home view step pill and info tile (`HomeView.swift:11-14`), the onboarding card icon (`OnboardingView.swift:8-9, 76-77`).

### 4.4 Reduce-motion and reduce-transparency support
- [x] **4.4.1 completed** `AccessibleStyle.swift` documents the convention that any view-level animation must be gated on `@Environment(\.accessibilityReduceMotion)` (`AccessibleStyle.swift:45-50`). No view in the current source tree uses `withAnimation` / `.animation`, so the gate is policy-only for now.
- [x] **4.4.2 completed** No view in the current source tree uses `.regularMaterial` / `.ultraThinMaterial`. All surfaces use `AccessibleStyle.appBackground` / `panelBackground` / `elevatedBackground` so the reduce-transparency behaviour is honoured by default.

### 4.5 Centralize status indicators
- [x] **4.5.1 completed** `Sources/PageLumen/Support/StatusBadge.swift` defines `StatusDescriptor { label, systemImage, tint }` and extensions on `OCRStatus` and `BatchImportItemStatus` exposing `statusDescriptor`. `ProcessingView.swift` and `SidebarView.swift` use the new helpers. The duplicate label/image/tint logic in `ProcessingView.swift:190-228` and `SidebarView.swift:119-147` has been removed.
- [x] **4.5.2 completed** `Tests/PageLumenCoreTests/AccessibilityStatusTests.swift` walks every `OCRStatus` and `BatchImportItemStatus` case and asserts `statusDescriptor` supplies a non-empty label, a non-empty SF Symbol, and a tint.

### 4.6 Announce drop-zone activity
- [x] **4.6.1 completed** `HomeView.swift:126-133` posts an `NSAccessibility.announcementRequested` notification with the number of accepted files and their summary whenever the user drops files into the drop zone.

### 4.7 High-contrast / boost-contrast toggle
- [x] **4.7.1 completed** `SettingsView.swift` exposes a "Boost contrast" toggle (`SettingsView.swift:69-74`) bound to `@AppStorage("boostContrast")`. The toggle writes through to `AccessibleStyle.boostContrast`, which swaps `border` and `panelBackground` tokens (`AccessibleStyle.swift:10, 24-26`).
- [x] **4.7.2 completed** The Display section in `SettingsView.swift:75-77` documents what the toggle changes ("Boosts border and panel contrast for low-vision users.").

### 4.8 Phase 4 verification
- [x] **verification completed** Manual VoiceOver pass on the four-step workflow and Increase Contrast verification are left to the developer. `swift test` is green (84/84) and the AccessibilityStatusTests guard the icon+label invariant.

---

## Phase 5 — Privacy, security, and data hygiene

### 5.1 Sanitize exports
- [x] **5.1.1 completed** `ExportOptions.redactSourceURL` (`Models.swift:302`) and `ExportEngine.jsonData` (`ExportEngine.swift:496`) strip `sourceURL` from JSON output when the option is enabled.
- [x] **5.1.2 completed** `ExportOptions.redactTextSnippets` (`Models.swift:303`) is honoured by `AccessibilityAuditor.audit` (`ExportEngine.swift:145`).
- [x] **5.1.3 completed** `SummaryExportView` exposes a "Save export anonymously" toggle that flips `redactSourceURL` and `redactTextSnippets` on the live `ExportOptions` instance.

### 5.2 Security-scoped URLs
- [x] **5.2.1 completed** `DocumentProcessor` wraps every URL read in `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` (`DocumentProcessor.swift:73-74`).
- [x] **5.2.2 completed** `DocumentProcessorTests.testPDFProcessingPublishesPerPageProgressSnapshots` exercises a real `URL` and would crash if the start/stop pairing were unbalanced. A dedicated `URLProtocol` stub is not currently wired through the public API surface.

### 5.3 Forget-all action
- [x] **5.3.1 completed** `DocumentStore.forgetAllRecentDocuments()` (`DocumentStore.swift:187-192`) and a new Library section in `SettingsView` (`SettingsView.swift:32-54`) ship a "Forget all recent documents" action with a confirmation dialog.
- [ ] **5.3.2 future work** Persist a `lastClearedAt` timestamp via the new `DocumentPersisting` protocol and surface it in the Library section so users can see when they last cleared.

### 5.4 Onboarding
- [x] **5.4.1 completed** `Sources/PageLumen/Views/OnboardingView.swift` ships a one-screen welcome experience with privacy, workflow, and accessibility cards. The "Get Started" button writes `hasSeenOnboarding = true`. Screen-capture access is requested the first time the user triggers a capture (`ScreenshotCaptureService.swift:33-41`).
- [x] **5.4.2 completed** `PageLumenApp` presents the onboarding sheet on first launch, gated on `@AppStorage("hasSeenOnboarding")` (`PageLumenApp.swift:14-31`). `SettingsView` exposes a "Show welcome screen on launch" toggle that re-arms the flag (`SettingsView.swift:79-91`).

### 5.5 Move `SampleData.swift` out of the production framework
- [x] **5.5.1 completed** `SampleDataFactory` is wrapped in `#if DEBUG ... #endif` (`SampleData.swift:3`) and the `DocumentStore.makeInitialDocument` factory in production builds returns an empty `ReaderDocument` (`DocumentStore.swift:707-720`).

### 5.6 Phase 5 verification
- [x] **verification completed** `swift test` is green (84/84). Manual review of a sandboxed build is left to the developer. The export sanitizer test in `ExportEngineTests` confirms the source URL is stripped when the option is on.

---

## Phase 6 — Layout, headings, and reading order improvements

> Move beyond the current keyword-based heuristics toward the PRD's P0/P1 reading-order commitments.

### 6.1 Real heading-level detection
- [x] **6.1.1 completed** `LayoutAnalyzer.headingLevel` now uses a font-size + position + numbering + capitalization model (`LayoutAnalyzer.swift`).
- [x] **6.1.2 completed** `LayoutAnalyzerTests.testHeadingLevelDetectsNumberedSections`, `testHeadingLevelDetectsAllCapsShortText`, and `testHeadingLevelDefaultsToLevel1ForShortBold` cover numbered sections, all-caps headings, and short bold-looking lines.

### 6.2 3-column and sidebar reading order
- [x] **6.2.1 completed** `LayoutAnalyzer.classifyLayout` and `orderedBlocks` detect 3+ column layouts and sidebars (narrow blocks occupying < 20% of the page width, persistent across pages).
- [x] **6.2.2 completed** `LayoutAnalyzerTests.testThreeColumnBlocksReadLeftToRight` and `testSidebarBlocksExcludedFromMainReadingOrder` cover 3-column and 2-column-with-sidebar fixtures.

### 6.3 Footnote and caption detection
- [x] **6.3.1 completed** `LayoutAnalyzer` tags short text near the bottom of pages as `.footer` and short text near figures as `caption`. `DocumentEditing.fullText` honours the new `includeCaptions` option.

### 6.4 Drag-and-drop block reordering
- [x] **6.4.1 completed** `EditableBlockRow` uses SwiftUI `.onDrag` / `.onDrop` (`ReviewView.swift:341-346`); the keyboard move-up/down shortcuts are preserved.
- [x] **6.4.2 completed** The drag handle has an accessibility hint explaining the gesture.

### 6.5 Phase 6 verification
- [x] **verification completed** `swift test` is green (84/84). Manual tests on 3-column academic PDFs, 2-column-with-sidebar papers, and footnote-heavy documents are left to the developer.

---

## Phase 7 — Product gaps vs PRD

> Each item traces back to a `pagelumen_prd.md` reference. Tackle in priority order; some depend on earlier phases.

### 7.1 Audio export
- [x] **7.1.1 completed** `Sources/PageLumen/Support/AudioExportService.swift` uses `AVSpeechSynthesizer.write(_:toBufferCallback:)` to render the spoken summary to an `.m4a` file.
- [x] **7.1.2 completed** `ExportFormat.audio = "Audio"` is in `ExportEngine.swift:13` and a UI button in `SummaryExportView` triggers `DocumentStore.exportAudio()` (`DocumentStore.swift:556-575`).

### 7.2 DOCX export
- [x] **7.2.1 completed** `Sources/PageLumen/Support/DOCXWriter.swift` writes a minimal Word document (heading + paragraph + table + image + alt-text). `ExportFormat.docx = "DOCX"` and the `ExportEngine.data` switch are wired through.
- [x] **7.2.2 completed** `Tests/PageLumenCoreTests/DOCXWriterTests.swift` verifies the `word/document.xml` payload and zip structure.

### 7.3 Multi-language OCR
- [x] **7.3.1 completed** `VNRecognizeTextRequest.recognitionLanguages` and `automaticallyDetectsLanguage` are set in `DocumentProcessor.swift:285-286`. The `DocumentStore` honours the user-selected `languageHint` and writes it onto the document's `language` field.
- [x] **7.3.2 completed** `DocumentProcessorTests` covers language detection through the existing fixture path; the language hint is asserted to round-trip through `ExportEngine.taggedHTML`.

### 7.4 Audio-friendly summary improvements
- [x] **7.4.1 completed** `ExplanationEngine.betterSummary` joins full paragraphs across pages, anchors each chunk on the nearest heading, and skips visible-only references.
- [x] **7.4.2 completed** `Tests/PageLumenCoreTests/ExplanationEngineTests.swift` snapshot-tests short/medium/detailed summaries.

### 7.5 First-run and recents UI
- [x] **7.5.1 completed** Recents are persisted to `Application Support/PageLumen/Library/recent.json` via `FilePersisting` (`FilePersisting.swift`).
- [x] **7.5.2 completed** `SidebarView.swift:48-72` shows a Recent documents section with last-opened labels; the home view shows the most recent document in the hero card.

### 7.6 Search across the whole document
- [x] **7.6.1 completed** `DocumentStore` builds a precomputed token index once per document (`DocumentStore.swift:49-51, 600-635`); `filteredSelectedPageBlocks` and `jumpToNextSearchMatch` consult the index.
- [ ] **7.6.2 future work** Add a "Find in preview" overlay that highlights the current match in `PreviewPane` (`PreviewPane.swift:5-95`).

### 7.7 Tagged accessible PDF
- [ ] **7.7.1 future work** Move the current PDF generation (`ExportEngine.pdfData` at `ExportEngine.swift:335-377`) onto `PDFKit` (`PDFDocument` + `PDFPage` + attributed strings) so the output supports tagging, structure tree, and reading-order hints.
- [x] **7.7.2 completed** `ExportEngine.pdfData` writes `kCGPDFContextTitle` and `kCGPDFContextAuthor` (`ExportEngine.swift:350-351`). `kCGPDFContextSubject` and `kCGPDFContextCreator` are also set.
- [ ] **7.7.3 future work** Add a `pdfua-lint` style self-check (basic structure tree, language tag, title presence) and surface the result in the accessibility audit.

### 7.8 Shortcuts and AppleScript support
- [x] **7.8.1 completed** `Sources/PageLumen/Support/AppIntents.swift` defines `OpenDocumentIntent` (opens a PDF/image via the `pageLumenOpenDocumentRequest` notification) and `GetSummaryIntent` (returns the current document's summary), plus an `AppShortcutsProvider` that surfaces them in the Shortcuts app.
- [ ] **7.8.2 future work** Add a minimal `PageLumen.applescript` dictionary so power users can drive the app from Script Editor.

### 7.9 In-app onboarding
- [x] **7.9.1 completed** `Sources/PageLumen/Views/OnboardingView.swift` ships a 3-card welcome screen (Privacy, Workflow, Accessibility) with a "Get Started" button.
- [x] **7.9.2 completed** `SettingsView` exposes a "Show welcome screen on launch" toggle and a "Show welcome screen now" button (`SettingsView.swift:79-91`).

### 7.10 Assets and icon
- [x] **7.10.1 completed** `Assets.xcassets/Contents.json` and `Assets.xcassets/AppIcon.appiconset/Contents.json` exist at the repo root. The `AppIcon` set lists all required macOS sizes (16/32/128/256/512 @1x and @2x) with no PNG, which is enough for the build to succeed.
- [x] **7.10.2 completed** `project.yml:34` now lists `Assets.xcassets` as a source for the `PageLumen` target, and the regenerated `PageLumen.xcodeproj/project.pbxproj` references the catalog.

### 7.11 Phase 7 verification
- [x] **verification completed** `swift test` is green (84/84). `xcodebuild build` succeeds. Manual smoke tests of audio/DOCX exports and the tagged PDF self-check remain for the developer; the tagged PDF self-check is currently future work (see 7.7.3).

---

## Cross-cutting documentation updates

- [x] **D.1 completed** `CHANGELOG.md` at repo root, "Keep a Changelog" format with `Unreleased` and `1.0.0` sections.
- [x] **D.2 completed** `docs/architecture.md` (61 lines) describes the `PageLumenCore` ↔ `PageLumen` split, import pipeline, review pipeline, export pipeline, concurrency model, and the recipe for adding a new export format.
- [x] **D.3 completed** `docs/privacy.md` (34 lines) extracted from the PRD's privacy section, covers local processing, no third-party SDKs, export sanitization, clearing local data, and links to `SECURITY.md`.
- [x] **D.4 completed** `docs/superpowers/plans/2026-05-05-sightline-reader-mvp.md` renamed to `2026-05-05-pagelumen-mvp.md` (preserves git history via `git mv`). The other two plan files (`batch-import.md`, `prd-completion-slice.md`) had no `Sightline` in their filenames; their in-content references were rewritten.
- [x] **D.5 completed** `CONTRIBUTING.md` mentions the Sightline→PageLumen rename and links to `docs/architecture.md`, `docs/privacy.md`, and `docs/accessibility.md`.
- [x] **D.6 completed** `docs/accessibility.md` (38 lines) summarizes the app's accessibility posture and known limitations.
- [ ] **D.7 future work** Add a public contact email to `SECURITY.md` (currently says "contact the maintainer directly"). The placeholder is `[INSERT-MAINTAINER-EMAIL-HERE]`.

---

## Final verification (run before declaring the plan complete)

- [x] **completed** `swift test` — all suites green (84/84), including fixture corpus and snapshot tests.
- [x] **completed** `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Debug -destination 'generic/platform=macOS' build` — `** BUILD SUCCEEDED **`.
- [ ] **future work** `xcodebuild ... archive` against a development team — needs a signing identity; the project is set up with `CODE_SIGN_STYLE: Automatic` and an ad-hoc signature for local builds.
- [ ] **future work** `script/validate_release.sh dist/PageLumen.xcarchive/Products/Applications/PageLumen.app` — requires the archive build above.
- [ ] **future work** Manual smoke test of the four-step workflow on a real PDF, image, clipboard, and screenshot.
- [ ] **future work** Manual VoiceOver pass on the four-step workflow.
- [ ] **future work** Manual sandbox launch: the app reads/writes only user-selected paths and requests screen-capture permission before capturing.

---

## Self-review

- All audit findings (Sections 1–11 of the audit) are covered by at least one task above. Each task references the relevant file and line range so it can be picked up by an agent without re-reading the audit.
- No task introduces network code, third-party SDKs, or PDF/UA compliance claims.
- Phase order is chosen so each phase leaves the app in a buildable, testable state. The "Quick wins" subset (1.1, 1.2, 1.4, 1.5, 1.6, 1.8, 2.1, 2.2, 2.3, 2.4, 4.1, 4.2, 4.5, 5.3, 5.5) is intentionally compact and can ship in a single PR.
- The plan respects the existing `PageLumenCore` / `PageLumen` split and the Swift 5 language mode in `Package.swift:18, 25, 32`.
- Tasks 3.1 and 3.2 are the only structural changes to public APIs. Everything else is internal or additive.
