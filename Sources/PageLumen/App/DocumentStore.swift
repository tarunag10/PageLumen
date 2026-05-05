import AppKit
import Combine
import Foundation
import PageLumenCore

@MainActor
final class DocumentStore: ObservableObject {
    enum Destination: Hashable {
        case home
        case review
        case summaryExport
    }

    @Published var document: ReaderDocument = SampleDataFactory.makeDemoDocument()
    @Published var selectedDestination: Destination? = .home
    @Published var selectedPageNumber: Int = 1
    @Published var isProcessing = false
    @Published var statusMessage = "Ready"
    @Published var exportOptions = ExportOptions.full
    @Published var summaryLength: SummaryLength = .short
    @Published var batchQueue = BatchImportQueue()
    @Published var recentDocuments: [ReaderDocument] = []

    private let processor = DocumentProcessor()
    private let exportEngine = ExportEngine()
    private let explanationEngine = ExplanationEngine()
    private let screenshotCaptureService = ScreenshotCaptureService()

    var selectedPage: ReaderPage? {
        document.pages.first(where: { $0.pageNumber == selectedPageNumber }) ?? document.pages.first
    }

    func loadSample() {
        document = SampleDataFactory.makeDemoDocument()
        remember(document)
        selectedPageNumber = 1
        selectedDestination = .review
        statusMessage = "Loaded demo document"
    }

    func openDocumentPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose PDFs, screenshots, scans, or images to make readable."
        if panel.runModal() == .OK {
            Task { await importURLs(panel.urls) }
        }
    }

    func importURL(_ url: URL) async {
        await importURLs([url])
    }

    func importURLs(_ urls: [URL]) async {
        let supportedURLs = urls.filter(BatchImportQueue.isSupportedURL)
        guard !supportedURLs.isEmpty else {
            statusMessage = "No supported PDF or image files were selected."
            return
        }

        batchQueue = BatchImportQueue(urls: supportedURLs)
        isProcessing = true
        selectedDestination = .review
        defer {
            isProcessing = false
            statusMessage = batchSummary
        }

        while let item = batchQueue.pendingItem {
            batchQueue.markProcessing(item.id)
            statusMessage = "Processing \(item.fileName)..."

            do {
                let processed = try await processor.process(url: item.url)
                batchQueue.markCompleted(item.id, document: processed)
                remember(processed)
                document = processed
                selectedPageNumber = processed.pages.first?.pageNumber ?? 1
            } catch {
                batchQueue.markFailed(item.id, message: error.localizedDescription)
            }
        }
    }

    func pasteImageFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            statusMessage = "Clipboard does not contain an image."
            return
        }

        Task {
            isProcessing = true
            selectedDestination = .review
            defer { isProcessing = false }
            do {
                document = try await processor.processClipboardImage(image)
                remember(document)
                selectedPageNumber = 1
                statusMessage = "Extracted clipboard image locally"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func captureSelectedRegion() {
        Task {
            await captureScreenshot(mode: .selectedRegion)
        }
    }

    func captureWindow() {
        Task {
            await captureScreenshot(mode: .window)
        }
    }

    func captureScreenshot(mode: ScreenshotCaptureMode) async {
        isProcessing = true
        statusMessage = mode == .selectedRegion ? "Select a screen region to capture..." : "Click a window to capture..."
        defer { isProcessing = false }

        do {
            let url = try await screenshotCaptureService.capture(mode: mode)
            await importURL(url)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func regenerateSummary() {
        document.summary = explanationEngine.summary(for: document, length: summaryLength)
    }

    func selectBatchItem(_ item: BatchImportItem) {
        guard let selectedDocument = item.document else {
            return
        }
        document = selectedDocument
        selectedPageNumber = selectedDocument.pages.first?.pageNumber ?? 1
        selectedDestination = .review
        statusMessage = "Viewing \(selectedDocument.title)"
    }

    func selectRecentDocument(_ selectedDocument: ReaderDocument) {
        document = selectedDocument
        selectedPageNumber = selectedDocument.pages.first?.pageNumber ?? 1
        selectedDestination = .review
        statusMessage = "Viewing \(selectedDocument.title)"
    }

    func updateBlock(_ block: TextBlock, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == block.pageNumber }),
              let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == block.id }) else {
            return
        }
        document.pages[pageIndex].blocks[blockIndex].text = text
        document.summary = explanationEngine.summary(for: document, length: summaryLength)
    }

    func moveBlock(_ block: TextBlock, direction: BlockMoveDirection) {
        DocumentEditing.moveBlock(id: block.id, direction: direction, in: &document)
        document.summary = explanationEngine.summary(for: document, length: summaryLength)
    }

    func fullExtractedText() -> String {
        DocumentEditing.fullText(for: document, includeHeadersAndFooters: exportOptions.includeHeadersAndFooters)
    }

    func export(format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = []
        panel.nameFieldStringValue = "\(document.title).\(format.fileExtension)"
        panel.message = "Export a cleaner, more accessible version of the extracted content."

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = exportEngine.data(for: document, format: format, options: exportOptions)
                try data.write(to: url, options: .atomic)
                statusMessage = "Exported \(format.rawValue) to \(url.lastPathComponent)"
            } catch {
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private var batchSummary: String {
        if batchQueue.totalCount == 0 {
            return "Ready"
        }
        if batchQueue.failedCount == 0 {
            return "Processed \(batchQueue.completedCount) of \(batchQueue.totalCount) files"
        }
        return "Processed \(batchQueue.completedCount) of \(batchQueue.totalCount) files, \(batchQueue.failedCount) failed"
    }

    private func remember(_ newDocument: ReaderDocument) {
        recentDocuments.removeAll { existing in
            existing.id == newDocument.id || (existing.sourceURL != nil && existing.sourceURL == newDocument.sourceURL)
        }
        recentDocuments.insert(newDocument, at: 0)
        recentDocuments = Array(recentDocuments.prefix(12))
    }
}
