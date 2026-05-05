# PRD Completion Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the remaining practical PRD capabilities in the native MVP: screenshot capture entrypoints, richer review controls, header/footer handling, full-text speech, CSV/JSON exports, and visible capability coverage.

**Architecture:** Keep deterministic behavior in `SightlineCore` with tests for layout/export/document mutations. Add macOS-specific screenshot capture and audio/export controls in the app target while preserving the current single-document review model and batch queue.

**Tech Stack:** SwiftPM, XCTest, SwiftUI, AppKit, AVFoundation, PDFKit/Vision, macOS `screencapture` command integration.

---

## File Structure

- Create `Sources/SightlineCore/DocumentEditing.swift`: pure helpers for block reordering, header/footer filtering, and document text assembly.
- Create `Tests/SightlineCoreTests/DocumentEditingTests.swift`: tests for manual reorder, header/footer exclusion, and full text assembly.
- Modify `Sources/SightlineCore/LayoutAnalyzer.swift`: mark repeated top/bottom text as header/footer across multi-page documents.
- Modify `Sources/SightlineCore/ExportEngine.swift`: add CSV and JSON export support plus header/footer exclusion option.
- Modify `Sources/SightlineCore/Models.swift`: extend export options/formats and add OCR profile/language metadata where useful.
- Create `Tests/SightlineCoreTests/AdvancedExportTests.swift`: tests for CSV and JSON export.
- Create `Sources/SightlineReader/Support/ScreenshotCaptureService.swift`: selected-region/current-window capture using macOS `screencapture`, then import captured PNGs.
- Modify `Sources/SightlineReader/App/DocumentStore.swift`: expose capture actions, block move actions, full-text speech text, export options.
- Modify `Sources/SightlineReader/Views/HomeView.swift`: add screenshot capture buttons.
- Modify `Sources/SightlineReader/Views/ReviewView.swift`: add move up/down controls for reading order and header/footer indicators.
- Modify `Sources/SightlineReader/Views/SummaryExportView.swift`: add “Read full text” playback and CSV/JSON export buttons.
- Modify `Sources/SightlineReader/Views/SettingsView.swift`: add privacy/OCR profile/language settings and capability coverage note.

## Tasks

### Task 1: Document Editing Core

**Files:**
- Create: `Tests/SightlineCoreTests/DocumentEditingTests.swift`
- Create: `Sources/SightlineCore/DocumentEditing.swift`
- Modify: `Sources/SightlineCore/LayoutAnalyzer.swift`

- [ ] **Step 1: Write failing tests for reorder and header/footer filtering**
- [ ] **Step 2: Run `swift test --filter DocumentEditingTests` and verify red**
- [ ] **Step 3: Implement `DocumentEditing` helpers and repeated header/footer marking**
- [ ] **Step 4: Run `swift test --filter DocumentEditingTests` and verify green**

### Task 2: Advanced Exports

**Files:**
- Create: `Tests/SightlineCoreTests/AdvancedExportTests.swift`
- Modify: `Sources/SightlineCore/Models.swift`
- Modify: `Sources/SightlineCore/ExportEngine.swift`

- [ ] **Step 1: Write failing CSV/JSON export tests**
- [ ] **Step 2: Run `swift test --filter AdvancedExportTests` and verify red**
- [ ] **Step 3: Add CSV and JSON export formats**
- [ ] **Step 4: Run `swift test --filter AdvancedExportTests` and verify green**

### Task 3: macOS UI Integration

**Files:**
- Create: `Sources/SightlineReader/Support/ScreenshotCaptureService.swift`
- Modify: `Sources/SightlineReader/App/DocumentStore.swift`
- Modify: `Sources/SightlineReader/Views/HomeView.swift`
- Modify: `Sources/SightlineReader/Views/ReviewView.swift`
- Modify: `Sources/SightlineReader/Views/SummaryExportView.swift`
- Modify: `Sources/SightlineReader/Views/SettingsView.swift`

- [ ] **Step 1: Add capture selected-region/current-window actions**
- [ ] **Step 2: Add block move controls and header/footer labels**
- [ ] **Step 3: Add full extracted text speech and CSV/JSON export buttons**
- [ ] **Step 4: Add settings for privacy, OCR profile, language hint, and capability coverage**

### Task 4: Verification and Commit

**Files:**
- No new files.

- [ ] **Step 1: Run `swift test`**
- [ ] **Step 2: Run `swift build --product SightlineReader`**
- [ ] **Step 3: Run `./script/build_and_run.sh --verify`**
- [ ] **Step 4: Commit and push branch**

## Self-Review

- Covered from PRD: capture selected region/current window, recent/batch import, confidence display, editable OCR text, manual reading order, repeated header/footer handling, summaries, read full text, CSV/JSON exports, export settings, privacy/profile settings.
- Left as capability notes rather than fake implementation: true browser extension, scanner import, trained domain layout models, full PDF/UA validation, EPUB/LMS/Notion/Readwise integrations, advanced chart data extraction, enterprise admin controls.
- The plan keeps generated/heuristic content labeled and local-first behavior visible.
