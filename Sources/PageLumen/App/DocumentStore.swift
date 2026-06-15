import AppKit
import Combine
import Foundation
import PageLumenCore
import UniformTypeIdentifiers

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

    @Published var document: ReaderDocument = DocumentStore.makeInitialDocument()
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
    @Published var exportPreviewFormat: ExportFormat = .markdown

    private let exportEngine = ExportEngine()
    private let explanationEngine = ExplanationEngine()
    private let screenshotCaptureService = ScreenshotCaptureService()
    private let audioExportService = AudioExportService()
    private var importTask: Task<Void, Never>?

    private let processor: any DocumentImporting
    private let persisting: any DocumentPersisting

    private var searchIndex: [String: [UUID]] = [:]
    private var searchIndexFingerprint: Int = 0
    private var searchIndexOrder: [TextBlock] = []

    private var currentOCRProfile: OCRProfile {
        OCRProfile(settingsValue: UserDefaults.standard.string(forKey: "ocrProfile") ?? OCRProfile.general.rawValue)
    }

    init(
        processor: any DocumentImporting = DocumentProcessor(),
        persisting: any DocumentPersisting = FilePersisting()
    ) {
        self.processor = processor
        self.persisting = persisting
        exportOptions = ExportOptions(
            includeHeadings: UserDefaults.standard.object(forKey: "includeHeadings") as? Bool ?? true,
            includeTables: UserDefaults.standard.object(forKey: "includeTables") as? Bool ?? true,
            includeFigures: UserDefaults.standard.object(forKey: "includeFigures") as? Bool ?? true,
            includePageReferences: UserDefaults.standard.object(forKey: "includePageReferences") as? Bool ?? true,
            includeConfidenceNotes: UserDefaults.standard.object(forKey: "includeConfidenceNotes") as? Bool ?? true,
            includeHeadersAndFooters: UserDefaults.standard.object(forKey: "includeHeadersAndFooters") as? Bool ?? true
        )
        if let stored = try? persisting.recentDocuments(), let first = stored.first {
            self.recentDocuments = stored
            self.document = first
            self.selectedDestination = .review
        } else {
            self.document = DocumentStore.makeInitialDocument()
            self.recentDocuments = [self.document]
        }
        applyLanguagePreference()
    }

    var selectedPage: ReaderPage? {
        document.pages.first(where: { $0.pageNumber == selectedPageNumber }) ?? document.pages.first
    }

    var lowConfidenceBlocks: [TextBlock] {
        document.allBlocks.filter { $0.confidence < 0.7 }
    }

    var reviewIssues: [ReviewIssue] {
        DocumentEditing.reviewIssues(for: document)
    }

    var reviewProgress: ReviewProgress {
        DocumentEditing.reviewProgress(for: document)
    }

    var reviewIssueCount: Int {
        reviewIssues.count
    }

    var extractionReadinessLabel: String {
        if isProcessing {
            return "Processing locally"
        }
        if reviewIssueCount == 0 && reviewProgress.fractionComplete >= 1 {
            return "Ready to export"
        }
        return "\(reviewIssueCount) issue\(reviewIssueCount == 1 ? "" : "s")"
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
        let matchIDs = Set(blocksMatching(query: query).map(\.id))
        return filtered.filter { matchIDs.contains($0.id) }
    }

    var reviewSearchMatchCount: Int {
        let query = reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return 0
        }
        return blocksMatching(query: query).count
    }

    func jumpToFirstReviewIssue() {
        if let issue = reviewIssues.first {
            selectedPageNumber = issue.pageNumber
            selectedDestination = .review
            reviewFilter = .needsReview
        }
    }

    func jumpToIssue(_ issue: ReviewIssue) {
        selectedPageNumber = issue.pageNumber
        selectedDestination = .review
        reviewFilter = .needsReview
    }

    func jumpToNextSearchMatch() {
        let query = reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }

        let matches = blocksMatching(query: query)
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
        document = DocumentStore.makeInitialDocument()
        applyLanguagePreference()
        remember(document)
        selectedPageNumber = 1
        selectedDestination = .review
        statusMessage = "Loaded demo document"
    }

    func forgetAllRecentDocuments() {
        let count = recentDocuments.count
        recentDocuments.removeAll()
        try? persisting.forgetAll()
        statusMessage = count == 0 ? "No recent documents to forget" : "Forgot \(count) recent document\(count == 1 ? "" : "s")"
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
                    let processed = try await processor.process(securityScopedURL: item.url) { [weak self] snapshot in
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
            importTask?.cancel()
            importTask = Task { [weak self] in
                defer {
                    try? FileManager.default.removeItem(at: url)
                }
                await self?.importURLs([url])
            }
        } catch {
            isProcessing = false
            statusMessage = error.localizedDescription
        }
    }

    func regenerateSummary() {
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
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
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func setBlockReviewed(_ block: TextBlock, isReviewed: Bool) {
        DocumentEditing.setBlockReviewed(id: block.id, isReviewed: isReviewed, in: &document)
        statusMessage = isReviewed ? "Marked block reviewed" : "Marked block for review"
    }

    func setSelectedPageReviewed(_ isReviewed: Bool) {
        DocumentEditing.setPageReviewed(pageNumber: selectedPageNumber, isReviewed: isReviewed, in: &document)
        statusMessage = isReviewed ? "Marked page \(selectedPageNumber) reviewed" : "Marked page \(selectedPageNumber) for review"
    }

    func changeBlockType(_ block: TextBlock, to type: BlockType) {
        DocumentEditing.changeBlockType(id: block.id, to: type, in: &document)
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
        statusMessage = "Changed block type to \(type.rawValue)"
    }

    func updateTableExplanation(_ table: TableRegion, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == table.pageNumber }),
              let tableIndex = document.pages[pageIndex].tables.firstIndex(where: { $0.id == table.id }) else {
            return
        }
        document.pages[pageIndex].tables[tableIndex].explanation = text
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func updateFigureDescription(_ figure: FigureRegion, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == figure.pageNumber }),
              let figureIndex = document.pages[pageIndex].figures.firstIndex(where: { $0.id == figure.id }) else {
            return
        }
        document.pages[pageIndex].figures[figureIndex].description = text
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func moveBlock(_ block: TextBlock, direction: BlockMoveDirection) {
        DocumentEditing.moveBlock(id: block.id, direction: direction, in: &document)
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    /// Move a block directly to a specific index within its page, in a single
    /// operation. Used by the drag-and-drop reorder gesture, which knows the
    /// final destination up front and shouldn't have to chain repeated
    /// `moveBlock(_:direction:)` calls.
    func reorderBlock(id: UUID, to destinationIndex: Int) {
        guard let pageIndex = document.pages.firstIndex(where: { page in
            page.blocks.contains(where: { $0.id == id })
        }),
        let sourceIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == id }) else {
            return
        }

        let blockCount = document.pages[pageIndex].blocks.count
        let clampedDestination = max(0, min(destinationIndex, blockCount - 1))
        guard sourceIndex != clampedDestination else { return }

        let block = document.pages[pageIndex].blocks.remove(at: sourceIndex)
        document.pages[pageIndex].blocks.insert(block, at: clampedDestination)
        DocumentEditing.renumberBlocks(on: &document.pages[pageIndex])
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func exportPreviewText(limit: Int = 4_000) -> String {
        let format = exportPreviewFormat
        let options = exportOptions
        let optionsHash = Self.optionsHash(options)
        let version = currentDocumentVersion

        if let cached = previewCache,
           cached.format == format,
           cached.optionsHash == optionsHash,
           cached.documentVersion == version,
           cached.limit == limit {
            return cached.text
        }

        let text = DocumentEditing.exportPreview(for: document, format: format, options: options, maxCharacters: limit)
        previewCache = PreviewCache(format: format, optionsHash: optionsHash, documentVersion: version, limit: limit, text: text)
        return text
    }

    // Cache key intentionally covers only the inputs that change the rendered
    // preview (format + the six option booleans + a content fingerprint).
    // Bumping the fingerprint on every document mutation keeps the cache fresh
    // without invalidating on every SwiftUI re-render.
    private struct PreviewCache {
        let format: ExportFormat
        let optionsHash: Int
        let documentVersion: Int
        let limit: Int
        let text: String
    }

    private var previewCache: PreviewCache?

    private var currentDocumentVersion: Int {
        var hasher = Hasher()
        hasher.combine(document.id)
        hasher.combine(document.pageCount)
        hasher.combine(document.allBlocks.count)
        for page in document.pages {
            for block in page.blocks {
                hasher.combine(block.id)
            }
        }
        return hasher.finalize()
    }

    private static func optionsHash(_ options: ExportOptions) -> Int {
        var hasher = Hasher()
        hasher.combine(options.includeHeadings)
        hasher.combine(options.includeTables)
        hasher.combine(options.includeFigures)
        hasher.combine(options.includePageReferences)
        hasher.combine(options.includeConfidenceNotes)
        hasher.combine(options.includeHeadersAndFooters)
        return hasher.finalize()
    }

    func fullExtractedText() -> String {
        DocumentEditing.fullText(for: document, includeHeadersAndFooters: exportOptions.includeHeadersAndFooters)
    }

    func export(format: ExportFormat) {
        switch format {
        case .audio:
            exportAudio()
        case .docx:
            exportDOCX()
        case .translated:
            exportTranslated()
        default:
            exportData(format: format)
        }
    }

    private func exportTranslated() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = []
        panel.nameFieldStringValue = "\(document.title).md"
        panel.message = "Translate the document to the language chosen in Settings, then export as Markdown."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let targetLanguage = Self.targetLanguageFromDefaults()
        let options = exportOptions
        let sourceDocument = document

        Task { @MainActor in
            do {
                let translatedDoc = try await TranslationService().translate(document: sourceDocument, to: targetLanguage)
                let markdown = ExportEngine().markdown(for: translatedDoc, options: options)
                let data = Data(markdown.utf8)
                try data.write(to: url, options: .atomic)
                statusMessage = "Exported Translated Markdown to \(url.lastPathComponent)"
            } catch {
                statusMessage = "Translation export failed: \(error.localizedDescription)"
            }
        }
    }

    private static func targetLanguageFromDefaults() -> Locale.Language {
        let code = UserDefaults.standard.string(forKey: "translationTargetLanguage") ?? "en"
        return Locale.Language(identifier: code)
    }

    private func exportData(format: ExportFormat) {
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

    private func exportAudio() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.audio]
        panel.nameFieldStringValue = "\(document.title).m4a"
        panel.message = "Export the spoken summary as an .m4a file."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        isProcessing = true
        statusMessage = "Synthesizing audio summary..."
        Task { [weak self] in
            guard let self else { return }
            do {
                let textToSpeak = self.document.summary.isEmpty
                    ? self.fullExtractedText()
                    : self.document.summary
                try await self.audioExportService.export(text: textToSpeak, to: url)
                self.statusMessage = "Exported Audio to \(url.lastPathComponent)"
            } catch {
                self.statusMessage = "Audio export failed: \(error.localizedDescription)"
            }
            self.isProcessing = false
        }
    }

    private func exportDOCX() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        panel.nameFieldStringValue = "\(document.title).docx"
        panel.message = "Export the document as a Word-compatible .docx file."

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = DOCXWriter().data(for: document, options: exportOptions)
                try data.write(to: url, options: .atomic)
                statusMessage = "Exported DOCX to \(url.lastPathComponent)"
            } catch {
                statusMessage = "DOCX export failed: \(error.localizedDescription)"
            }
        }
    }

    private func blocksMatching(query: String) -> [TextBlock] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        let tokens = Self.searchTokens(for: trimmed)
        guard !tokens.isEmpty else {
            return []
        }

        rebuildSearchIndexIfNeeded()

        var candidateIDs: Set<UUID>?
        for token in tokens {
            let hits = searchIndex[token] ?? []
            if candidateIDs == nil {
                candidateIDs = Set(hits)
            } else {
                candidateIDs?.formIntersection(hits)
            }
        }

        let ids = candidateIDs ?? []
        return searchIndexOrder.filter { ids.contains($0.id) }
    }

    private func rebuildSearchIndexIfNeeded() {
        let fingerprint = currentDocumentVersion
        guard fingerprint != searchIndexFingerprint || searchIndex.isEmpty else {
            return
        }

        var tokenIndex: [String: [UUID]] = [:]
        var ordered: [TextBlock] = []
        ordered.reserveCapacity(document.allBlocks.count)

        for block in document.allBlocks {
            ordered.append(block)
            for token in Self.tokensForIndexing(block.text) {
                tokenIndex[token, default: []].append(block.id)
            }
        }

        searchIndex = tokenIndex
        searchIndexOrder = ordered
        searchIndexFingerprint = fingerprint
    }

    private static func searchTokens(for query: String) -> [String] {
        let lowered = query.lowercased()
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        let raw = lowered.components(separatedBy: separators)
        return raw.filter { $0.count >= 3 }
    }

    private static func tokensForIndexing(_ text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        let raw = text.lowercased().components(separatedBy: separators)
        return raw.filter { $0.count >= 3 }
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
        var stamped = newDocument
        stamped.createdAt = Date()
        recentDocuments.removeAll { existing in
            existing.id == stamped.id || (existing.sourceURL != nil && existing.sourceURL == stamped.sourceURL)
        }
        recentDocuments.insert(stamped, at: 0)
        recentDocuments = Array(recentDocuments.prefix(12))
        try? persisting.save(stamped)
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

    #if DEBUG
    static func makeInitialDocument() -> ReaderDocument {
        SampleDataFactory.makeDemoDocument()
    }
    #else
    static func makeInitialDocument() -> ReaderDocument {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 900, height: 1_200),
            blocks: [
                TextBlock(
                    pageNumber: 1,
                    type: .heading,
                    text: "Welcome to PageLumen",
                    bounds: BoundingBox(x: 70, y: 64, width: 480, height: 40),
                    confidence: 1.0,
                    readingOrderIndex: 0
                ),
                TextBlock(
                    pageNumber: 1,
                    type: .paragraph,
                    text: "Import a PDF, image, screenshot, or clipboard capture to begin.",
                    bounds: BoundingBox(x: 70, y: 130, width: 650, height: 72),
                    confidence: 1.0,
                    readingOrderIndex: 1
                )
            ]
        )
        return ReaderDocument(
            title: "PageLumen",
            sourceType: .sample,
            language: "en",
            processingStatus: .complete,
            pages: [page]
        )
    }
    #endif
}
