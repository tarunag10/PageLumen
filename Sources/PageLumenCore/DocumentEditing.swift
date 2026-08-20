import Foundation

public enum ReviewPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case general = "General"
    case legal = "Legal"
    case academic = "Academic"
    case receipts = "Receipts"
    case slides = "Slides"
    case accessibility = "Accessibility Remediation"

    public var id: String { rawValue }

    public var lowConfidenceThreshold: Double {
        switch self {
        case .general: return 0.70
        case .legal: return 0.85
        case .academic: return 0.75
        case .receipts: return 0.80
        case .slides: return 0.65
        case .accessibility: return 0.90
        }
    }

    public var explanation: String {
        switch self {
        case .general: return "Balanced confidence and structure checks."
        case .legal: return "Flags lower-confidence text aggressively for source verification."
        case .academic: return "Prioritises citations, headings, and moderate OCR uncertainty."
        case .receipts: return "Flags uncertain key-value and numeric extraction."
        case .slides: return "Allows sparse slide text while retaining structure warnings."
        case .accessibility: return "Uses the strictest confidence threshold for remediation work."
        }
    }
}

public enum BlockMoveDirection: Sendable {
    case up
    case down
}

public enum ReviewIssueKind: String, Codable, Equatable, Sendable {
    case pageWarning
    case lowConfidence
    case unknownBlockType
    case unreviewedTableOrFigure
    case conflictingExtractionSources
    case unresolvedTableHeaders
    case missingImageDescription
    case unreviewedAIContribution
}

/// The action-oriented category used to order the review queue.  Categories
/// are intentionally independent from `ReviewIssueKind`: the latter is a
/// compatibility-facing description of how a finding was detected, while
/// this vocabulary describes the risk a reviewer should address first.
public enum ReviewFindingCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case unreadablePage
    case missingStructure
    case lowConfidence
    case conflictingExtractionSources
    case unresolvedTableHeaders
    case missingImageDescription
    case unreviewedAIContribution
    case other

    /// Lower values are surfaced first. Keep this order explicit and stable
    /// so queue order does not vary with dictionary, task, or page iteration.
    public var priority: Int {
        switch self {
        case .unreadablePage: return 0
        case .missingStructure: return 1
        case .lowConfidence: return 2
        case .conflictingExtractionSources: return 3
        case .unresolvedTableHeaders: return 4
        case .missingImageDescription: return 5
        case .unreviewedAIContribution: return 6
        case .other: return 7
        }
    }

    public var displayName: String {
        switch self {
        case .unreadablePage: return "Unreadable page"
        case .missingStructure: return "Missing structure"
        case .lowConfidence: return "Low confidence"
        case .conflictingExtractionSources: return "Conflicting extraction sources"
        case .unresolvedTableHeaders: return "Unresolved table headers"
        case .missingImageDescription: return "Missing image description"
        case .unreviewedAIContribution: return "Unreviewed AI contribution"
        case .other: return "Other review item"
        }
    }
}

public enum ReviewFindingSeverity: String, Codable, Equatable, Sendable, CaseIterable {
    case blocker
    case warning
    case info
}

public enum ReviewFindingSource: String, Codable, Equatable, Sendable {
    case embeddedPDF
    case visionOCR
    case heuristic
    case userEdit
    case appleIntelligence
}

public enum ReviewDecision: String, Codable, Equatable, Sendable {
    case unreviewed
    case accepted
    case rejected
}

/// Typed provenance for a finding. Source excerpts remain outside this model;
/// callers can resolve the page/block location without duplicating OCR text.
public struct ReviewFindingProvenance: Codable, Equatable, Sendable {
    public var source: ReviewFindingSource
    public var pageNumber: Int
    public var bounds: BoundingBox?
    public var parentBlockID: UUID?
    public var createdAt: Date

    public init(
        source: ReviewFindingSource,
        pageNumber: Int,
        bounds: BoundingBox? = nil,
        parentBlockID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.source = source
        self.pageNumber = pageNumber
        self.bounds = bounds
        self.parentBlockID = parentBlockID
        self.createdAt = createdAt
    }
}

