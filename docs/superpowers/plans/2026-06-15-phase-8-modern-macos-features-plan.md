# PageLumen Phase 8 — Modern macOS Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Replace `- [ ]` with `- [x] completed` (and add a short note) as each item is finished.

**Date:** 2026-06-15
**Status:** Open
**Source:** Follow-up to the 2026-06-15 audit plan (`docs/superpowers/plans/2026-06-15-audit-implementation-plan.md`). Built on the post-audit codebase (84/84 tests green as of 2026-06-15).
**Build environment:** macOS 26 SDK, Xcode 26.3, Swift 6.2.4. Deployment target: macOS 14.0.

**Goal:** Adopt the modern macOS frameworks that are free, on-device, and aligned with PageLumen's accessibility-first and local-first product mission: FoundationModels (Apple Intelligence), `VNRecognizeDocumentsRequest`, ScreenCaptureKit, Translation, `@Observable`, SwiftData, Personal Voice, TipKit, Swift Charts, `MenuBarExtra`, and Liquid Glass. Every new feature must be gated with `#available` so the deployment target stays at macOS 14.

**Architecture:** Each new feature is wrapped in a small adapter that conforms to an existing protocol or implements a well-defined interface, so the feature can be enabled/disabled via Settings, mocked in tests, and the fallback path is always exercised on unsupported Macs.

**Tech Stack:** Swift 6 toolchain in Swift 5 language mode, SwiftUI, AppKit, PDFKit, Vision (including `VNRecognizeDocumentsRequest`), AVFoundation (including Personal Voice), FoundationModels (macOS 26+), Translation (macOS 15+), ScreenCaptureKit (macOS 14+ / `SCScreenshotManager` macOS 26+), SwiftData (macOS 14+), TipKit (macOS 14+), Swift Charts (macOS 14+), SwiftUI `MenuBarExtra` (macOS 14+), XCTest, SwiftPM.

**Conventions for this plan:**
- Every file/line reference uses `path:line` so the agent can jump straight to the source.
- Items are ordered so each step leaves the app in a buildable, testable state.
- A feature is "completed" when: the change is implemented, `swift test` is green (84+ tests), `xcodebuild ... build` succeeds, and a new test exists for the feature or its fallback path.
- `#available(macOS X.Y, *)` is mandatory for every API introduced in macOS 15+ or macOS 26+. Nothing in this plan may raise the deployment target.
- Every new technology must remain **free** (no per-token or subscription cost from Apple) and **on-device** (no network call).

---

## Overview — what's new and why

| # | Tech | macOS | Impact | Free? | On-device? |
|---|---|---|---|---|---|
| 8.1 | FoundationModels (Apple Intelligence) | 26+ | High | Yes | Yes |
| 8.2 | `VNRecognizeDocumentsRequest` | 14+ | High | Yes | Yes |
| 8.3 | ScreenCaptureKit / `SCScreenshotManager` | 14+ / 26+ | High | Yes | Yes |
| 8.4 | Translation framework | 15+ | High | Yes | Yes |
| 8.5 | `@Observable` macro | 14+ | Medium | Yes | Yes |
| 8.6 | SwiftData (replaces `FilePersisting`) | 14+ | Medium | Yes | Yes |
| 8.7 | Personal Voice | 14+ | Medium | Yes | Yes |
| 8.8 | TipKit | 14+ | Medium | Yes | Yes |
| 8.9 | Swift Charts | 14+ | Low | Yes | Yes |
| 8.10 | `MenuBarExtra` | 14+ | Low | Yes | Yes |
| 8.11 | Liquid Glass materials | 26+ | Low | Yes | Yes |

All 11 are free (no per-use cost from Apple) and on-device. Six require only macOS 14 (already the deployment target). Five require macOS 15+ or macOS 26+ and are gated with `#available`.

---

## Deployment-target strategy

The deployment target **stays at macOS 14.0**. Every newer API is gated with `#available`. The only changes to `project.yml` and `Package.swift` are:
- Bump the SDK comment to mention macOS 26 features (informational only).
- Keep the existing `MARKETING_VERSION` bump on release.

If at any future date the maintainer chooses to raise the minimum to macOS 15 or macOS 16, the `#available` checks in this plan become unnecessary and can be removed. Until then, the plan's contract is: **the app runs on macOS 14 and is no worse than the post-audit baseline on any Mac**.

---

## Phase 8.1 — Apple Intelligence (FoundationModels)

> The single highest-impact change. Replaces the templated strings in `ExplanationEngine` with on-device prose grounded in extracted text. Maintains the PRD's safety rules: only use visible text, say when uncertain, no hallucination.

