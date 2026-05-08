import AppKit
import Combine
import Foundation
import PageLumenCore

@MainActor
final class DocumentStore: ObservableObject {
    enum Destination: Hashable {
        case home
        case processing
        case review
        case summaryExport
    }

    enum ReviewFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case needsReview = "Needs Review"
        case headings = "Headings"
        case tablesFigures = "Tables & Figures"

        var id: String { rawValue }
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
    @Published var processingDocument: ReaderDocument?
    @Published var processingFileName = ""
    @Published var reviewSearchQuery = ""
    @Published var reviewFilter: ReviewFilter = .all

    private let processor = DocumentProcessor()
    private let exportEngine = ExportEngine()
    private let explanationEngine = ExplanationEngine()
    private let screenshotCaptureService = ScreenshotCaptureService()
    private var importTask: Task<Void, Never>?

    init() {
        exportOptions = ExportOptions(
            includeHeadings: UserDefaults.standard.object(forKey: "includeHeadings") as? Bool ?? true,
            includeTables: UserDefaults.standard.object(forKey: "includeTables") as? Bool ?? true,
            includeFigures: UserDefaults.standard.object(forKey: "includeFigures") as? Bool ?? true,
            includePageReferences: UserDefaults.standard.object(forKey: "includePageReferences") as? Bool ?? true,
            includeConfidenceNotes: UserDefaults.standard.object(forKey: "includeConfidenceNotes") as? Bool ?? true,
            includeHeadersAndFooters: UserDefaults.standard.object(forKey: "includeHeadersAndFooters") as? Bool ?? true
        )
        applyLanguagePreference()
    }

    var selectedPage: ReaderPage? {
        document.pages.first(where: { $0.pageNumber == selectedPageNumber }) ?? document.pages.first
    }

    var lowConfidenceBlocks: [TextBlock] {
        document.allBlocks.filter { $0.confidence < 0.7 }
    }

    var reviewIssueCount: Int {
        lowConfidenceBlocks.count + document.pages.filter { $0.warning != nil }.count
    }

    var extractionReadinessLabel: String {
        if isProcessing {
            return "Processing locally"
        }
        if reviewIssueCount == 0 {
            return "Ready to export"
        }
        return "\(reviewIssueCount) review item\(reviewIssueCount == 1 ? "" : "s")"
    }