/// A normalized review finding that can be persisted or rendered by any UI.
/// `ReviewIssue` remains as the compatibility-facing view model used by the
/// current SwiftUI shell.
public struct ReviewFinding: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: ReviewIssueKind
    public var category: ReviewFindingCategory
    public var severity: ReviewFindingSeverity
    public var pageNumber: Int
    public var blockID: UUID?
    public var title: String
    public var detail: String
    public var isResolved: Bool
    public var decision: ReviewDecision
    public var provenance: ReviewFindingProvenance?

    public init(
        id: String,
        kind: ReviewIssueKind,
        category: ReviewFindingCategory? = nil,
        severity: ReviewFindingSeverity,
        pageNumber: Int,
        blockID: UUID? = nil,
        title: String,
        detail: String,
        isResolved: Bool = false,
        decision: ReviewDecision = .unreviewed,
        provenance: ReviewFindingProvenance? = nil
    ) {
        self.id = id
        self.kind = kind
        self.category = category ?? ReviewFindingCategory(categoryFor: kind)
        self.severity = severity
        self.pageNumber = pageNumber
        self.blockID = blockID
        self.title = title
        self.detail = detail
        self.isResolved = isResolved
        self.decision = decision
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, category, severity, pageNumber, blockID, title, detail, isResolved, decision, provenance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(ReviewIssueKind.self, forKey: .kind)
        category = try container.decodeIfPresent(ReviewFindingCategory.self, forKey: .category)
            ?? ReviewFindingCategory(categoryFor: kind)
        severity = try container.decode(ReviewFindingSeverity.self, forKey: .severity)
        pageNumber = try container.decode(Int.self, forKey: .pageNumber)
        blockID = try container.decodeIfPresent(UUID.self, forKey: .blockID)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        isResolved = try container.decodeIfPresent(Bool.self, forKey: .isResolved) ?? false
        decision = try container.decodeIfPresent(ReviewDecision.self, forKey: .decision) ?? .unreviewed
        provenance = try container.decodeIfPresent(ReviewFindingProvenance.self, forKey: .provenance)
    }
}

private extension ReviewFindingCategory {
    init(categoryFor kind: ReviewIssueKind) {
        switch kind {
        case .pageWarning: self = .unreadablePage
        case .unknownBlockType, .unreviewedTableOrFigure: self = .missingStructure
        case .lowConfidence: self = .lowConfidence
        case .conflictingExtractionSources: self = .conflictingExtractionSources
        case .unresolvedTableHeaders: self = .unresolvedTableHeaders
        case .missingImageDescription: self = .missingImageDescription
        case .unreviewedAIContribution: self = .unreviewedAIContribution
        }
    }
}

public struct ReviewIssue: Identifiable, Equatable, Sendable {
    public var id: String
    public var kind: ReviewIssueKind
    public var pageNumber: Int
    public var blockID: UUID?
    public var title: String
    public var detail: String

    public init(kind: ReviewIssueKind, pageNumber: Int, blockID: UUID? = nil, title: String, detail: String) {
        self.kind = kind
        self.pageNumber = pageNumber
        self.blockID = blockID
        self.title = title
        self.detail = detail
        self.id = "\(kind.rawValue)-\(pageNumber)-\(blockID?.uuidString ?? title)"
    }
}

public struct ReviewProgress: Equatable, Sendable {
    public var reviewedBlocks: Int
    public var totalBlocks: Int
    public var issueCount: Int

    public var fractionComplete: Double {
        guard totalBlocks > 0 else { return 1 }
        return Double(reviewedBlocks) / Double(totalBlocks)
    }

    public var label: String {
        "\(reviewedBlocks) of \(totalBlocks) blocks reviewed"
    }
}

public enum DocumentEditing {
    private static let reviewStatusKey = "reviewStatus"
    private static let reviewedValue = "reviewed"
    private static let reviewDecisionKey = "reviewDecision"

    public static func moveBlock(id: UUID, direction: BlockMoveDirection, in document: inout ReaderDocument) {
        guard let pageIndex = document.pages.firstIndex(where: { page in
            page.blocks.contains(where: { $0.id == id })
        }),
        let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex: Int
        switch direction {
        case .up:
            destinationIndex = max(blockIndex - 1, 0)
        case .down:
            destinationIndex = min(blockIndex + 1, document.pages[pageIndex].blocks.count - 1)
        }

        guard destinationIndex != blockIndex else {
            return
        }

        document.pages[pageIndex].blocks.swapAt(blockIndex, destinationIndex)
        renumberBlocks(on: &document.pages[pageIndex])
    }