### 8.1.1 Add the `IntelligentExplainer` adapter
- [ ] Create `Sources/PageLumenCore/IntelligentExplainer.swift` with a `@available(macOS 26.0, *) public struct IntelligentExplainer` that:
  - Holds a `SystemLanguageModel.default` instance.
  - Exposes a synchronous `availability: IntelligentExplainer.Availability` enum (`.available`, `.unavailable(reason)`, `.notSupported`) so callers can choose without an `async` hop.
  - Implements `func summary(for: ReaderDocument, length: SummaryLength) async -> String` that calls the model with a carefully constrained prompt.
  - Implements `func explain(table: TableRegion) async -> String` and `func explain(figure: FigureRegion) async -> String`.
- [ ] Use `@Generable` macros where the output has a fixed shape (e.g. summary has `{ body: String, pageReferences: [Int] }`).

### 8.1.2 Wrap `ExplanationEngine.summary`
- [ ] Update `Sources/PageLumenCore/ExplanationEngine.swift:32-58` so callers can opt in to intelligent summaries. Add a new method `ExplanationEngine.summary(for:length:options:)` where `options` is a `SummaryOptions` struct with `useIntelligence: Bool` and `maxSentences: Int`. When `useIntelligence` is true, the engine delegates to `IntelligentExplainer` (when available) and otherwise returns the existing templated string.
- [ ] Update `Sources/PageLumen/App/DocumentStore.swift`'s `regenerateSummary()` to use the new entry point and to read the new "Use on-device AI for summaries" toggle from `UserDefaults`.

### 8.1.3 Wrap table and figure explanations
- [ ] Update `Sources/PageLumenCore/LayoutAnalyzer.swift:21-29` so the per-page table/figure explanation loop calls `IntelligentExplainer.explain(...)` when enabled. The existing `ExplanationEngine.explain(table:)` and `explain(figure:)` are kept as the fallback.

### 8.1.4 Settings toggle
- [ ] Add a new section in `Sources/PageLumen/Views/SettingsView.swift` titled "On-device AI" with:
  - A `Toggle` "Use Apple Intelligence for summaries and explanations" backed by `@AppStorage("useOnDeviceAI")`.
  - A read-only label that shows the current `IntelligentExplainer.Availability` (e.g. "Available on this Mac" / "Not supported on this Mac — using templated summaries").
  - A help text pointing at `docs/privacy.md` to reinforce that the AI is on-device.
- [ ] The toggle is `true` by default on Macs that report `IntelligentExplainer.Availability.available`; otherwise the default is `false`.

### 8.1.5 Tests
- [ ] Add `Tests/PageLumenCoreTests/IntelligentExplainerTests.swift` with:
  - `testAvailabilityIsNeverThrowing` — calls `IntelligentExplainer.availability` and asserts it returns a value (no crash, no exception).
  - `testAvailabilityOnUnsupportedOSReturnsNotSupported` — if running on macOS < 26, the availability is `.notSupported`. (In the CI runner this will be the case.)
  - `testSummaryFallsBackWhenIntelligenceDisabled` — calls `ExplanationEngine.summary(for:length:options:)` with `useIntelligence: false` and asserts the output matches the existing templated string.
  - `testSummaryFallsBackWhenIntelligenceUnavailable` — same as above but with `useIntelligence: true` on a Mac where the model is unavailable; the fallback path is exercised.
  - `testTableExplanationFallsBack` — same pattern for `explain(table:)`.
  - `testFigureExplanationFallsBack` — same pattern for `explain(figure:)`.
- [ ] Do NOT add tests that call the actual model (it is non-deterministic and slow). The test surface is the availability check and the fallback routing.

### 8.1.6 Verification
- [ ] `swift test` is green (84+ tests, +6 from 8.1.5).
- [ ] `xcodebuild ... build` succeeds on macOS 26.
- [ ] `xcodebuild ... build` succeeds on macOS 14 (the `#available` path is exercised).
- [ ] Manual: import a document, toggle "Use Apple Intelligence for summaries" off, confirm the summary is the existing templated version. Toggle on, confirm the summary reads like prose. Verify the explanation for a table reads like a sentence, not a template.
- [ ] Manual: open Settings on a non-Apple-Intelligence Mac; the toggle is disabled and the availability label reads "Not supported on this Mac".

---

## Phase 8.2 — Vision document recognition (`VNRecognizeDocumentsRequest`)

> Replaces the keyword-based heuristics in `LayoutAnalyzer` with a single Vision request that returns structured text blocks with bounding boxes, plus detected tables, lists, and reading order. Available since macOS 14, so no deployment-target change.