    var filteredSelectedPageBlocks: [TextBlock] {
        guard let page = selectedPage else {
            return []
        }

        let filtered = page.blocks.filter { block in
            switch reviewFilter {
            case .all:
                return true
            case .needsReview:
                return block.confidence < 0.7 || block.type == .unknown
            case .headings:
                return block.type == .heading || block.type == .header || block.type == .footer
            case .tablesFigures:
                return block.type == .table || block.type == .figure
            }
        }

        let query = reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return filtered
        }
        return filtered.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var reviewSearchMatchCount: Int {
        let query = reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return 0
        }
        return document.allBlocks.filter { $0.text.localizedCaseInsensitiveContains(query) }.count
    }

    func jumpToFirstReviewIssue() {
        if let block = lowConfidenceBlocks.first {
            selectedPageNumber = block.pageNumber
            selectedDestination = .review
            reviewFilter = .needsReview
        } else if let page = document.pages.first(where: { $0.warning != nil }) {
            selectedPageNumber = page.pageNumber
            selectedDestination = .review
        }
    }

    func jumpToNextSearchMatch() {
        let query = reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }

        let matches = document.allBlocks.filter { $0.text.localizedCaseInsensitiveContains(query) }
        guard !matches.isEmpty else {
            return
        }

        let next = matches.first { $0.pageNumber > selectedPageNumber } ?? matches.first
        if let next {
            selectedPageNumber = next.pageNumber
            selectedDestination = .review
        }
    }

    func loadSample() {
        document = SampleDataFactory.makeDemoDocument()
        applyLanguagePreference()
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
            startImport(urls: panel.urls)
        }
    }

    func importURL(_ url: URL) async {
        await importURLs([url])
    }

    func startImport(urls: [URL]) {
        importTask?.cancel()
        importTask = Task { [weak self] in
            await self?.importURLs(urls)
        }
    }

    func importURLs(_ urls: [URL]) async {
        let supportedURLs = urls.filter(BatchImportQueue.isSupportedURL)
        guard !supportedURLs.isEmpty else {
            statusMessage = "No supported PDF or image files were selected."
            return
        }

        batchQueue = BatchImportQueue(urls: supportedURLs)
        processingDocument = nil
        processingFileName = ""
        isProcessing = true
        selectedDestination = .processing

        do {
            while let item = batchQueue.pendingItem {
                try Task.checkCancellation()
                batchQueue.markProcessing(item.id)
                processingFileName = item.fileName
                statusMessage = "Processing \(item.fileName)..."

                do {
                    let processed = try await processor.process(url: item.url) { [weak self] snapshot in
                        guard let self, !Task.isCancelled else { return }
                        var preparedSnapshot = snapshot
                        self.applyLanguagePreference(to: &preparedSnapshot)
                        self.processingDocument = preparedSnapshot
                        self.document = preparedSnapshot
                        self.selectedPageNumber = snapshot.pages.first(where: { $0.ocrStatus == .processing })?.pageNumber
                            ?? snapshot.pages.first(where: { $0.ocrStatus == .pending })?.pageNumber
                            ?? snapshot.pages.first?.pageNumber
                            ?? 1
                    }
                    var prepared = processed
                    applyLanguagePreference(to: &prepared)
                    batchQueue.markCompleted(item.id, document: prepared)
                    remember(prepared)
                    document = prepared
                    processingDocument = prepared
                    selectedPageNumber = prepared.pages.first?.pageNumber ?? 1
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    batchQueue.markFailed(item.id, message: error.localizedDescription)
                    statusMessage = "Failed \(item.fileName): \(error.localizedDescription)"
                }
            }

            isProcessing = false
            importTask = nil
            statusMessage = batchSummary
            selectedDestination = .review
        } catch is CancellationError {
            cancelImport()
        } catch {
            isProcessing = false
            importTask = nil
            statusMessage = error.localizedDescription
        }
    }

    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        batchQueue.cancelActiveAndPendingItems()
        isProcessing = false
        processingFileName = ""
        if var snapshot = processingDocument {
            snapshot.processingStatus = .partial
            processingDocument = snapshot
            document = snapshot
        }
        statusMessage = "Import cancelled"
    }

    func pasteImageFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            statusMessage = "Clipboard does not contain an image."
            return
        }

        importTask?.cancel()
        importTask = Task { [weak self] in
            guard let self else { return }
            isProcessing = true
            processingFileName = "Clipboard Image"
            selectedDestination = .processing
            do {
                document = try await processor.processClipboardImage(image) { [weak self] snapshot in
                    guard let self else { return }
                    var preparedSnapshot = snapshot
                    self.applyLanguagePreference(to: &preparedSnapshot)
                    self.processingDocument = preparedSnapshot
                    self.document = preparedSnapshot
                }
                applyLanguagePreference()
                try Task.checkCancellation()
                processingDocument = document
                remember(document)
                selectedPageNumber = 1
                statusMessage = "Extracted clipboard image locally"
                selectedDestination = .review
                isProcessing = false
                importTask = nil
            } catch is CancellationError {
                cancelImport()
            } catch {
                statusMessage = error.localizedDescription
                isProcessing = false
                importTask = nil
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

        do {
            let url = try await screenshotCaptureService.capture(mode: mode)
            isProcessing = false
            startImport(urls: [url])
        } catch {
            isProcessing = false
            statusMessage = error.localizedDescription
        }
    }

    func regenerateSummary() {
        document.summary = explanationEngine.summary(for: document, length: summaryLength)
    }

    func persistExportDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(exportOptions.includeHeadings, forKey: "includeHeadings")
        defaults.set(exportOptions.includeTables, forKey: "includeTables")
        defaults.set(exportOptions.includeFigures, forKey: "includeFigures")
        defaults.set(exportOptions.includePageReferences, forKey: "includePageReferences")
        defaults.set(exportOptions.includeConfidenceNotes, forKey: "includeConfidenceNotes")
        defaults.set(exportOptions.includeHeadersAndFooters, forKey: "includeHeadersAndFooters")
    }

    func applyLanguagePreference() {
        applyLanguagePreference(to: &document)
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
        let cancelledCount = batchQueue.items.filter { $0.status == .cancelled }.count
        if cancelledCount > 0 {
            return "Cancelled \(cancelledCount) of \(batchQueue.totalCount) files"
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

    private func applyLanguagePreference(to targetDocument: inout ReaderDocument) {
        let hint = UserDefaults.standard.string(forKey: "languageHint") ?? "Automatic"
        targetDocument.language = languageCode(for: hint)
    }

    private func languageCode(for hint: String) -> String? {
        switch hint {
        case "English":
            return "en"
        case "Hindi":
            return "hi"
        case "Spanish":
            return "es"
        case "French":
            return "fr"
        default:
            return nil
        }
    }
}
