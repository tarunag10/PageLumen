# PageLumen Architecture

This document describes how the PageLumen macOS app is put together. It is a companion to the audit implementation plan (`docs/superpowers/plans/2026-06-15-audit-implementation-plan.md`) and the product PRD (`pagelumen_prd.md`).

## Overview

PageLumen is a local-first macOS app that turns PDFs, images, screenshots, and clipboard captures into structured, editable, exportable text. Every stage of the pipeline is reachable from a SwiftUI screen and every behaviour that does not need a window is implemented in a framework that XCTest can cover without booting a UI.

## Module Split

The project is two SwiftPM / Xcode targets (`project.yml:13-52`):

- **`PageLumenCore`** is a framework that holds pure types and services. It owns the document model (`Models.swift`), the import pipeline (`DocumentProcessor`), the layout heuristics (`LayoutAnalyzer`), the editing helpers (`DocumentEditing`), the export engine (`ExportEngine`), the explanation engine (`ExplanationEngine`), and the batch import queue (`BatchImportQueue`). Nothing in `PageLumenCore` imports `SwiftUI` or `AppKit` for behaviour code (AppKit is only used for PDFKit-driven rendering and as a thin `NSImage` bridge). Everything in this target is testable from `Tests/PageLumenCoreTests`.
- **`PageLumen`** is the SwiftUI shell plus the AppKit glue. It owns the `@main` app entry, `DocumentStore` (the single `@MainActor` source of truth), the speech engine wrapper, the screenshot capture service, and every view (`HomeView`, `ProcessingView`, `ReviewView`, `SummaryExportView`, `SettingsView`, `SidebarView`, `PreviewPane`, `ContentView`). The shell depends on `PageLumenCore` for all processing.

The split keeps the engine free of UI dependencies, which is the only way to make a screen-reader-first app both honest (no mocked accessibility claims) and testable (no flaky UI tests in CI).

## Import Pipeline

```
URL  ─▶  DocumentProcessor  ─▶  LayoutAnalyzer  ─▶  ReaderDocument
             │                       │                     │
             │   Vision OCR /        │   reading-order,     │   used by Review,
             │   embedded PDF text   │   headings, tables   │   Summary, Export
             │                       │   figures            │
```

1. **Source detection** — `DocumentProcessor.process(url:onProgress:)` decides whether the input is a PDF, an image, a screenshot, or a clipboard paste (`DocumentProcessor.swift:50-56`).
2. **PDF page extraction** — for PDFs, embedded text is preferred; pages are rendered with PDFKit for thumbnails and to feed the Vision OCR fallback when text is missing.
3. **Image OCR** — `VNRecognizeTextRequest` extracts text and confidence; Vision's language detection drives the OCR profile chosen in Settings.
4. **Layout analysis** — `LayoutAnalyzer.orderedBlocks` sorts blocks into reading order, classifies single / multi-column / slide / form / mixed layouts, and surfaces headings, tables, and figures.
5. **Document assembly** — the result is a `ReaderDocument` whose pages expose `blocks`, `tables`, `figures`, and an `outline`.

## Review Pipeline

- **`DocumentEditing`** provides pure helpers for block reordering, header / footer filtering, and full-text assembly. The store calls into these helpers from `MainActor`-isolated methods.
- **`ReadingOrderOverlay`** is a SwiftUI overlay that draws the ordered blocks on top of the page preview and exposes accessibility labels and values for VoiceOver.
- **Editable block rows** render each block with a `TextEditor`, a `StatusBadge`, and per-block move / retype / mark-reviewed actions. Edits are debounced before they reach the store.

## Export Pipeline

- **`ExportEngine`** owns the format switch. It supports Markdown, TXT, HTML, tagged HTML, accessible PDF, CSV, JSON, and an Accessibility Report.
- **`AccessibilityAuditor`** runs against a `ReaderDocument` and produces a list of `AccessibilityFinding`s (missing language, missing headings, low-confidence text, missing figure description, etc.) that surface in the Summary view and in the Accessibility Report export.
- **`ExportSanitizer`** is a small opt-in layer (Settings → "Save export anonymously") that strips `sourceURL` from JSON output and truncates OCR text snippets in the audit so private material does not leak through an export.

## Concurrency Model

- The `Models.swift` types are `Sendable` and `Codable`. They cross actor boundaries freely.
- `DocumentStore` is `@MainActor`. All `@Published` mutation happens on the main actor; the `importURLs` / `pasteImageFromClipboard` entry points wrap their progress callbacks in an explicit `Task { @MainActor in ... }` to make the hop visible to future readers.
- Long-running processing (PDF page rendering, Vision OCR) happens off the main actor inside `DocumentProcessor` and is cancellable. Per-page OCR is a candidate for a `TaskGroup` fan-out with a `max(1, activeProcessorCount / 2)` concurrency cap (see Phase 2.6 of the audit plan).
- The shell and the framework share no mutable state besides the value-type snapshots that flow through `DocumentStore`.

## Adding a New Export Format

Five-line recipe:

1. Add a `case` to `ExportFormat` (`ExportEngine.swift:4-27`) and update `fileExtension`.
2. Add a writer method on `ExportEngine` (e.g. `markdownData`, `pdfData`).
3. Add the new case to the `ExportEngine.data` switch.
4. Surface the format in `SummaryExportView`'s format picker and Save Panel file type list.
5. Add a snapshot test under `Tests/PageLumenCoreTests/` that locks down the output for a fixture `ReaderDocument`.
