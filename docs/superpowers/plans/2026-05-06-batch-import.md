# Batch Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the PRD P1 feature “Batch import multiple PDFs or images” so users can open or drop several supported files, watch queue progress, and select processed documents for review/export.

**Architecture:** Add a small testable queue model in `SightlineCore`, then use it from `DocumentStore` to process URLs sequentially with per-item status. Keep the app single-document review focused by making the selected batch item set the active `ReaderDocument`.

**Tech Stack:** SwiftPM, XCTest, SwiftUI, AppKit `NSOpenPanel`, Swift concurrency, existing `DocumentProcessor`.

---

## File Structure

- Create `Sources/SightlineCore/BatchImportQueue.swift`: pure queue/status model for pending, processing, completed, and failed batch items.
- Create `Tests/SightlineCoreTests/BatchImportQueueTests.swift`: red/green tests for enqueueing, starting, completing, failing, and supported extensions.
- Modify `Sources/SightlineReader/App/DocumentStore.swift`: allow multi-select import, process batches sequentially, expose queue to sidebar/home.
- Modify `Sources/SightlineReader/Views/HomeView.swift`: update drop zone copy and handle multiple dropped file URLs.
- Modify `Sources/SightlineReader/Views/SidebarView.swift`: add batch queue section with status and document selection.
- Modify `Sources/SightlineReader/Views/ContentView.swift` and `Sources/SightlineReader/App/SightlineReaderApp.swift`: rename open actions to batch-aware labels.

## Tasks

### Task 1: Queue Model

**Files:**
- Create: `Tests/SightlineCoreTests/BatchImportQueueTests.swift`
- Create: `Sources/SightlineCore/BatchImportQueue.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testEnqueueCreatesPendingItemsForSupportedURLs()
func testQueueTransitionsThroughProcessingCompleteAndFailed()
```

- [ ] **Step 2: Run red test**

Run: `swift test --filter BatchImportQueueTests`
Expected: FAIL because `BatchImportQueue` is not defined.

- [ ] **Step 3: Implement queue model**

```swift
public struct BatchImportQueue { ... }
public struct BatchImportItem: Identifiable, Equatable, Sendable { ... }
public enum BatchImportItemStatus: Equatable, Sendable { ... }
```

- [ ] **Step 4: Run green test**

Run: `swift test --filter BatchImportQueueTests`
Expected: PASS.

### Task 2: App Integration

**Files:**
- Modify: `Sources/SightlineReader/App/DocumentStore.swift`
- Modify: `Sources/SightlineReader/Views/HomeView.swift`
- Modify: `Sources/SightlineReader/Views/SidebarView.swift`
- Modify: `Sources/SightlineReader/Views/ContentView.swift`
- Modify: `Sources/SightlineReader/App/SightlineReaderApp.swift`

- [ ] **Step 1: Add batch state to `DocumentStore`**

```swift
@Published var batchQueue = BatchImportQueue()
@Published var recentDocuments: [ReaderDocument] = []
```

- [ ] **Step 2: Process selected URLs sequentially**

```swift
func importURLs(_ urls: [URL]) async { ... }
```

- [ ] **Step 3: Show batch queue in sidebar and allow selecting completed documents**

```swift
ForEach(store.batchQueue.items) { item in ... }
```

- [ ] **Step 4: Allow multi-file open and multi-file drop**

```swift
panel.allowsMultipleSelection = true
```

### Task 3: Verification

**Files:**
- No new files.

- [ ] **Step 1: Run all tests**

Run: `swift test`
Expected: PASS.

- [ ] **Step 2: Build app**

Run: `swift build --product SightlineReader`
Expected: PASS.

- [ ] **Step 3: Launch verify**

Run: `./script/build_and_run.sh --verify`
Expected: PASS and app process exists.

## Self-Review

- PRD P1 batch import is covered for multiple PDFs/images through Open Panel and drag/drop.
- Processing remains local and sequential to avoid UI freezes and runaway parallel Vision/PDF processing.
- Existing single-document review/export stays intact by selecting one completed batch document at a time.
- Screenshot capture/current window are intentionally left for the next import P1 feature because they require macOS ScreenCaptureKit permissions and a separate UI path.