    public static func setBlockReviewed(id: UUID, isReviewed: Bool, in document: inout ReaderDocument) {
        guard let location = blockLocation(id: id, in: document) else {
            return
        }

        if isReviewed {
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata[reviewStatusKey] = reviewedValue
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata[reviewDecisionKey] = ReviewDecision.accepted.rawValue
        } else {
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata.removeValue(forKey: reviewStatusKey)
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata.removeValue(forKey: reviewDecisionKey)
        }
    }

    public static func setReviewDecision(id: UUID, decision: ReviewDecision, in document: inout ReaderDocument) {
        guard let location = blockLocation(id: id, in: document) else { return }
        switch decision {
        case .unreviewed:
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata.removeValue(forKey: reviewDecisionKey)
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata.removeValue(forKey: reviewStatusKey)
        case .accepted:
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata[reviewDecisionKey] = decision.rawValue
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata[reviewStatusKey] = reviewedValue
        case .rejected:
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata[reviewDecisionKey] = decision.rawValue
            document.pages[location.pageIndex].blocks[location.blockIndex].metadata.removeValue(forKey: reviewStatusKey)
        }
    }

    public static func setPageReviewed(pageNumber: Int, isReviewed: Bool, in document: inout ReaderDocument) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == pageNumber }) else {
            return
        }

        for blockIndex in document.pages[pageIndex].blocks.indices {
            if isReviewed {
                document.pages[pageIndex].blocks[blockIndex].metadata[reviewStatusKey] = reviewedValue
                document.pages[pageIndex].blocks[blockIndex].metadata[reviewDecisionKey] = ReviewDecision.accepted.rawValue
            } else {
                document.pages[pageIndex].blocks[blockIndex].metadata.removeValue(forKey: reviewStatusKey)
                document.pages[pageIndex].blocks[blockIndex].metadata.removeValue(forKey: reviewDecisionKey)
            }
        }
    }

    public static func changeBlockType(id: UUID, to type: BlockType, in document: inout ReaderDocument) {
        guard let location = blockLocation(id: id, in: document) else {
            return
        }

        document.pages[location.pageIndex].blocks[location.blockIndex].type = type
        document.pages[location.pageIndex].blocks[location.blockIndex].contentRole = ContentRole(legacyType: type)
        rebuildOutline(in: &document)
    }

    public static func fullText(for document: ReaderDocument, includeHeadersAndFooters: Bool) -> String {
        document.pages
            .flatMap { exportableBlocks(on: $0, includeHeadersAndFooters: includeHeadersAndFooters) }
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    public static func exportableBlocks(on page: ReaderPage, includeHeadersAndFooters: Bool) -> [TextBlock] {
        let sorted = page.blocks.sorted { lhs, rhs in
            lhs.readingOrderIndex < rhs.readingOrderIndex
        }

        if includeHeadersAndFooters {
            return sorted
        }

        return sorted.filter { block in
            block.type != .header && block.type != .footer
        }
    }

    public static func reviewIssues(for document: ReaderDocument, preset: ReviewPreset = .general) -> [ReviewIssue] {
        document.pages.flatMap { page in
            var issues: [ReviewIssue] = []
            if let warning = page.warning {
                issues.append(ReviewIssue(kind: .pageWarning, pageNumber: page.pageNumber, title: "Page warning", detail: warning))
            } else if page.ocrStatus == .failed || page.blocks.isEmpty {
                issues.append(ReviewIssue(kind: .pageWarning, pageNumber: page.pageNumber, title: "Unreadable page", detail: "No reliable extracted content is available. Verify the original page or retry extraction."))
            }

            for block in page.blocks.sorted(by: { $0.readingOrderIndex < $1.readingOrderIndex }) {
                guard !isReviewed(block), reviewDecision(block) != .rejected else {
                    continue
                }

                if block.type == .unknown {
                    issues.append(ReviewIssue(kind: .unknownBlockType, pageNumber: page.pageNumber, blockID: block.id, title: "Unknown block type", detail: previewText(block.text)))
                } else if block.confidence < preset.lowConfidenceThreshold {
                    issues.append(ReviewIssue(kind: .lowConfidence, pageNumber: page.pageNumber, blockID: block.id, title: "Low OCR confidence", detail: "\(Int(block.confidence * 100))% confidence: \(previewText(block.text))"))
                } else if block.type == .table || block.type == .figure {
                    if block.type == .table,
                       let table = page.tables.first(where: { $0.bounds == block.bounds }),
                       !table.rows.isEmpty,
                       table.columnHeaderRows.isEmpty {
                        issues.append(ReviewIssue(kind: .unresolvedTableHeaders, pageNumber: page.pageNumber, blockID: block.id, title: "Unresolved table headers", detail: "Assign column or row headers before publishing this table."))
                    } else if block.type == .figure,
                              let figure = page.figures.first(where: { $0.bounds == block.bounds }),
                              figure.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(ReviewIssue(kind: .missingImageDescription, pageNumber: page.pageNumber, blockID: block.id, title: "Missing image description", detail: "Add a concise description for assistive technology."))
                    } else {
                        issues.append(ReviewIssue(kind: .unreviewedTableOrFigure, pageNumber: page.pageNumber, blockID: block.id, title: "Review generated structure", detail: previewText(block.text)))
                    }
                }

                if hasConflictingExtractionSources(block) {
                    issues.append(ReviewIssue(kind: .conflictingExtractionSources, pageNumber: page.pageNumber, blockID: block.id, title: "Conflicting extraction sources", detail: "Extraction sources disagree for this block. Verify it against the original page."))
                }

                if hasUnreviewedAIContribution(block) {
                    issues.append(ReviewIssue(kind: .unreviewedAIContribution, pageNumber: page.pageNumber, blockID: block.id, title: "Unreviewed AI contribution", detail: "Review the generated contribution against the cited source before accepting it."))
                }
            }

            // Preserve findings even when a typed table or figure has no
            // corresponding text block (for example, a structure-only PDF).
            for table in page.tables where table.rows.count > 0 && table.columnHeaderRows.isEmpty {
                guard !page.blocks.contains(where: { $0.type == .table && $0.bounds == table.bounds }) else { continue }
                issues.append(ReviewIssue(kind: .unresolvedTableHeaders, pageNumber: page.pageNumber, title: "Unresolved table headers", detail: "Assign column or row headers before publishing this table."))
            }
            for figure in page.figures where figure.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard !page.blocks.contains(where: { $0.type == .figure && $0.bounds == figure.bounds }) else { continue }
                issues.append(ReviewIssue(kind: .missingImageDescription, pageNumber: page.pageNumber, title: "Missing image description", detail: "Add a concise description for assistive technology."))
            }
            return issues
        }
    }

    public static func reviewFindings(for document: ReaderDocument, preset: ReviewPreset = .general) -> [ReviewFinding] {
        let findings = reviewIssues(for: document, preset: preset).map { issue in
            let severity: ReviewFindingSeverity
            switch issue.kind {
            case .pageWarning, .unknownBlockType, .conflictingExtractionSources:
                severity = .blocker
            case .lowConfidence, .unreviewedTableOrFigure, .unresolvedTableHeaders, .missingImageDescription, .unreviewedAIContribution:
                severity = .warning
            }
            let block = issue.blockID.flatMap { id in document.allBlocks.first { $0.id == id } }
            let decision = block.map(reviewDecision) ?? .unreviewed
            let source: ReviewFindingSource = {
                if let provenance = block?.provenance {
                    switch provenance.source {
                    case .embeddedPDF: return .embeddedPDF
                    case .visionOCR: return .visionOCR
                    case .userEdit: return .userEdit
                    case .appleIntelligence: return .appleIntelligence
                    case .heuristic: return .heuristic
                    }
                }
                switch block?.blockSource {
                case .embeddedPDF: return .embeddedPDF
                case .visionOCR: return .visionOCR
                case .userEdited: return .userEdit
                default: return .heuristic
                }
            }()
            return ReviewFinding(
                id: issue.id,
                kind: issue.kind,
                category: ReviewFindingCategory(categoryFor: issue.kind),
                severity: severity,
                pageNumber: issue.pageNumber,
                blockID: issue.blockID,
                title: issue.title,
                detail: issue.detail,
                isResolved: decision != .unreviewed || (block.map(isReviewed) ?? false),
                decision: decision,
                provenance: ReviewFindingProvenance(
                    source: source,
                    pageNumber: issue.pageNumber,
                    bounds: block?.bounds,
                    parentBlockID: issue.blockID
                )
            )
        }

        // Category rank is the primary key. Page and reading order are only
        // tie-breakers, making repeated runs stable while preserving the
        // existing source navigation destinations and decisions.
        return findings.sorted { lhs, rhs in
            if lhs.category.priority != rhs.category.priority {
                return lhs.category.priority < rhs.category.priority
            }
            let lhsSeverity = severityRank(lhs.severity)
            let rhsSeverity = severityRank(rhs.severity)
            if lhsSeverity != rhsSeverity { return lhsSeverity < rhsSeverity }
            if lhs.pageNumber != rhs.pageNumber { return lhs.pageNumber < rhs.pageNumber }
            let lhsOrder = lhs.blockID.flatMap { id in document.allBlocks.first(where: { $0.id == id })?.readingOrderIndex } ?? Int.max
            let rhsOrder = rhs.blockID.flatMap { id in document.allBlocks.first(where: { $0.id == id })?.readingOrderIndex } ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.id < rhs.id
        }
    }

    public static func reviewProgress(for document: ReaderDocument, preset: ReviewPreset = .general) -> ReviewProgress {
        let blocks = document.allBlocks
        return ReviewProgress(
            reviewedBlocks: blocks.filter(isReviewed).count,
            totalBlocks: blocks.count,
            issueCount: reviewIssues(for: document, preset: preset).count
        )
    }

    public static func exportPreview(for document: ReaderDocument, format: ExportFormat, options: ExportOptions, maxCharacters: Int = 4_000) -> String {
        let data = ExportEngine().data(for: document, format: format, options: options)
        let text = String(data: data, encoding: .utf8) ?? ""
        guard text.count > maxCharacters else {
            return text
        }
        return String(text.prefix(maxCharacters))
    }

    public static func renumberBlocks(on page: inout ReaderPage) {
        for index in page.blocks.indices {
            page.blocks[index].readingOrderIndex = index
        }
    }

    public static func isReviewed(_ block: TextBlock) -> Bool {
        block.metadata[reviewStatusKey] == reviewedValue
    }

    public static func reviewDecision(_ block: TextBlock) -> ReviewDecision {
        ReviewDecision(rawValue: block.metadata[reviewDecisionKey] ?? "") ?? .unreviewed
    }

    private static func blockLocation(id: UUID, in document: ReaderDocument) -> (pageIndex: Int, blockIndex: Int)? {
        guard let pageIndex = document.pages.firstIndex(where: { page in
            page.blocks.contains(where: { $0.id == id })
        }),
        let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return (pageIndex, blockIndex)
    }

    private static func rebuildOutline(in document: inout ReaderDocument) {
        document.outline = document.pages.flatMap { page in
            page.blocks
                .filter { $0.type == .heading }
                .sorted { $0.readingOrderIndex < $1.readingOrderIndex }
                .map { OutlineItem(title: $0.text, pageNumber: page.pageNumber) }
        }
    }

    private static func previewText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 90 else {
            return trimmed
        }
        return "\(trimmed.prefix(90))..."
    }

    private static func severityRank(_ severity: ReviewFindingSeverity) -> Int {
        switch severity {
        case .blocker: return 0
        case .warning: return 1
        case .info: return 2
        }
    }

    private static func hasConflictingExtractionSources(_ block: TextBlock) -> Bool {
        guard let declared = block.blockSource, let provenance = block.provenance else { return false }
        switch (declared, provenance.source) {
        case (.embeddedPDF, .embeddedPDF), (.visionOCR, .visionOCR), (.userEdited, .userEdit):
            return false
        case (_, .heuristic):
            // Heuristics derive structure from either source and are not a
            // second extraction source by themselves.
            return false
        default:
            return true
        }
    }

    private static func hasUnreviewedAIContribution(_ block: TextBlock) -> Bool {
        if block.provenance?.source == .appleIntelligence { return true }
        let values = block.metadata.reduce(into: Set<String>()) { result, pair in
            result.insert(pair.key.lowercased())
            result.insert(pair.value.lowercased())
        }
        return values.contains("ai") || values.contains("apple-intelligence") || values.contains("appleintelligence") || values.contains("ai-contribution")
    }
}
