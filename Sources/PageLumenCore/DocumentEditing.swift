import Foundation

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

    public static func reviewIssues(for document: ReaderDocument) -> [ReviewIssue] {
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
                } else if block.confidence < 0.7 {
                    issues.append(ReviewIssue(kind: .lowConfidence, pageNumber: page.pageNumber, blockID: block.id, title: "Low OCR confidence", detail: "\(Int(block.confidence * 100))% confidence: \(previewText(block.text))"))
                } else if block.type == .table || block.type == .figure {
                    issues.append(ReviewIssue(kind: .unreviewedTableOrFigure, pageNumber: page.pageNumber, blockID: block.id, title: "Review generated structure", detail: previewText(block.text)))
                }
            }
            return issues
        }
    }

    public static func reviewProgress(for document: ReaderDocument) -> ReviewProgress {
        let blocks = document.allBlocks
        return ReviewProgress(
            reviewedBlocks: blocks.filter(isReviewed).count,
            totalBlocks: blocks.count,
            issueCount: reviewIssues(for: document).count
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
