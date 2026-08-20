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
    public var severity: ReviewFindingSeverity
    public var pageNumber: Int
    public var blockID: UUID?
    public var title: String
    public var detail: String
    public var isResolved: Bool
    public var provenance: ReviewFindingProvenance?

    public init(
        id: String,
        kind: ReviewIssueKind,
        severity: ReviewFindingSeverity,
        pageNumber: Int,
        blockID: UUID? = nil,
        title: String,
        detail: String,
        isResolved: Bool = false,
        provenance: ReviewFindingProvenance? = nil
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.pageNumber = pageNumber
        self.blockID = blockID
        self.title = title
        self.detail = detail
        self.isResolved = isResolved
        self.provenance = provenance
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
        } else {
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
            } else {
                document.pages[pageIndex].blocks[blockIndex].metadata.removeValue(forKey: reviewStatusKey)
            }
        }
    }

    public static func changeBlockType(id: UUID, to type: BlockType, in document: inout ReaderDocument) {
        guard let location = blockLocation(id: id, in: document) else {
            return
        }

        document.pages[location.pageIndex].blocks[location.blockIndex].type = type
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
            }

            for block in page.blocks.sorted(by: { $0.readingOrderIndex < $1.readingOrderIndex }) {
                guard !isReviewed(block) else {
                    continue
                }

                if block.type == .unknown {
                    issues.append(ReviewIssue(kind: .unknownBlockType, pageNumber: page.pageNumber, blockID: block.id, title: "Unknown block type", detail: previewText(block.text)))
                } else if block.confidence < preset.lowConfidenceThreshold {
                    issues.append(ReviewIssue(kind: .lowConfidence, pageNumber: page.pageNumber, blockID: block.id, title: "Low OCR confidence", detail: "\(Int(block.confidence * 100))% confidence: \(previewText(block.text))"))
                } else if block.type == .table || block.type == .figure {
                    issues.append(ReviewIssue(kind: .unreviewedTableOrFigure, pageNumber: page.pageNumber, blockID: block.id, title: "Review generated structure", detail: previewText(block.text)))
                }
            }
            return issues
        }
    }

    public static func reviewFindings(for document: ReaderDocument, preset: ReviewPreset = .general) -> [ReviewFinding] {
        reviewIssues(for: document, preset: preset).map { issue in
            let severity: ReviewFindingSeverity
            switch issue.kind {
            case .pageWarning, .unknownBlockType:
                severity = .blocker
            case .lowConfidence, .unreviewedTableOrFigure:
                severity = .warning
            }
            let block = issue.blockID.flatMap { id in document.allBlocks.first { $0.id == id } }
            let source: ReviewFindingSource = {
                if let provenance = block?.provenance {
                    switch provenance.source {
                    case .embeddedPDF: return .embeddedPDF
                    case .visionOCR: return .visionOCR
                    case .userEdit: return .userEdit
                    case .appleIntelligence, .heuristic: return .heuristic
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
                severity: severity,
                pageNumber: issue.pageNumber,
                blockID: issue.blockID,
                title: issue.title,
                detail: issue.detail,
                provenance: ReviewFindingProvenance(
                    source: source,
                    pageNumber: issue.pageNumber,
                    bounds: block?.bounds,
                    parentBlockID: issue.blockID
                )
            )
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
}