### 8.2.1 Add the structured-recognition path
- [ ] In `Sources/PageLumenCore/DocumentProcessor.swift`, add a new private method `recognizeStructured(in:pageNumber:pageSize:)` that uses `VNRecognizeDocumentsRequest` and maps its observations to `[TextBlock]` and `[TableRegion]`.
- [ ] The mapping should preserve `VNRectangleObservation` bounding boxes (Vision's normalized 0-1 coords) and convert to pixel coords using the `pageSize` argument.

### 8.2.2 Wire as the OCR fallback
- [ ] In `Sources/PageLumenCore/DocumentProcessor.swift:112-114` (the `processPDF` per-page OCR fallback), prefer `recognizeStructured` when the page has no embedded text. Fall back to the existing `recognizeText` (which uses `VNRecognizeTextRequest`) only if `VNRecognizeDocumentsRequest` fails or returns no results.
- [ ] In `Sources/PageLumenCore/DocumentProcessor.swift:170` (the image path), the same preference applies: try `recognizeStructured` first, then `recognizeText`.

### 8.2.3 Keep the existing path for already-tagged PDFs
- [ ] Do not call `recognizeStructured` for pages with embedded PDF text. The existing embedded-text path at `DocumentProcessor.swift:107-111` is preserved and faster.

### 8.2.4 Tests
- [ ] In `Tests/PageLumenCoreTests/DocumentProcessorTests.swift`, add `testImageOCRUsesStructuredRecognitionWhenAvailable` that runs the processor on a small generated fixture and asserts the resulting blocks have `metadata["source"] == "structured-recognition"` (or whatever convention you pick).
- [ ] Add a fallback test: when `VNRecognizeDocumentsRequest` is mocked to fail, the existing text-recognition path is used and the result still has blocks. (If mocking the request is too invasive, just add a test that exercises `recognizeText` directly with a non-document image to assert fallback works.)

### 8.2.5 Verification
- [ ] `swift test` is green.
- [ ] Manual: import a screenshot of a 2-column paper; confirm tables (if any) are detected with correct row counts and the blocks come out in reading order.
- [ ] Manual: import a flat image with no text; confirm the empty-state block ("No readable text was found on this page.") is shown.

---

## Phase 8.3 — ScreenCaptureKit / `SCScreenshotManager`

> Replaces the `screencapture` shell-out in `Sources/PageLumen/Support/ScreenshotCaptureService.swift` with the proper modern API. Two paths: `SCScreenshotManager` for one-shot capture (macOS 26+), `SCStream` for region selection (macOS 14+).

### 8.3.1 Add the `SCScreenshotManager` one-shot path
- [ ] In `Sources/PageLumen/Support/ScreenshotCaptureService.swift`, add a `@available(macOS 26.0, *)` method `captureWindow(_ windowID: CGWindowID) async throws -> URL` that uses `SCScreenshotManager.captureImage(contentRect:scale:)` to grab a specific window by its window ID. Write the resulting `CGImage` to a PNG in the temp directory.
- [ ] Add a `@available(macOS 26.0, *)` method `captureScreen() async throws -> URL` for full-screen capture.

### 8.3.2 Add the `SCStream` region-selection path
- [ ] Add a `@available(macOS 14.0, *)` method `selectAndCaptureRegion() async throws -> URL` that:
  1. Shows an `SCStream` with a transparent filter (no specific window, no display exclusion).
  2. Lets the user drag-select a region.
  3. Captures that region as a `CGImage` and writes it to a PNG.
- [ ] This is a non-trivial UI. If implementing a full region-selection UI is too much for one PR, document a deferred path: use `CGWindowListCreateImage` for the selected-window case and the legacy `screencapture` process for region selection, and ship a follow-up Phase 8.3.2b later.

### 8.3.3 Keep the legacy fallback
- [ ] The existing `Process`-based `/usr/sbin/screencapture` path remains as the macOS 13-or-earlier fallback (in practice unreachable since deployment target is 14, but the function is the default path when `#available` returns false).
- [ ] `Sources/PageLumen/Support/ScreenshotCaptureService.swift:32-53` becomes a small dispatch: pick the highest-available API.

### 8.3.4 Wire to `HomeView` buttons
- [ ] `Sources/PageLumen/Views/HomeView.swift:47-57` (the "Capture Screen" menu) — no change required because the buttons call `store.captureSelectedRegion()` and `store.captureWindow()`. The store in turn calls `ScreenshotCaptureService.capture(mode:)`. Confirm the dispatch works on both macOS 14 and macOS 26.

### 8.3.5 Permission prompt
- [ ] At app launch, call `CGRequestScreenCaptureAccess()` once if the app detects it has never been granted. (Already done at `ScreenshotCaptureService.swift:1-69` in the post-audit polish commit; verify it is still present.)

### 8.3.6 Tests
- [ ] Add `Tests/PageLumenCoreTests/ScreenshotCaptureServiceTests.swift` with:
  - `testCaptureThrowsWhenNotGranted` — mocks the permission state, asserts the legacy path throws `.commandFailed` or a new `.permissionDenied` case.
  - `testArgumentBuilderForWindow` — pure-function test that `arguments(for: .window, output: someURL)` returns `["-w", path]`.
  - `testArgumentBuilderForRegion` — same for `.selectedRegion`.

### 8.3.7 Verification
- [ ] `swift test` is green.
- [ ] Manual: on macOS 26, click "Capture Current Window" — the system permission prompt appears once, then a window picker UI shows, then the captured image is imported.
- [ ] Manual: on macOS 14, the legacy `screencapture` shell-out is used (still works).
- [ ] Manual: grant Screen Recording in System Settings > Privacy & Security > Screen Recording; confirm the capture works without a re-prompt.

---

## Phase 8.4 — Translation framework

> Adds "Translate this page" and "Translate entire document" features. On-device, free, private. Available since macOS 15.

### 8.4.1 Create `TranslationService`
- [ ] Create `Sources/PageLumen/Support/TranslationService.swift` with:
  ```swift
  @MainActor
  public final class TranslationService {
      public init() {}
      public func translate(_ text: String, to target: Locale.Language) async throws -> String
      public func translate(document: ReaderDocument, to target: Locale.Language) async throws -> ReaderDocument
  }
  ```
- [ ] The `translate(_:to:)` method uses `TranslationSession` (macOS 15+) and falls back to identity (returns the input) on older systems.
- [ ] The `translate(document:to:)` method translates each block's text in order, builds a new `ReaderDocument` with the translated strings, and stamps a `metadata["translatedFrom"]` and `metadata["translationTargetLanguage"]` on each translated block. Tables and figures keep their structure; only text changes.

### 8.4.2 Add a new export format
- [ ] In `Sources/PageLumenCore/ExportEngine.swift:4-27`, add `case translated = "Translated"` with `fileExtension: "md"`.
- [ ] The `ExportEngine.data(for:format:options:)` switch returns a placeholder; the actual translation is invoked in `DocumentStore.export(format:)` via `TranslationService`.
- [ ] In `Sources/PageLumen/App/DocumentStore.swift:425-440` (`export(format:)`), add the `.translated` case that:
  1. Reads the target language from `UserDefaults` key `"translationTargetLanguage"`.
  2. Calls `TranslationService.translate(document:to:)`.
  3. Exports the translated document as Markdown via the existing `ExportEngine.markdown(...)`.

### 8.4.3 Add a Settings entry
- [ ] In `Sources/PageLumen/Views/SettingsView.swift`, add a new section "Translation" with:
  - A `Picker` for target language (English, Spanish, French, Hindi, German, Japanese, Chinese Simplified).
  - A help text: "On-device translation, private and free. Requires macOS 15+."
  - The picker is disabled on macOS < 15 with a "Requires macOS 15 or later" label.

### 8.4.4 Add a "Translate" action in `SummaryExportView`
- [ ] In `Sources/PageLumen/Views/SummaryExportView.swift:120-138` (the export format grid), add a "Translate & Export" button that triggers the new `.translated` format.

### 8.4.5 Tests
- [ ] Add `Tests/PageLumenCoreTests/TranslationServiceTests.swift` with:
  - `testTranslateReturnsInputOnUnsupportedOS` — on macOS < 15, `translate(_:to:)` returns the input string unchanged.
  - `testTranslateDocumentPreservesBlockCount` — on any macOS, calling `translate(document:to:)` on a 3-block document returns a 3-block document (even if text is unchanged due to fallback).
  - `testTranslateStampsMetadataOnTranslatedBlocks` — when translation succeeds (skipped in tests), each translated block has `metadata["translationTargetLanguage"]` set.
- [ ] Do NOT add tests that actually translate text (non-deterministic and slow on CI).

### 8.4.6 Verification
- [ ] `swift test` is green (84+ tests, +3 from 8.4.5).
- [ ] Manual: on macOS 15+, translate a Spanish-language PDF to English; confirm the exported `.md` file contains English text.
- [ ] Manual: on macOS 14, the Settings picker is disabled with the appropriate label; "Translate & Export" still produces a file (with untranslated text) instead of failing.

---

## Phase 8.5 — `@Observable` macro

> Replaces `ObservableObject` + `@Published` with the new observation system. Cleaner code, less boilerplate, better performance. Available since macOS 14.

### 8.5.1 Convert `DocumentStore`
- [ ] In `Sources/PageLumen/App/DocumentStore.swift`:
  - Add `@Observable` to the class declaration (above `@MainActor`).
  - Remove every `@Published` keyword from the properties.
  - The class no longer conforms to `ObservableObject`.

### 8.5.2 Update views
- [ ] In every file under `Sources/PageLumen/Views/` and `Sources/PageLumen/Support/` that uses `@EnvironmentObject private var store: DocumentStore`:
  - Replace with `@Environment(DocumentStore.self) private var store`.
  - Anywhere the view uses `$store.someProperty` for a binding, switch to `@Bindable var store = store` inside `body` and then use `$store.someProperty` (or use a `Binding` derived from the property).
  - In `Sources/PageLumen/App/PageLumenApp.swift:15` and `:49`, change `.environmentObject(store)` to `.environment(store)`.
  - In `Sources/PageLumen/Support/StatusBadge.swift` and any other files that pass `DocumentStore` via `@EnvironmentObject`, apply the same change.

### 8.5.3 Update tests
- [ ] In `Tests/PageLumenTests/DocumentStoreTests.swift`:
  - The `InMemoryPersisting` test double still works.
  - Where the test uses `store.document = ...` directly, no change (you can write to `@Observable` properties the same way).
  - Where the test reads `store.$document` (a `Published.Publisher`), update to a `withObservationTracking { store.document }` pattern OR drop the publisher-based assertions and use direct reads.
  - The `testSearchIndexInvalidatesOnDocumentChange` and `testExportPreviewTextCachesForSameInputs` tests need re-validation.

### 8.5.4 Tests
- [ ] After the migration, all 84+ existing tests pass. No new tests required for `@Observable` itself (it's a compiler feature).

### 8.5.5 Verification
- [ ] `swift test` is green (84+ tests).
- [ ] `xcodebuild ... build` succeeds.
- [ ] Manual: every interaction that previously re-rendered the view (typing in a block, selecting a page, toggling a setting) still re-renders correctly. The new observation system is more granular so re-renders should actually be *fewer*, not more.

---

## Phase 8.6 — SwiftData (replaces `FilePersisting`)

> Replaces the JSON-file persistence in `Sources/PageLumenCore/FilePersisting.swift` with SwiftData. Better for >100 recents, supports queries on title and date. Available since macOS 14.

### 8.6.1 Define the `@Model`
- [ ] Create `Sources/PageLumenCore/PersistedDocument.swift` with:
  ```swift
  @available(macOS 14.0, *)
  @Model
  public final class PersistedDocument {
      @Attribute(.unique) public var id: UUID
      public var title: String
      public var createdAt: Date
      public var lastOpened: Date
      public var pageCount: Int
      public var sourceType: String
      public var jsonData: Data  // serialized ReaderDocument

      public init(id: UUID, title: String, createdAt: Date, lastOpened: Date, pageCount: Int, sourceType: String, jsonData: Data) {
          self.id = id
          self.title = title
          self.createdAt = createdAt
          self.lastOpened = lastOpened
          self.pageCount = pageCount
          self.sourceType = sourceType
          self.jsonData = jsonData
      }
  }
  ```

### 8.6.2 Implement `SwiftDataPersisting`
- [ ] Create `Sources/PageLumenCore/SwiftDataPersisting.swift` with a `public final class SwiftDataPersisting: DocumentPersisting` that uses a `ModelContainer` configured for the app's Application Support directory. Implements `save`, `load(id:)`, `recentDocuments()` (sorted by `lastOpened` desc, limit 50), and `forgetAll`.

### 8.6.3 Switch the default in `DocumentStore`
- [ ] In `Sources/PageLumen/App/DocumentStore.swift`, change the default `persisting` from `FilePersisting()` to `SwiftDataPersisting()`. The `FilePersisting` implementation stays in the codebase (used by the existing `FilePersistingTests` and as a test double) but is no longer the production default.
- [ ] Add a one-time migration: on first launch, if `Application Support/PageLumen/Library/recent.json` exists, import its contents into the SwiftData store and delete the file.

### 8.6.4 Tests
- [ ] Add `Tests/PageLumenCoreTests/SwiftDataPersistingTests.swift` (mirror of `DocumentPersistingTests.swift`):
  - `testSaveAndLoadRoundTrips` — saves 2 documents, loads them, asserts title and lastOpened.
  - `testRecentDocumentsSortedByLastOpened` — saves 3 documents with different `lastOpened`, asserts the order.
  - `testForgetAllEmptiesTheStore` — saves 2, forgets, asserts empty.
- [ ] The existing `FilePersistingTests` continue to pass (the implementation is unchanged).

### 8.6.5 Verification
- [ ] `swift test` is green (84+ tests, +3 from 8.6.4).
- [ ] Manual: import 5 documents, close the app, relaunch — all 5 appear in the "Library" section.
- [ ] Manual: click "Forget all" — the library is empty and the JSON file is gone.

---

## Phase 8.7 — Personal Voice

> One-line change in `SpeechEngine` that lets the app speak summaries in the user's own enrolled Personal Voice. Big accessibility win for users with speech impairments who can read but not speak. Available since macOS 14.

### 8.7.1 Update `SpeechEngine`
- [ ] In `Sources/PageLumen/Support/SpeechEngine.swift:17-19` (the `speak(_:)` method), before constructing the utterance, look up the user's Personal Voice:
  ```swift
  let personalVoice = AVSpeechSynthesisVoice.personalVoice()
  let voice = personalVoice ?? AVSpeechSynthesisVoice(language: "en-US")
  utterance.voice = voice
  ```
- [ ] Add a Settings toggle "Use Personal Voice if available" (default on) backed by `@AppStorage("usePersonalVoice")`. When the toggle is off, use the default voice.

### 8.7.2 Voice selection UI (optional)
- [ ] In `Sources/PageLumen/Views/SettingsView.swift`, add a "Voice" section that:
  - Lists `AVSpeechSynthesisVoice.speechVoices()` filtered to English.
  - Lets the user pick a system voice.
  - Shows "Personal Voice" as the first option when `AVSpeechSynthesisVoice.personalVoice()` is non-nil.
  - The picker state is stored in `UserDefaults` key `"speechVoiceIdentifier"`.

### 8.7.3 Tests
- [ ] `SpeechEngineTests` (or extend an existing test file) with:
  - `testSpeakUsesDefaultVoiceWhenPersonalVoiceDisabled` — set `@AppStorage("usePersonalVoice") = false`, call `speak`, assert the utterance's `voice.identifier` is the default (e.g. `"com.apple.voice.compact.en-US.Samantha"`).
  - `testSpeakUsesPersonalVoiceWhenAvailable` — if `AVSpeechSynthesisVoice.personalVoice()` is non-nil, the utterance uses it.

### 8.7.4 Verification
- [ ] `swift test` is green.
- [ ] Manual: open System Settings > Accessibility > Personal Voice (macOS 14+) and record a voice. Then in PageLumen, click "Play" on a summary — the voice is the user's own.
- [ ] Manual: on a Mac without Personal Voice enrolled, the app falls back to the default voice silently (no warning, no error).

---

## Phase 8.8 — TipKit

> Contextual first-use hints. Available since macOS 14. No cost, no network, very small code surface.

### 8.8.1 Define the tips
- [ ] Create `Sources/PageLumen/Support/PageLumenTips.swift` with:
  - `DropZoneTip` — "Drop a PDF, image, or screenshot" with a `doc.viewfinder` icon.
  - `ReviewIssueTip` — "Press ⌘⇧R to jump to the first review issue" with a `scope` icon.
  - `ExportAccessibilityTip` — "Tagged HTML and the Accessibility Report are the review-ready exports" with a `checkmark.seal` icon.
  - `BoostContrastTip` — "If text is hard to read, try Boost Contrast in Settings" with a `circle.lefthalf.filled` icon.

### 8.8.2 Wire tips to views
- [ ] `Sources/PageLumen/Views/HomeView.swift` — show `DropZoneTip` once on the drop-zone panel (use `.popoverTip` or `.tipViewStyle`).
- [ ] `Sources/PageLumen/Views/ReviewView.swift` — show `ReviewIssueTip` on the "Review Issues" button.
- [ ] `Sources/PageLumen/Views/SummaryExportView.swift` — show `ExportAccessibilityTip` above the export format grid.
- [ ] `Sources/PageLumen/Views/SettingsView.swift` — show `BoostContrastTip` on the Display section (only when the user has toggled the contrast setting at least once).

### 8.8.3 Configure the tips container
- [ ] In `Sources/PageLumen/App/PageLumenApp.swift`, register a `TipsConfiguration`:
  ```swift
  .task {
      try? Tips.configure([.displayFrequency(.immediate)])
  }
  ```

### 8.8.4 Tests
- [ ] `PageLumenTipsTests` (a small test that asserts each tip has a non-empty title, message, and image). TipKit is testable via `Tips.Testing`.

### 8.8.5 Verification
- [ ] `swift test` is green.
- [ ] Manual: first launch of the app shows the drop-zone tip. After dismissing it once, it does not reappear.

---

## Phase 8.9 — Swift Charts

> Visualize OCR confidence and per-page metrics. Available since macOS 14. Low priority because the trust bar already shows aggregate metrics, but adds polish.

### 8.9.1 Create `ConfidenceChartView`
- [ ] Create `Sources/PageLumen/Views/ConfidenceChartView.swift` that:
  - Takes a `ReaderDocument` and renders a `BarMark` chart of `(pageNumber, averageConfidence)` for every page.
  - Uses `AccessibleStyle.warning` for bars below 0.7 confidence and `AccessibleStyle.success` for bars at or above.
  - Includes a "low-confidence" overlay (horizontal dashed line at 0.7).
  - Has a `.accessibilityLabel("Per-page OCR confidence chart")` and `.accessibilityChartDescriptor(...)` for VoiceOver.

### 8.9.2 Wire to `ReviewView`
- [ ] In `Sources/PageLumen/Views/ReviewView.swift`, add a "Confidence" button next to "Show order" that opens a `.popover` with `ConfidenceChartView(document: store.document)`.

### 8.9.3 Tests
- [ ] `ConfidenceChartViewTests` (or extend an existing test file) with:
  - `testChartHighlightsLowConfidencePages` — creates a document with 3 pages (high, low, high), asserts the chart's data points are marked correctly.
  - `testChartHasAccessibilityChartDescriptor` — asserts the view has an accessibility chart descriptor.

### 8.9.4 Verification
- [ ] `swift test` is green.
- [ ] Manual: open the review view, click "Confidence", confirm the chart renders and is VoiceOver-navigable.

---

## Phase 8.10 — `MenuBarExtra`

> Quick access from the menu bar to capture, recents, and listen. Available since macOS 14. Adds a small persistent affordance for repeat users.

### 8.10.1 Add a new scene
- [ ] In `Sources/PageLumen/App/PageLumenApp.swift`, add a `MenuBarExtra("PageLumen", systemImage: "doc.text.magnifyingglass")` scene:
  ```swift
  MenuBarExtra("PageLumen", systemImage: "doc.text.magnifyingglass") {
      Button("Capture Selected Region") { store.captureSelectedRegion() }
      Button("Capture Window") { store.captureWindow() }
      Divider()
      Button("Play Summary") { store.playCurrentSummary() }  // new method on DocumentStore
      Button("Read Full Text") { store.readCurrentFullText() }  // new method
      Divider()
      ForEach(store.recentDocuments.prefix(5)) { document in
          Button(document.title) { store.selectRecentDocument(document) }
      }
      Divider()
      Button("Open PageLumen Window") { NSApp.activate(ignoringOtherApps: true) }
  }
  ```

### 8.10.2 Add helper methods on `DocumentStore`
- [ ] `playCurrentSummary()` and `readCurrentFullText()` reuse the existing `SpeechEngine` (held by `SummaryExportView`). Either lift `SpeechEngine` to `DocumentStore` (so the menu bar can drive it) or pass a `Notification.Name` to the existing view-owned `SpeechEngine` (cleaner separation).

### 8.10.3 Tests
- [ ] No new tests required. The behavior is exercised end-to-end via the existing `DocumentStoreTests`.

### 8.10.4 Verification
- [ ] Manual: the menu bar shows a PageLumen icon. Click "Capture Selected Region" — the same flow as the Home view button. Click "Play Summary" — the summary is read aloud.

---

## Phase 8.11 — Liquid Glass materials (macOS 26)

> The new design language in macOS 26. Adds translucent materials. Important to gate on accessibility settings.

### 8.11.1 Use Liquid Glass selectively
- [ ] In `Sources/PageLumen/Support/AccessibleStyle.swift`, add a helper:
  ```swift
  @available(macOS 26.0, *)
  static var primaryPanel: some ShapeStyle {
      get { AnyShapeStyle(.glass) }  // placeholder — actual API is `Material.glass` or similar
  }
  ```
  The actual API in macOS 26 for Liquid Glass may be `Material.glass` or a new `ShapeStyle.glass`. Look up the SDK at implementation time and use the correct name.
- [ ] In `Sources/PageLumen/Views/SidebarView.swift`, `Sources/PageLumen/Views/HomeView.swift`, and `Sources/PageLumen/Views/ReviewView.swift`, swap the existing `AccessibleStyle.panelBackground` for the new glass material on macOS 26.

### 8.11.2 Gate on accessibility settings
- [ ] The new materials are only applied when:
  - `AccessibleStyle.boostContrast == false` (the boost-contrast toggle is off), AND
  - `@Environment(\.accessibilityReduceTransparency) == false`.
- [ ] When either is true, fall back to the existing `AccessibleStyle.panelBackground`.

### 8.11.3 Tests
- [ ] No automated tests (visual changes). Manual review only.

### 8.11.4 Verification
- [ ] Manual: on macOS 26, the app has a subtle translucent look. On macOS 14-15, the existing solid backgrounds remain. Toggling Boost Contrast or Reduce Transparency on macOS 26 reverts to solid.

---

## Cross-cutting considerations

### Privacy
Every technology in this plan is **on-device**. No new network calls, no telemetry, no third-party services. The settings toggles in `docs/privacy.md` are updated as new features are added.

### Accessibility
- **VoiceOver**: every new view has explicit `.accessibilityLabel` / `.accessibilityValue` / `.accessibilityChartDescriptor` modifiers.
- **Reduce Motion / Reduce Transparency**: gated on `@Environment(\.accessibilityReduceMotion)` and `accessibilityReduceTransparency`. (Phase 4.4 work from the audit plan is upstream; this plan preserves it.)
- **Boost Contrast**: `AccessibleStyle.boostContrast` is checked in every new view.
- **Personal Voice**: Phase 8.7 specifically supports users with speech impairments.

### Performance
- FoundationModels is fast on M1+; the call is `await`-ed so the UI does not block.
- `VNRecognizeDocumentsRequest` is roughly the same speed as `VNRecognizeTextRequest`. Phase 8.2 does not regress performance.
- SwiftData is faster than JSON-file I/O for >10 recents.
- `@Observable` reduces re-renders (only views that read a changed property re-render).

### Testing strategy
- New tests: at least one test per phase that asserts the **fallback path** is exercised on unsupported macOS. This is the key contract: the app must work on macOS 14, and any macOS 14-15-26 feature must be optional.
- New tests: a test per feature that asserts the **happy path** is reachable when the feature is available.
- No tests that call non-deterministic APIs (FoundationModels inference, Translation, Speech synthesis).

### Documentation
- Each phase updates `docs/architecture.md` with the new module/dependency.
- Each phase updates `CHANGELOG.md` under `Unreleased > Added`.
- Each phase updates `docs/privacy.md` if the feature has any privacy implications (it shouldn't — everything is on-device — but the doc is the contract).
- After all 11 phases land, mark this plan's checkboxes accordingly.

---

## Final verification (run before declaring the plan complete)

- [ ] `swift test` is green (84+ tests, expected 100+ after all phases).
- [ ] `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Debug -destination 'generic/platform=macOS' build` succeeds.
- [ ] `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Release -destination 'generic/platform=macOS' archive -archivePath dist/PageLumen.xcarchive` succeeds.
- [ ] `script/validate_release.sh dist/PageLumen.xcarchive/Products/Applications/PageLumen.app` passes.
- [ ] On macOS 26: Apple Intelligence summaries, SCScreenshotManager capture, Liquid Glass, all work.
- [ ] On macOS 15-16: Translation, all macOS 14 features, all work.
- [ ] On macOS 14: every feature is present in the UI but disabled / fallback where required. The app does not crash on a missing `#available` API.
- [ ] `CHANGELOG.md` is updated with all `Unreleased > Added` entries.
- [ ] `docs/architecture.md` reflects the new modules.
- [ ] `docs/privacy.md` is unchanged (everything is on-device, no new privacy claims needed).
- [ ] This plan is updated to mark every phase complete.

---

## Self-review

- All 11 modern macOS technologies are addressed in dedicated phases.
- No paid services or third-party SDKs are introduced. Every new dependency is an Apple system framework that ships with the OS.
- No network calls are introduced. Every new feature is on-device, preserving the "local-first" promise in `README.md:69` and `pagelumen_prd.md:660-666`.
- The deployment target stays at macOS 14.0. All newer APIs are gated with `#available`.
- Every new feature has a documented fallback path for older macOS, and at least one test exercises that fallback.
- Accessibility is preserved or improved in every phase (VoiceOver labels, reduce-motion, reduce-transparency, boost-contrast, Personal Voice).
- Performance is not regressed: `VNRecognizeDocumentsRequest` is the same speed as `VNRecognizeTextRequest`; SwiftData is faster than JSON for the recents list; `@Observable` reduces re-renders.
- The plan is ordered so each phase leaves the app in a buildable, testable state. Phases 8.1-8.4 are the highest-impact and can ship first. Phases 8.5-8.11 are polish and can ship in any order or be deferred.
- Tests for new behavior are added in every phase. Final test count should be ≥ 100.
