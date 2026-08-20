import AppKit
import Combine
import Foundation
import PageLumenCore
import PDFKit
import UniformTypeIdentifiers

struct ProcessingBudgetPrompt: Identifiable {
    let id = UUID()
    let url: URL
    let estimate: ProcessingBudgetEstimate
}

struct EditHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let label: String
    let timestamp: Date

    init(label: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.label = label
        self.timestamp = timestamp
    }
}

@MainActor
@Observable
final class DocumentStore {
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

    enum PersistenceStatus: Equatable {
        case available
        case degraded(String)

        var label: String {
            switch self {
            case .available:
                return "Local library available"
            case .degraded(let reason):
                return "Local library fallback: \(reason)"
            }
        }

        var systemImage: String {
            switch self {
            case .available:
                return "checkmark.circle.fill"
            case .degraded:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    var document: ReaderDocument = DocumentStore.makeInitialDocument()
    var selectedDestination: Destination? = .home
    var selectedPageNumber: Int = 1
    var selectedBlockID: UUID?
    var selectedReviewIssueID: String?
    var isProcessing = false
    var isExportingAudio = false
    private(set) var isStirlingOperationInFlight = false
    var audioExportProgress = AudioExportProgress(fractionCompleted: 0, phase: .preparing)
    var statusMessage = "Ready"
    var exportOptions = ExportOptions.full
    var summaryLength: SummaryLength = .short
    var batchQueue = BatchImportQueue()
    var recentDocuments: [ReaderDocument] = []
    private(set) var persistenceStatus: PersistenceStatus = .available
    var processingDocument: ReaderDocument?
    var processingFileName = ""
    var reviewSearchQuery = ""
    var reviewFilter: ReviewFilter = .all
    var reviewPreset: ReviewPreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "reviewPreset"),
                  let preset = ReviewPreset(rawValue: raw) else { return .general }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "reviewPreset")
        }
    }
    var exportPreviewFormat: ExportFormat = .markdown
    var reviewDraft: GroundedSummary?
    var librarySearchQuery = ""
    var librarySearchResults: [LibrarySearchResult] = []
    var watchFolderEnabled = false
    var watchFolderPathLabel = "Not configured"
    var watchFolderCandidates: [WatchFolderCandidate] = []
    var watchFolderFailures: [WatchFolderImportFailure] = []
    var processingBudgetPrompt: ProcessingBudgetPrompt?
    private var pendingImportURLs: [URL] = []

    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var editHistory: [EditHistoryEntry] = []

    var libraryStorageSizeLabel: String {
        do {
            guard let bytes = try persisting.storageSizeInBytes() else {
                return "Storage size unavailable"
            }
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } catch {
            return "Storage size unavailable"
        }
    }

    var lastLibraryClearLabel: String {
        guard let date = repositoryPreferences.object(forKey: DocumentRepositorySettings.lastClearedAtKey) as? Date else {
            return "Never"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var useOnDeviceAI: Bool {
        intelligenceMode == .appleFoundationModels && !isIntelligenceOptedOutForCurrentDocument
    }

    var intelligenceMode: IntelligenceMode {
        if let raw = intelligencePreferences.string(forKey: "intelligenceMode"),
           let mode = IntelligenceMode(rawValue: raw) {
            return mode
        }
        // Migrate the earlier boolean preference without silently enabling a
        // new mode for people who never opted into Apple Intelligence.
        return intelligencePreferences.bool(forKey: "useOnDeviceAI") ? .appleFoundationModels : .off
    }

    var isIntelligenceOptedOutForCurrentDocument: Bool {
        intelligencePreferences.bool(forKey: intelligenceOptOutKey(for: document.id))
    }

    func setIntelligenceMode(_ mode: IntelligenceMode) {
        intelligencePreferences.set(mode.rawValue, forKey: "intelligenceMode")
        intelligencePreferences.set(mode == .appleFoundationModels, forKey: "useOnDeviceAI")
        regenerateSummary()
        statusMessage = mode == .off
            ? "Apple Intelligence disabled; using deterministic summaries"
            : "\(mode.displayName) selected; regenerating the current summary when available"
    }

    func setIntelligenceOptOutForCurrentDocument(_ optedOut: Bool) {
        let key = intelligenceOptOutKey(for: document.id)
        if optedOut {
            intelligencePreferences.set(true, forKey: key)
        } else {
            intelligencePreferences.removeObject(forKey: key)
        }
        regenerateSummary()
        statusMessage = optedOut
            ? "Apple Intelligence disabled for this document"
            : "This document may use the selected Apple Intelligence mode"
    }

    var privacyMode: Bool {
        UserDefaults.standard.object(forKey: "privacyMode") as? Bool ?? true
    }

    func canNavigate(to destination: Destination) -> Bool {
        switch destination {
        case .home, .processing:
            return true
        case .review:
            return !document.pages.isEmpty
        case .summaryExport:
            return !document.pages.isEmpty && !isProcessing
        }
    }

    private let exportEngine = ExportEngine()
    private let explanationEngine = ExplanationEngine()
    private let screenshotCaptureService = ScreenshotCaptureService()
    private let audioExportService = AudioExportService()
    private let watchFolderMonitor = WatchFolderMonitor()
    private var importTask: Task<Void, Never>?
    private var audioExportTask: Task<Void, Never>?
    private var stirlingOperationTask: Task<Void, Never>?
    private var watchFolderImportsInFlight = Set<URL>()

    private let processor: any DocumentImporting
    private let persisting: any DocumentPersisting
    private let intelligencePreferences: UserDefaults
    private let repositoryPreferences: UserDefaults

    private var searchIndex: [String: [UUID]] = [:]
    private var searchIndexFingerprint: Int = 0
    private var searchIndexOrder: [TextBlock] = []
    private var undoStack: [ReaderDocument] = []
    private var redoStack: [ReaderDocument] = []
    private static let editHistoryLimit = 50

    private var currentOCRProfile: OCRProfile {
        OCRProfile(settingsValue: UserDefaults.standard.string(forKey: "ocrProfile") ?? OCRProfile.general.rawValue)
    }

    private func intelligenceOptOutKey(for id: UUID) -> String {
        "intelligence.optOut.\(id.uuidString.lowercased())"
    }

    init(
        processor: any DocumentImporting = DocumentProcessor(),
        persisting: (any DocumentPersisting)? = nil,
        intelligencePreferences: UserDefaults = .standard,
        repositoryPreferences: UserDefaults = .standard
    ) {
        self.processor = processor
        self.intelligencePreferences = intelligencePreferences
        self.repositoryPreferences = repositoryPreferences
        self.watchFolderEnabled = repositoryPreferences.bool(forKey: DocumentRepositorySettings.watchFolderEnabledKey)
        if let persisting {
            self.persisting = persisting
            self.persistenceStatus = .available
        } else if #available(macOS 14.0, *) {
            do {
                self.persisting = try SwiftDataPersisting()
                self.persistenceStatus = .available
            } catch let error as SwiftDataPersistingError {
                self.persisting = FilePersisting()
                switch error {
                case let .migrationFailed(backupURL, _):
                    let backupName = backupURL.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "the preserved store"
                    self.persistenceStatus = .degraded("SwiftData migration failed; recovery backup kept as \(backupName); using JSON recents")
                }
            } catch {
                self.persisting = FilePersisting()
                self.persistenceStatus = .degraded("SwiftData could not open; using JSON recents")
            }
        } else {
            self.persisting = FilePersisting()
            self.persistenceStatus = .degraded("SwiftData is unavailable on this macOS version")
        }
        exportOptions = ExportOptions(
            includeHeadings: UserDefaults.standard.object(forKey: "includeHeadings") as? Bool ?? true,
            includeTables: UserDefaults.standard.object(forKey: "includeTables") as? Bool ?? true,
            includeFigures: UserDefaults.standard.object(forKey: "includeFigures") as? Bool ?? true,
            includePageReferences: UserDefaults.standard.object(forKey: "includePageReferences") as? Bool ?? true,
            includeConfidenceNotes: UserDefaults.standard.object(forKey: "includeConfidenceNotes") as? Bool ?? true,
            includeHeadersAndFooters: UserDefaults.standard.object(forKey: "includeHeadersAndFooters") as? Bool ?? true,
            includeProvenance: UserDefaults.standard.object(forKey: "includeProvenance") as? Bool ?? true
        )
        do {
            let stored = try self.persisting.recentDocuments()
            if let first = stored.first {
                self.recentDocuments = stored
                self.document = first
                self.selectedDestination = .review
            } else {
                self.document = DocumentStore.makeInitialDocument()
                self.recentDocuments = [self.document]
            }
        } catch {
            self.persistenceStatus = .degraded("Local recents were damaged; a recoverable backup was kept")
            self.document = DocumentStore.makeInitialDocument()
            self.recentDocuments = [self.document]
        }
        applyLanguagePreference()
        if watchFolderEnabled {
            startConfiguredWatchFolder()
        }
    }

    func chooseWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to monitor for new PDFs and images."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            let bookmark = try WatchFolderBookmark.create(for: folder)
            repositoryPreferences.set(bookmark.data, forKey: DocumentRepositorySettings.watchFolderBookmarkKey)
            watchFolderPathLabel = folder.lastPathComponent
            setWatchFolderEnabled(true)
            statusMessage = "Watch folder enabled for \(folder.lastPathComponent); new files require confirmation"
        } catch {
            statusMessage = "Could not save watch folder: \(error.localizedDescription)"
        }
    }

    func setWatchFolderEnabled(_ enabled: Bool) {
        watchFolderEnabled = enabled
        repositoryPreferences.set(enabled, forKey: DocumentRepositorySettings.watchFolderEnabledKey)
        guard enabled else {
            watchFolderMonitor.stop()
            watchFolderCandidates.removeAll()
            watchFolderFailures.removeAll()
            watchFolderImportsInFlight.removeAll()
            return
        }
        startConfiguredWatchFolder()
    }

    func importWatchFolderCandidate(_ candidate: WatchFolderCandidate) {
        watchFolderCandidates.removeAll { $0.id == candidate.id }
        watchFolderFailures.removeAll { $0.id == candidate.id }
        watchFolderImportsInFlight.insert(candidate.url)
        startImport(urls: [candidate.url])
    }

    func dismissWatchFolderCandidate(_ candidate: WatchFolderCandidate) {
        watchFolderCandidates.removeAll { $0.id == candidate.id }
    }

    func retryWatchFolderFailure(_ failure: WatchFolderImportFailure) {
        watchFolderFailures.removeAll { $0.id == failure.id }
        watchFolderImportsInFlight.insert(failure.id)
        startImport(urls: [failure.id])
    }

    func dismissWatchFolderFailure(_ failure: WatchFolderImportFailure) {
        watchFolderFailures.removeAll { $0.id == failure.id }
    }

    private func startConfiguredWatchFolder() {
        guard let data = repositoryPreferences.data(forKey: DocumentRepositorySettings.watchFolderBookmarkKey) else {
            watchFolderEnabled = false
            return
        }
        do {
            let bookmark = WatchFolderBookmark(data: data)
            watchFolderPathLabel = try bookmark.resolve().lastPathComponent
            try watchFolderMonitor.start(bookmark: bookmark) { [weak self] candidates in
                await MainActor.run {
                    guard let self else { return }
                    self.watchFolderCandidates.append(contentsOf: candidates.filter { candidate in
                        !self.watchFolderCandidates.contains(where: { $0.id == candidate.id })
                    })
                    self.statusMessage = "\(self.watchFolderCandidates.count) watch-folder file\(self.watchFolderCandidates.count == 1 ? "" : "s") awaiting confirmation"
                }
            } onError: { [weak self] error in
                await MainActor.run {
                    guard let self else { return }
                    self.watchFolderEnabled = false
                    self.repositoryPreferences.set(false, forKey: DocumentRepositorySettings.watchFolderEnabledKey)
                    self.statusMessage = "Watch folder stopped: \(error.localizedDescription)"
                }
            }
        } catch {
            watchFolderEnabled = false
            repositoryPreferences.set(false, forKey: DocumentRepositorySettings.watchFolderEnabledKey)
            statusMessage = "Watch folder unavailable: \(error.localizedDescription)"
        }
    }

    var selectedPage: ReaderPage? {
        document.pages.first(where: { $0.pageNumber == selectedPageNumber }) ?? document.pages.first
    }

    var lowConfidenceBlocks: [TextBlock] {
        document.allBlocks.filter { $0.confidence < 0.7 }
    }

    var reviewIssues: [ReviewIssue] {
        DocumentEditing.reviewIssues(for: document, preset: reviewPreset)
    }

    var reviewFindings: [ReviewFinding] {
        DocumentEditing.reviewFindings(for: document, preset: reviewPreset)
    }

    var documentChanges: [DocumentChange] {
        DocumentComparison.changes(in: document)
    }

    /// Undo checkpoints are immutable value snapshots and can be selected as
    /// an explicit comparison baseline without mutating the live document.
    /// The newest checkpoint is index zero, matching the visible edit history.
    var comparisonRevisionCount: Int { undoStack.count }

    func comparisonChanges(comparedToRevision index: Int) -> [DocumentChange] {
        guard index >= 0, index < undoStack.count else { return [] }
        let baseline = undoStack[undoStack.count - 1 - index]
        return DocumentComparison.changes(from: baseline, to: document)
    }

    /// The current Review location, suitable for restoration by a Quick Look,
    /// share extension, or future URL scheme. Only stable identifiers are
    /// emitted so source text never leaks through a deep link.
    var reviewSelectionPayload: ReviewSelectionPayload {
        ReviewSelectionPayload(
            documentID: document.id,
            pageNumber: selectedPage?.pageNumber ?? selectedPageNumber,
            blockID: selectedBlockID,
            issueID: selectedReviewIssueID ?? currentReviewIssue?.id
        )
    }

    /// Applies a serialized Review location after validating it against the
    /// currently open document. Invalid page or block identifiers are rejected
    /// rather than silently selecting a different source block.
    @discardableResult
    func applyReviewSelection(_ payload: ReviewSelectionPayload) -> Bool {
        if let payloadDocumentID = payload.documentID, payloadDocumentID != document.id {
            statusMessage = "This Review link belongs to a different document"
            return false
        }
        guard let page = document.pages.first(where: { $0.pageNumber == payload.pageNumber }) else {
            statusMessage = "Review link points to a missing page"
            return false
        }
        if let blockID = payload.blockID, !page.blocks.contains(where: { $0.id == blockID }) {
            statusMessage = "Review link points to a missing block on page \(page.pageNumber)"
            return false
        }
        selectedPageNumber = page.pageNumber
        selectedBlockID = payload.blockID
        selectedReviewIssueID = payload.issueID
        selectedDestination = .review
        statusMessage = payload.blockID == nil
            ? "Opened Review page \(page.pageNumber)"
            : "Opened Review page \(page.pageNumber) source block"
        return true
    }

    /// Selects one source location and keeps the preview, extracted text, and
    /// Review queue on the same page/block target.
    @discardableResult
    func selectReviewSource(pageNumber: Int, blockID: UUID? = nil, issueID: String? = nil) -> Bool {
        applyReviewSelection(ReviewSelectionPayload(
            documentID: document.id,
            pageNumber: pageNumber,
            blockID: blockID,
            issueID: issueID
        ))
    }

    var reviewProgress: ReviewProgress {
        DocumentEditing.reviewProgress(for: document, preset: reviewPreset)
    }

    func setReviewPreset(_ preset: ReviewPreset) {
        reviewPreset = preset
        statusMessage = "Review preset set to \(preset.rawValue)"
    }

    var reviewIssueCount: Int {
        reviewIssues.count
    }

    /// Whether every editable block on the selected page has been reviewed.
    /// Empty pages are not considered reviewed so the toolbar control cannot
    /// appear complete when there is no reviewable content.
    var isSelectedPageReviewed: Bool {
        guard let page = selectedPage, !page.blocks.isEmpty else { return false }
        return page.blocks.allSatisfy(DocumentEditing.isReviewed)
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

    var reviewSearchMatchPosition: Int? {
        let query = reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let selectedBlockID else { return nil }
        let matches = blocksMatching(query: query)
        guard let index = matches.firstIndex(where: { $0.id == selectedBlockID }) else { return nil }
        return index + 1
    }

    func jumpToFirstReviewIssue() {
        if let issue = reviewIssues.first {
            _ = selectReviewSource(pageNumber: issue.pageNumber, blockID: issue.blockID, issueID: issue.id)
            reviewFilter = .needsReview
        }
    }

    func jumpToNextReviewIssue() {
        jumpToReviewIssue(offset: 1)
    }

    func jumpToPreviousReviewIssue() {
        jumpToReviewIssue(offset: -1)
    }

    private func jumpToReviewIssue(offset: Int) {
        let issues = reviewIssues
        guard !issues.isEmpty else { return }
        let currentIndex = issues.firstIndex { issue in
            if let selectedBlockID, issue.blockID == selectedBlockID {
                return true
            }
            return issue.pageNumber == selectedPageNumber
        } ?? (offset > 0 ? -1 : issues.count)
        let nextIndex = (currentIndex + offset + issues.count) % issues.count
        jumpToIssue(issues[nextIndex])
    }

    func jumpToIssue(_ issue: ReviewIssue) {
        _ = selectReviewSource(pageNumber: issue.pageNumber, blockID: issue.blockID, issueID: issue.id)
        reviewFilter = .needsReview
    }

    /// The unresolved issue currently targeted by the review workspace.
    /// Prefer the selected block, then fall back to the selected page so
    /// page-level warnings remain actionable from keyboard commands.
    var currentReviewIssue: ReviewIssue? {
        if let selectedReviewIssueID,
           let issue = reviewIssues.first(where: {
               $0.id == selectedReviewIssueID &&
               $0.pageNumber == selectedPageNumber &&
               ($0.blockID == nil || $0.blockID == selectedBlockID)
           }) {
            return issue
        }
        if let selectedBlockID,
           let issue = reviewIssues.first(where: { $0.blockID == selectedBlockID }) {
            return issue
        }
        return reviewIssues.first(where: { $0.pageNumber == selectedPageNumber })
    }

    func acceptCurrentReviewIssue() {
        guard let issue = currentReviewIssue else {
            statusMessage = "Select a review issue first"
            return
        }
        resolveReviewIssue(issue)
    }

    func rejectCurrentReviewIssue() {
        guard let issue = currentReviewIssue else {
            statusMessage = "Select a review issue first"
            return
        }
        rejectReviewIssue(issue)
    }

    /// Resolves a block-backed finding without discarding the original OCR.
    /// Page-level warnings remain visible until their source warning is fixed.
    func resolveReviewIssue(_ issue: ReviewIssue) {
        markReviewIssueReviewed(issue)
    }

    /// Marks a queue item complete. Block findings become an explicit
    /// accepted decision; page warnings are corrected only after the reviewer
    /// has opened the original page. Neither path changes extracted source
    /// text or retained OCR observations.
    func markReviewIssueReviewed(_ issue: ReviewIssue) {
        if let blockID = issue.blockID,
           let block = document.allBlocks.first(where: { $0.id == blockID }) {
            setBlockReviewed(block, isReviewed: true)
            statusMessage = "Resolved: \(issue.title)"
            return
        }
        guard issue.kind == .pageWarning,
              document.pages.contains(where: { $0.pageNumber == issue.pageNumber && $0.warning != nil }) else {
            statusMessage = "This review item has no correctable source"
            return
        }
        recordEdit("Correct page warning")
        DocumentEditing.clearPageWarning(pageNumber: issue.pageNumber, in: &document)
        statusMessage = "Corrected page warning on page \(issue.pageNumber)"
    }

    func reopenReviewIssue(_ issue: ReviewIssue) {
        guard let blockID = issue.blockID,
              let block = document.allBlocks.first(where: { $0.id == blockID }) else {
            statusMessage = "This page warning remains open until its source is corrected"
            return
        }
        setBlockReviewed(block, isReviewed: false)
        statusMessage = "Reopened: \(issue.title)"
    }

    func rejectReviewIssue(_ issue: ReviewIssue) {
        guard let blockID = issue.blockID,
              let block = document.allBlocks.first(where: { $0.id == blockID }) else {
            statusMessage = "This page warning needs source-level correction"
            return
        }
        recordEdit("Reject review suggestion")
        DocumentEditing.setReviewDecision(id: block.id, decision: .rejected, in: &document)
        statusMessage = "Rejected: \(issue.title)"
    }

    func jumpToNextSearchMatch() {
        jumpToSearchMatch(direction: 1)
    }

    func jumpToPreviousSearchMatch() {
        jumpToSearchMatch(direction: -1)
    }

    private func jumpToSearchMatch(direction: Int) {
        let query = reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }

        let matches = blocksMatching(query: query)
        guard !matches.isEmpty else {
            return
        }

        let index: Int
        if let selectedBlockID, let currentIndex = matches.firstIndex(where: { $0.id == selectedBlockID }) {
            index = (currentIndex + direction + matches.count) % matches.count
        } else if direction > 0 {
            index = matches.firstIndex { $0.pageNumber >= selectedPageNumber } ?? 0
        } else {
            index = matches.lastIndex { $0.pageNumber < selectedPageNumber } ?? (matches.count - 1)
        }

        let match = matches[index]
        selectedBlockID = match.id
        selectedReviewIssueID = nil
        selectedPageNumber = match.pageNumber
        selectedDestination = .review
        statusMessage = "Match \(index + 1) of \(matches.count), page \(match.pageNumber)"
    }

    func loadSample() {
        document = DocumentStore.makeInitialDocument()
        applyLanguagePreference()
        remember(document)
        selectedPageNumber = 1
        selectedBlockID = nil
        selectedReviewIssueID = nil
        selectedDestination = .review
        statusMessage = "Loaded demo document"
    }

    func forgetAllRecentDocuments() {
        let count = recentDocuments.count
        recentDocuments.removeAll()
        try? persisting.forgetAll()
        repositoryPreferences.set(Date(), forKey: DocumentRepositorySettings.lastClearedAtKey)
        statusMessage = count == 0 ? "No recent documents to forget" : "Forgot \(count) recent document\(count == 1 ? "" : "s")"
    }

    /// Searches only retained local copies when the person has explicitly
    /// enabled searchable library storage. Source files are never opened by
    /// this path, and a disabled setting clears any prior result list.
    func searchLibrary(query: String? = nil) {
        if let query {
            librarySearchQuery = query
        }
        guard repositoryPreferences.bool(forKey: DocumentRepositorySettings.keepSearchableLocalCopiesKey) else {
            librarySearchResults = []
            statusMessage = "Library search is off; enable searchable local copies in Settings"
            return
        }
        let repository = LocalDocumentRepository(
            persisting: persisting,
            keepSearchableLocalCopies: true
        )
        do {
            librarySearchResults = try repository.search(query: librarySearchQuery, limit: 20)
            if librarySearchResults.isEmpty {
                statusMessage = "No library matches"
            } else {
                let suffix = librarySearchResults.count == 1 ? "" : "es"
                statusMessage = "Found \(librarySearchResults.count) library match\(suffix)"
            }
        } catch {
            librarySearchResults = []
            statusMessage = "Library search unavailable: \(error.localizedDescription)"
        }
    }

    /// Disables searchable retention and clears the active result/index view;
    /// retained documents and original source files are intentionally kept.
    func setKeepSearchableLocalCopies(_ enabled: Bool) {
        repositoryPreferences.set(enabled, forKey: DocumentRepositorySettings.keepSearchableLocalCopiesKey)
        if !enabled {
            librarySearchResults.removeAll()
            librarySearchQuery = ""
            statusMessage = "Searchable local copies removed; recent documents and source files were kept"
        } else {
            statusMessage = "Searchable local copies enabled for future library searches"
        }
    }

    func openLibrarySearchResult(_ result: LibrarySearchResult) {
        guard let selected = recentDocuments.first(where: { $0.id == result.documentID }) else {
            statusMessage = "The matching document is no longer in the local library"
            return
        }
        selectRecentDocument(selected)
        _ = selectReviewSource(pageNumber: result.pageNumber, blockID: result.blockID)
        statusMessage = "Opened \(result.title), page \(result.pageNumber)"
    }

    /// Removes one retained library copy without touching its source file.
    /// If the active document is removed, return to the import step.
    func forgetRecentDocument(_ selectedDocument: ReaderDocument) {
        let wasActive = selectedDocument.id == document.id
        recentDocuments.removeAll { $0.id == selectedDocument.id }
        do {
            try persisting.delete(id: selectedDocument.id)
        } catch {
            statusMessage = "Could not forget \(selectedDocument.title): \(error.localizedDescription)"
            if let restored = try? persisting.recentDocuments() {
                recentDocuments = restored
            }
            return
        }

        if wasActive {
            document = Self.makeInitialDocument()
            selectedPageNumber = 1
            selectedBlockID = nil
            selectedReviewIssueID = nil
            selectedDestination = .home
        }
        statusMessage = "Forgot \(selectedDocument.title); source files were not deleted"
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
        let supportedURLs = urls.filter(BatchImportQueue.isSupportedURL)
        guard !supportedURLs.isEmpty else {
            statusMessage = "No supported PDF or image files were selected."
            return
        }
        if let first = supportedURLs.first,
           let estimate = processingBudgetEstimate(for: first), estimate.requiresChoice {
            pendingImportURLs = supportedURLs
            processingBudgetPrompt = ProcessingBudgetPrompt(url: first, estimate: estimate)
            statusMessage = "Choose a bounded processing option before importing."
            return
        }
        beginImport(urls: supportedURLs, options: .full)
    }

    func chooseFullProcessing() {
        guard !pendingImportURLs.isEmpty else { return }
        let urls = pendingImportURLs
        pendingImportURLs = []
        processingBudgetPrompt = nil
        beginImport(urls: urls, options: .full)
    }

    func chooseBalancedProcessing() {
        guard !pendingImportURLs.isEmpty else { return }
        let urls = pendingImportURLs
        let pageRange: ClosedRange<Int>? = (processingBudgetPrompt?.estimate.pageCount ?? 0) > 100 ? 1...100 : nil
        pendingImportURLs = []
        processingBudgetPrompt = nil
        beginImport(urls: urls, options: ProcessingImportOptions(quality: .balanced, pageRange: pageRange))
    }

    func chooseFirstHundredPages() {
        guard !pendingImportURLs.isEmpty else { return }
        let urls = pendingImportURLs
        pendingImportURLs = []
        processingBudgetPrompt = nil
        beginImport(urls: urls, options: ProcessingImportOptions(pageRange: 1...100))
    }

    func dismissProcessingBudgetPrompt() {
        pendingImportURLs = []
        processingBudgetPrompt = nil
        statusMessage = "Import cancelled; choose a smaller page range or lower quality to continue."
    }

    private func beginImport(urls: [URL], options: ProcessingImportOptions) {
        importTask = Task { [weak self] in
            await self?.importURLs(urls, options: options)
        }
    }

    private func processingBudgetEstimate(for url: URL) -> ProcessingBudgetEstimate? {
        guard url.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: url) else { return nil }
        let sizes = (0..<pdf.pageCount).compactMap { index -> (width: Double, height: Double)? in
            guard let page = pdf.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            return (Double(bounds.width), Double(bounds.height))
        }
        return ProcessingBudgetEstimator.estimate(pageSizes: sizes)
    }

    func importURLs(_ urls: [URL], options: ProcessingImportOptions = .full) async {
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
                    let processed = try await processor.process(securityScopedURL: item.url, options: options) { [weak self] snapshot in
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
                    watchFolderImportsInFlight.remove(item.url)
                    remember(prepared)
                    document = prepared
                    processingDocument = prepared
                    selectedPageNumber = prepared.pages.first?.pageNumber ?? 1
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    let safeMessage = WatchFolderImportFailure.privacySafeMessage(error.localizedDescription, fileURL: item.url)
                    batchQueue.markFailed(item.id, message: safeMessage)
                    if watchFolderImportsInFlight.remove(item.url) != nil {
                        watchFolderFailures.removeAll { $0.id == item.url }
                        watchFolderFailures.append(WatchFolderImportFailure(url: item.url, message: safeMessage))
                    }
                    statusMessage = "Failed \(item.fileName): \(safeMessage)"
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

    var hasScreenCapturePermission: Bool {
        screenshotCaptureService.hasScreenCapturePermission
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
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
        let source = document
        let length = summaryLength
        guard useOnDeviceAI else {
            document.summary = explanationEngine.betterSummary(for: source, length: length)
            clearIntelligenceProvenance()
            return
        }

        // Foundation Models is asynchronous and availability varies by Mac.
        // Keep the deterministic summary visible until an opted-in result is
        // ready, and discard a late result if the document changed meanwhile.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.document.id == source.id else { return }
            let result = await self.explanationEngine.groundedIntelligenceSummary(for: source, length: length)
            switch result {
            case .generated(let grounded):
                self.document.summary = grounded.text
                self.document.summaryProvenance = grounded.provenance
                self.document.metadata["intelligenceSource"] = "apple-foundation-models"
                self.document.metadata["intelligenceEngine"] = "FoundationModels"
                self.document.metadata["intelligenceGeneratedAt"] = ISO8601DateFormatter().string(from: Date())
                self.document.metadata["intelligenceCitationCount"] = String(grounded.citations.count)
                self.document.metadata["intelligenceUncertaintyCount"] = String(grounded.uncertaintyNotes.count)
                self.document.metadata["intelligenceUnsupportedClaimCount"] = String(grounded.unsupportedClaims.count)
            case .unavailable, .failed:
                self.document.summary = self.explanationEngine.betterSummary(for: source, length: length)
                self.clearIntelligenceProvenance()
            }
        }
    }

    private func clearIntelligenceProvenance() {
        document.summaryProvenance = nil
        document.metadata.removeValue(forKey: "intelligenceSource")
        document.metadata.removeValue(forKey: "intelligenceEngine")
        document.metadata.removeValue(forKey: "intelligenceGeneratedAt")
        document.metadata.removeValue(forKey: "intelligenceCitationCount")
        document.metadata.removeValue(forKey: "intelligenceUncertaintyCount")
        document.metadata.removeValue(forKey: "intelligenceUnsupportedClaimCount")
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

    func openRecentDocument(id: UUID) {
        guard let selected = recentDocuments.first(where: { $0.id == id })
                ?? (try? persisting.load(id: id)) ?? nil else {
            statusMessage = "That document is no longer in the local library."
            return
        }
        selectRecentDocument(selected)
    }

    func updateBlock(_ block: TextBlock, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == block.pageNumber }),
              let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == block.id }) else {
            return
        }
        guard document.pages[pageIndex].blocks[blockIndex].text != text else { return }
        recordEdit("Edit block text")
        if document.pages[pageIndex].blocks[blockIndex].originalText == nil {
            document.pages[pageIndex].blocks[blockIndex].originalText = block.text
        }
        document.pages[pageIndex].blocks[blockIndex].text = text
        document.pages[pageIndex].blocks[blockIndex].provenance = BlockProvenance(
            source: .userEdit,
            pageNumber: block.pageNumber,
            bounds: block.bounds,
            confidence: document.pages[pageIndex].blocks[blockIndex].confidence,
            parentBlockID: block.id,
            engine: "PageLumen review editor"
        )
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func setBlockReviewed(_ block: TextBlock, isReviewed: Bool) {
        let currentDecision = DocumentEditing.reviewDecision(block)
        guard (isReviewed ? currentDecision != .accepted : currentDecision != .unreviewed) else { return }
        recordEdit("Change block review status")
        DocumentEditing.setBlockReviewed(id: block.id, isReviewed: isReviewed, in: &document)
        statusMessage = isReviewed ? "Marked block reviewed" : "Marked block for review"
    }

    func setSelectedPageReviewed(_ isReviewed: Bool) {
        guard let page = document.pages.first(where: { $0.pageNumber == selectedPageNumber }),
              page.blocks.contains(where: { DocumentEditing.isReviewed($0) != isReviewed }) else { return }
        recordEdit("Change page review status")
        DocumentEditing.setPageReviewed(pageNumber: selectedPageNumber, isReviewed: isReviewed, in: &document)
        statusMessage = isReviewed ? "Marked page \(selectedPageNumber) reviewed" : "Marked page \(selectedPageNumber) for review"
    }

    /// Copies only the requested block and a human-readable page/block
    /// citation. Source URLs and OCR metadata are intentionally excluded.
    func copyAccessibleExcerpt(_ block: TextBlock) {
        let quote = DocumentQuote.from(document: document, block: block)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(quote.accessibleExcerpt, forType: .string)
        statusMessage = "Copied accessible excerpt from page \(quote.pageNumber)"
    }

    /// Copies a grounded draft with explicit page/block citations. The draft
    /// is labelled as generated and never replaces extracted source content.
    func copySummaryWithCitations() {
        let grounded = explanationEngine.groundedSummary(for: document, length: summaryLength)
        var output = "Generated summary (verify against the original source):\n\(grounded.text)"
        if !grounded.citations.isEmpty {
            output += "\n\nSources:"
            for citation in grounded.citations {
                output += "\n- Page \(citation.pageNumber), block \(citation.blockID.uuidString): \(citation.excerpt)"
            }
        }
        if let warning = grounded.groundingWarning {
            output += "\n\nNote: \(warning)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        statusMessage = "Copied generated summary with \(grounded.citations.count) citation\(grounded.citations.count == 1 ? "" : "s")"
    }

    /// Creates a review-gated draft from the current grounded summary. The
    /// draft is held separately from extracted source and is never applied
    /// implicitly.
    func prepareReviewDraft() {
        reviewDraft = explanationEngine.groundedSummary(for: document, length: summaryLength)
        statusMessage = "Draft prepared for review; extracted source is unchanged"
    }

    func insertReviewDraftAsSummary() {
        guard let draft = reviewDraft else { return }
        recordEdit("Insert reviewed draft")
        document.summary = draft.text
        // Keep the accepted draft's typed model/session and cited source
        // locations. Deterministic drafts intentionally clear stale AI
        // provenance rather than claiming that a model generated them.
        document.summaryProvenance = draft.provenance
        reviewDraft = nil
        statusMessage = "Draft inserted as the document summary"
    }

    /// Replaces the selected block only after an explicit review action. This
    /// is intentionally limited to a selected block and retains undo history.
    func replaceSelectedDescriptionAfterReview() {
        guard let draft = reviewDraft,
              let selectedBlockID,
              let pageIndex = document.pages.firstIndex(where: { page in
                  page.blocks.contains { $0.id == selectedBlockID }
              }),
              let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == selectedBlockID }) else {
            statusMessage = "Select a source block before replacing its description"
            return
        }
        recordEdit("Replace selected description")
        document.pages[pageIndex].blocks[blockIndex].text = draft.text
        let sourceBlock = document.pages[pageIndex].blocks[blockIndex]
        let aiLineage = draft.provenance.flatMap {
            AIBlockLineage(contentKind: .description, provenance: $0)
        }
        document.pages[pageIndex].blocks[blockIndex].provenance = BlockProvenance(
            source: aiLineage == nil ? .userEdit : .appleIntelligence,
            pageNumber: sourceBlock.pageNumber,
            bounds: sourceBlock.bounds,
            confidence: sourceBlock.confidence,
            parentBlockID: sourceBlock.id,
            engine: aiLineage == nil ? "PageLumen review editor" : "apple-foundation-models",
            aiLineage: aiLineage
        )
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
        reviewDraft = nil
        statusMessage = "Reviewed draft replaced the selected description"
    }

    func discardReviewDraft() {
        guard reviewDraft != nil else { return }
        reviewDraft = nil
        statusMessage = "Draft discarded; extracted source is unchanged"
    }

    func changeBlockType(_ block: TextBlock, to type: BlockType) {
        guard block.type != type else { return }
        recordEdit("Change block type")
        DocumentEditing.changeBlockType(id: block.id, to: type, in: &document)
        if let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == block.pageNumber }),
           let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == block.id }) {
            document.pages[pageIndex].blocks[blockIndex].provenance = BlockProvenance(
                source: .userEdit,
                pageNumber: block.pageNumber,
                bounds: block.bounds,
                confidence: document.pages[pageIndex].blocks[blockIndex].confidence,
                parentBlockID: block.id,
                engine: "PageLumen review editor"
            )
        }
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
        statusMessage = "Changed block type to \(type.rawValue)"
    }

    func updateTableExplanation(_ table: TableRegion, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == table.pageNumber }),
              let tableIndex = document.pages[pageIndex].tables.firstIndex(where: { $0.id == table.id }) else {
            return
        }
        guard document.pages[pageIndex].tables[tableIndex].explanation != text else { return }
        recordEdit("Edit table explanation")
        document.pages[pageIndex].tables[tableIndex].explanation = text
        document.pages[pageIndex].tables[tableIndex].provenance = BlockProvenance(
            source: .userEdit,
            pageNumber: table.pageNumber,
            bounds: table.bounds,
            confidence: table.confidence,
            parentBlockID: table.id,
            engine: "PageLumen review editor"
        )
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func updateTableHeaderAssignments(_ table: TableRegion, columnHeaderRows: [Int], rowHeaderColumns: [Int]) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == table.pageNumber }),
              let tableIndex = document.pages[pageIndex].tables.firstIndex(where: { $0.id == table.id }) else {
            return
        }
        let validRowIndexes = Set(document.pages[pageIndex].tables[tableIndex].rows.indices)
        let maxColumnCount = document.pages[pageIndex].tables[tableIndex].rows.map(\.count).max() ?? 0
        let validColumnIndexes = Set(0..<maxColumnCount)
        let rows = Array(Set(columnHeaderRows.filter { validRowIndexes.contains($0) })).sorted()
        let columns = Array(Set(rowHeaderColumns.filter { validColumnIndexes.contains($0) })).sorted()
        guard document.pages[pageIndex].tables[tableIndex].columnHeaderRows != rows
                || document.pages[pageIndex].tables[tableIndex].rowHeaderColumns != columns else { return }
        recordEdit("Assign table headers")
        document.pages[pageIndex].tables[tableIndex].columnHeaderRows = rows
        document.pages[pageIndex].tables[tableIndex].rowHeaderColumns = columns
        document.pages[pageIndex].tables[tableIndex].provenance = BlockProvenance(
            source: .userEdit,
            pageNumber: table.pageNumber,
            bounds: table.bounds,
            confidence: table.confidence,
            parentBlockID: table.id,
            engine: "PageLumen table semantics editor"
        )
        statusMessage = "Updated table header assignments"
    }

    func updateTableCell(_ table: TableRegion, row: Int, column: Int, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == table.pageNumber }),
              let tableIndex = document.pages[pageIndex].tables.firstIndex(where: { $0.id == table.id }),
              document.pages[pageIndex].tables[tableIndex].rows.indices.contains(row),
              document.pages[pageIndex].tables[tableIndex].rows[row].indices.contains(column) else {
            return
        }
        guard document.pages[pageIndex].tables[tableIndex].rows[row][column] != text else { return }
        recordEdit("Edit table cell")
        document.pages[pageIndex].tables[tableIndex].rows[row][column] = text
        document.pages[pageIndex].tables[tableIndex].provenance = BlockProvenance(
            source: .userEdit,
            pageNumber: table.pageNumber,
            bounds: table.bounds,
            confidence: table.confidence,
            parentBlockID: table.id,
            engine: "PageLumen table cell editor"
        )
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func updateFigureDescription(_ figure: FigureRegion, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == figure.pageNumber }),
              let figureIndex = document.pages[pageIndex].figures.firstIndex(where: { $0.id == figure.id }) else {
            return
        }
        guard document.pages[pageIndex].figures[figureIndex].description != text else { return }
        recordEdit("Edit figure description")
        document.pages[pageIndex].figures[figureIndex].description = text
        document.pages[pageIndex].figures[figureIndex].provenance = BlockProvenance(
            source: .userEdit,
            pageNumber: figure.pageNumber,
            bounds: figure.bounds,
            confidence: figure.confidence,
            parentBlockID: figure.id,
            engine: "PageLumen review editor"
        )
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func moveBlock(_ block: TextBlock, direction: BlockMoveDirection) {
        recordEdit("Reorder block")
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

        recordEdit("Reorder block")
        let block = document.pages[pageIndex].blocks.remove(at: sourceIndex)
        document.pages[pageIndex].blocks.insert(block, at: clampedDestination)
        DocumentEditing.renumberBlocks(on: &document.pages[pageIndex])
        document.summary = explanationEngine.betterSummary(for: document, length: summaryLength)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        refreshEditHistoryState()
        statusMessage = "Undid last edit"
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        refreshEditHistoryState()
        statusMessage = "Redid last edit"
    }

    private func recordEdit(_ label: String) {
        undoStack.append(document)
        if undoStack.count > Self.editHistoryLimit {
            undoStack.removeFirst(undoStack.count - Self.editHistoryLimit)
        }
        redoStack.removeAll(keepingCapacity: true)
        editHistory.append(EditHistoryEntry(label: label))
        if editHistory.count > Self.editHistoryLimit {
            editHistory.removeFirst(editHistory.count - Self.editHistoryLimit)
        }
        refreshEditHistoryState()
    }

    private func refreshEditHistoryState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
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
    // preview (format + export option booleans + a content fingerprint).
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
        hasher.combine(options.includeProvenance)
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

    func canExport(_ format: ExportFormat) -> Bool {
        guard format == .translated else {
            guard !document.pages.isEmpty && !isProcessing else { return false }
            if [.html, .taggedHTML, .pdf].contains(format) {
                return exportEngine.validate(document: document, format: format, options: exportOptions).canExport
            }
            return true
        }
        guard !privacyMode, !document.pages.isEmpty, !isProcessing else { return false }
        let target = Self.targetLanguageFromDefaults()
        return TranslationService().availability(for: target) == .available
    }

    func exportAvailabilityMessage(for format: ExportFormat) -> String {
        guard format == .translated else {
            return canExport(format) ? "Save \(format.rawValue)" : "Import and finish processing a document first"
        }
        if privacyMode { return "Disable Privacy mode to use translation export" }
        switch TranslationService().availability(for: Self.targetLanguageFromDefaults()) {
        case .available:
            return "Translate the document and save Markdown"
        case .downloadable:
            return "Download and approve the language model before translating"
        case .unsupported:
            return "Translation export requires macOS 26 or later"
        case .unavailable:
            return "Translation is unavailable for the selected language on this Mac"
        }
    }

    var canUseStirlingCompression: Bool {
        guard UserDefaults.standard.bool(forKey: "stirlingPDFEnabled"), !privacyMode, !document.pages.isEmpty, !isProcessing else {
            return false
        }
        return stirlingPDFEndpoint?.capabilityState == .loopback || stirlingPDFEndpoint?.capabilityState == .remoteHTTPSAdvancedOptIn
    }

    var stirlingCompressionAvailabilityMessage: String {
        if privacyMode { return "Disable Privacy mode before sending a PDF to Stirling-PDF" }
        guard UserDefaults.standard.bool(forKey: "stirlingPDFEnabled") else { return "Enable Stirling-PDF in Settings first" }
        guard let endpoint = stirlingPDFEndpoint else { return "Configure a valid Stirling-PDF endpoint in Settings" }
        switch endpoint.capabilityState {
        case .loopback: return "Compress a generated Readable PDF through the local Stirling-PDF service"
        case .remoteHTTPSAdvancedOptIn: return "Compress through the explicitly approved remote HTTPS service"
        default: return endpoint.capabilityState.userMessage
        }
    }

    /// Compresses a generated Readable PDF only after the confirmation dialog
    /// has made the endpoint, upload boundary, and replacement behavior clear.
    /// The output is saved separately; the source document is never replaced.
    func compressReadablePDFWithStirling(confirmed: Bool) {
        guard confirmed else {
            statusMessage = "Stirling-PDF compression requires explicit confirmation."
            return
        }
        guard !isStirlingOperationInFlight, canUseStirlingCompression, let endpoint = stirlingPDFEndpoint else {
            statusMessage = stirlingCompressionAvailabilityMessage
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(document.title)-compressed.pdf"
        panel.message = "Save a separately compressed copy. The original document will not be replaced."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let sourceData = exportEngine.data(for: document, format: .pdf, options: exportOptions)
        let authorization = StirlingPDFOperationAuthorization(privacyModeEnabled: privacyMode, operationConfirmed: confirmed)
        statusMessage = "Compressing a copy through Stirling-PDF…"
        isStirlingOperationInFlight = true
        stirlingOperationTask = Task { @MainActor in
            defer {
                isStirlingOperationInFlight = false
                stirlingOperationTask = nil
            }
            do {
                let result = try await StirlingPDFOperationsProvider(endpoint: endpoint, authorization: authorization).execute(
                    PDFOperationRequest(operation: .compress, documents: [(data: sourceData, filename: "\(document.title).pdf")])
                )
                try result.data.write(to: url, options: .atomic)
                statusMessage = "Saved compressed PDF copy to \(url.lastPathComponent)"
            } catch {
                statusMessage = Task.isCancelled ? "Stirling-PDF compression cancelled." : "Stirling-PDF compression failed: \(error.localizedDescription)"
            }
        }
    }

    /// Merges the current generated PDF with user-selected PDFs only after an
    /// explicit confirmation. The selected inputs are read once, sent through
    /// the bounded provider, validated there, and saved as a new file.
    func mergeReadablePDFWithStirling(confirmed: Bool) {
        guard confirmed else {
            statusMessage = "Stirling-PDF merge requires explicit confirmation."
            return
        }
        guard !isStirlingOperationInFlight, canUseStirlingCompression, let endpoint = stirlingPDFEndpoint else {
            statusMessage = stirlingCompressionAvailabilityMessage
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.message = "Choose one or more PDFs to append after the current generated document."
        guard openPanel.runModal() == .OK, !openPanel.urls.isEmpty else { return }

        let currentData = exportEngine.data(for: document, format: .pdf, options: exportOptions)
        do {
            let selected = try openPanel.urls.map { url in
                (data: try Data(contentsOf: url), filename: url.lastPathComponent)
            }
            let inputs = [(data: currentData, filename: "\(document.title).pdf")] + selected
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "\(document.title)-merged.pdf"
            panel.message = "Save a separately merged PDF copy. The original document and selected files will not be replaced."
            guard panel.runModal() == .OK, let outputURL = panel.url else { return }

            let authorization = StirlingPDFOperationAuthorization(privacyModeEnabled: privacyMode, operationConfirmed: confirmed)
            statusMessage = "Merging \(selected.count + 1) PDFs through Stirling-PDF…"
            isStirlingOperationInFlight = true
            stirlingOperationTask = Task { @MainActor in
                defer {
                    isStirlingOperationInFlight = false
                    stirlingOperationTask = nil
                }
                do {
                    let result = try await StirlingPDFOperationsProvider(endpoint: endpoint, authorization: authorization).execute(
                        PDFOperationRequest(operation: .merge, documents: inputs)
                    )
                    try result.data.write(to: outputURL, options: .atomic)
                    statusMessage = "Saved merged PDF copy to \(outputURL.lastPathComponent)"
                } catch {
                    statusMessage = Task.isCancelled ? "Stirling-PDF merge cancelled." : "Stirling-PDF merge failed: \(error.localizedDescription)"
                }
            }
        } catch {
            statusMessage = "Could not read a selected PDF: \(error.localizedDescription)"
        }
    }

    func cancelStirlingOperation() {
        guard isStirlingOperationInFlight else { return }
        stirlingOperationTask?.cancel()
        statusMessage = "Cancelling Stirling-PDF operation…"
    }

    private var stirlingPDFEndpoint: StirlingPDFEndpoint? {
        let raw = UserDefaults.standard.string(forKey: "stirlingPDFEndpoint")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = URL(string: raw), !raw.isEmpty else { return nil }
        let allowRemoteHTTPS = UserDefaults.standard.bool(forKey: "stirlingPDFAllowRemoteHTTPS")
        return StirlingPDFEndpoint(baseURL: url, allowRemoteHTTPS: allowRemoteHTTPS)
    }

    private func exportTranslated() {
        guard !privacyMode else {
            statusMessage = "Translated export is disabled in Privacy mode."
            return
        }
        let targetLanguage = Self.targetLanguageFromDefaults()
        guard TranslationService().availability(for: targetLanguage) == .available else {
            statusMessage = exportAvailabilityMessage(for: .translated)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = []
        panel.nameFieldStringValue = "\(document.title).md"
        panel.message = "Translate the document to the language chosen in Settings, then export as Markdown."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let options = exportOptions
        let sourceDocument = document

        Task { @MainActor in
            do {
                let translatedDoc = try await TranslationService().translate(document: sourceDocument, to: targetLanguage)
                let markdown = ExportEngine().markdown(for: translatedDoc, options: options)
                let data = Data(markdown.utf8)
                try data.write(to: url, options: .atomic)
                statusMessage = "Exported translated Markdown to \(url.lastPathComponent)"
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
        let validation = exportEngine.validate(document: document, format: format, options: exportOptions)
        guard validation.canExport else {
            let firstFinding = validation.findings.first(where: { $0.hasPrefix("[Needs fix]") })
            statusMessage = firstFinding.map { "Export blocked: \($0.replacingOccurrences(of: "[Needs fix] ", with: ""))" }
                ?? "Export is unavailable until the document review requirements are complete."
            return
        }
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
        guard canExport(.audio), !isExportingAudio else {
            statusMessage = exportAvailabilityMessage(for: .audio)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.audio]
        panel.nameFieldStringValue = "\(document.title).m4a"
        panel.message = "Export the spoken summary as an .m4a file."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        isExportingAudio = true
        audioExportProgress = AudioExportProgress(fractionCompleted: 0, phase: .preparing)
        statusMessage = "Synthesizing audio summary..."
        audioExportTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isExportingAudio = false
                self.audioExportProgress = AudioExportProgress(fractionCompleted: 0, phase: .preparing)
                self.audioExportTask = nil
            }
            do {
                let textToSpeak = self.document.summary.isEmpty
                    ? self.fullExtractedText()
                    : self.document.summary
                let defaults = UserDefaults.standard
                let configuredVoice = defaults.string(forKey: "speechVoiceIdentifier")
                let voiceIdentifier = configuredVoice == nil || configuredVoice == "default" || configuredVoice == "personal"
                    ? nil
                    : configuredVoice
                let language = self.document.language.map { Locale(identifier: $0).identifier } ?? "en-US"
                try await self.audioExportService.export(
                    text: textToSpeak,
                    to: url,
                    language: language,
                    voiceIdentifier: voiceIdentifier,
                    onProgress: { [weak self] progress in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.audioExportProgress = progress
                            switch progress.phase {
                            case .preparing:
                                self.statusMessage = "Preparing audio export..."
                            case .synthesizing:
                                self.statusMessage = "Synthesizing audio summary..."
                            case .completed:
                                self.statusMessage = "Finalizing audio export..."
                            case .cancelled:
                                self.statusMessage = "Audio export cancelled"
                            }
                        }
                    }
                )
                self.statusMessage = "Exported Audio to \(url.lastPathComponent)"
            } catch is CancellationError {
                self.statusMessage = "Audio export cancelled"
            } catch AudioExportError.cancelled {
                self.statusMessage = "Audio export cancelled"
            } catch {
                self.statusMessage = "Audio export failed: \(error.localizedDescription)"
            }
        }
    }

    func cancelAudioExport() {
        guard isExportingAudio else { return }
        audioExportService.cancel()
        audioExportTask?.cancel()
        audioExportTask = nil
        isExportingAudio = false
        statusMessage = "Audio export cancelled"
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
