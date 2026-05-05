# Sightline Reader MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the PRD’s Phase 0/MVP native macOS app shell with local PDF/image import, OCR-oriented document structure, side-by-side review, summaries, speech playback, and Markdown/TXT/HTML/basic PDF export.

**Architecture:** Use a SwiftPM macOS GUI app with a reusable `SightlineCore` library for models and document processing. Keep SwiftUI focused on workflow composition while `DocumentProcessor`, `LayoutAnalyzer`, `ExplanationEngine`, `SpeechEngine`, and `ExportEngine` own testable behavior.

**Tech Stack:** Swift 6 toolchain in Swift 5 language mode, SwiftUI, AppKit, PDFKit, Vision, AVFoundation, XCTest, SwiftPM app-bundle run script.

---

## File Structure

- `Package.swift`: SwiftPM package with `SightlineCore`, `SightlineReader`, and `SightlineCoreTests`.
- `Sources/SightlineCore/Models.swift`: document, page, block, table, figure, outline, and export data models.
- `Sources/SightlineCore/LayoutAnalyzer.swift`: reading-order sorting, layout classification, heading/table/figure heuristics.
- `Sources/SightlineCore/ExplanationEngine.swift`: grounded table/chart explanations and audio-friendly summaries.
- `Sources/SightlineCore/ExportEngine.swift`: Markdown, TXT, semantic HTML, and basic accessible PDF export.
- `Sources/SightlineCore/DocumentProcessor.swift`: PDF/image loading, embedded PDF text extraction, Vision OCR fallback, page thumbnails.
- `Sources/SightlineCore/SampleData.swift`: demo document used on first launch and tests.
- `Tests/SightlineCoreTests/*`: focused tests for reading order, summaries, and exports.
- `Sources/SightlineReader/App/SightlineReaderApp.swift`: `@main` app and activation delegate.
- `Sources/SightlineReader/App/DocumentStore.swift`: main-window state and import/process/export actions.
- `Sources/SightlineReader/Views/*.swift`: sidebar, home, processing, review, summary, export, preview, and reusable UI.
- `Sources/SightlineReader/Support/SpeechEngine.swift`: AVFoundation text-to-speech wrapper.
- `script/build_and_run.sh`: Codex Run button build/launch entrypoint.
- `.codex/environments/environment.toml`: Codex app run action.

## Tasks

### Task 1: Package and Failing Tests

**Files:**
- Create: `Package.swift`
- Create: `Tests/SightlineCoreTests/LayoutAnalyzerTests.swift`
- Create: `Tests/SightlineCoreTests/ExportEngineTests.swift`
- Create: `Tests/SightlineCoreTests/ExplanationEngineTests.swift`

- [x] **Step 1: Create package manifest**

```swift
// Defines SightlineCore, SightlineReader, and SightlineCoreTests.
```

- [x] **Step 2: Write failing tests for reading order, summaries, and exports**

```swift
// Tests reference LayoutAnalyzer, ExplanationEngine, ExportEngine, and sample blocks.
```

- [x] **Step 3: Run tests to verify red**

Run: `swift test`
Expected: FAIL because core types do not exist yet.

### Task 2: Core Models and Services

**Files:**
- Create: `Sources/SightlineCore/Models.swift`
- Create: `Sources/SightlineCore/LayoutAnalyzer.swift`
- Create: `Sources/SightlineCore/ExplanationEngine.swift`
- Create: `Sources/SightlineCore/ExportEngine.swift`
- Create: `Sources/SightlineCore/SampleData.swift`

- [x] **Step 1: Implement minimal models**

```swift
// ReaderDocument, ReaderPage, TextBlock, TableRegion, FigureRegion, OutlineItem.
```

- [x] **Step 2: Implement layout heuristics**

```swift
// Classify layouts, sort single/two-column pages, infer headings/tables/figures.
```

- [x] **Step 3: Implement grounded explanations and summaries**

```swift
// Summaries use extracted text only and include page references.
```

- [x] **Step 4: Implement exports**

```swift
// Markdown, TXT, HTML, and basic text-based PDF.
```

- [x] **Step 5: Run tests to verify green**

Run: `swift test`
Expected: PASS.

### Task 3: Document Processing Pipeline

**Files:**
- Create: `Sources/SightlineCore/DocumentProcessor.swift`
- Modify: `Sources/SightlineCore/Models.swift`
- Add tests where pure behavior is exposed.

- [x] **Step 1: Implement import source detection**

```swift
// PDF, image, screenshot/clipboard labels, unsupported files.
```

- [x] **Step 2: Implement PDF page extraction**

```swift
// Prefer embedded PDF text, render pages for thumbnails and Vision OCR fallback.
```

- [x] **Step 3: Implement image OCR**

```swift
// Decode NSImage, run VNRecognizeTextRequest, store bounding boxes/confidence.
```

### Task 4: Native SwiftUI App

**Files:**
- Create: `Sources/SightlineReader/App/SightlineReaderApp.swift`
- Create: `Sources/SightlineReader/App/DocumentStore.swift`
- Create: `Sources/SightlineReader/Views/ContentView.swift`
- Create: `Sources/SightlineReader/Views/SidebarView.swift`
- Create: `Sources/SightlineReader/Views/HomeView.swift`
- Create: `Sources/SightlineReader/Views/ProcessingView.swift`
- Create: `Sources/SightlineReader/Views/ReviewView.swift`
- Create: `Sources/SightlineReader/Views/SummaryExportView.swift`
- Create: `Sources/SightlineReader/Views/PreviewPane.swift`
- Create: `Sources/SightlineReader/Support/SpeechEngine.swift`

- [x] **Step 1: Build native shell**

```swift
// NavigationSplitView sidebar with Home, Review, Summary & Export.
```

- [x] **Step 2: Add import routes**

```swift
// Open panel, drag/drop, paste clipboard image, sample document.
```

- [x] **Step 3: Add review and edit surface**

```swift
// Side-by-side original preview and editable structured extracted text.
```

- [x] **Step 4: Add summary, speech, and export controls**

```swift
// Length picker, playback controls, export format/options/save panel.
```

### Task 5: Build/Run Wiring and Verification

**Files:**
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

- [x] **Step 1: Add run script**

```bash
./script/build_and_run.sh --verify
```

- [x] **Step 2: Add Codex Run action**

```toml
command = "./script/build_and_run.sh"
```

- [x] **Step 3: Verify**

Run: `swift test`, `swift build`, `./script/build_and_run.sh --verify`
Expected: tests pass, build succeeds, app process launches.

## Self-Review

- P0 import covered: PDF, image, paste image, drag/drop; Share Sheet and recent files are represented as app shell affordances, not App Store extension packaging.
- P0 OCR covered: Vision OCR for images/rendered PDFs, embedded PDF text detection, page/block metadata, confidence.
- P0 structure covered: reading order, headings, simple table/figure heuristics, outline.
- P0 review covered: side-by-side preview and editable extracted text.
- P0 summary/audio covered: local summary generation and system speech playback.
- P0 exports covered: Markdown, TXT, HTML, basic accessible text PDF.
- Non-goals preserved: no enterprise management, no full PDF/UA compliance claim, no cloud model dependency.
