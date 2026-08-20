import Foundation

/// The deterministic kind of change between two text-block revisions.
public enum DocumentChangeKind: String, Codable, Equatable, Sendable {
    case added
    case removed
    case modified
}

/// A privacy-conscious block comparison. Text is available to the local UI
/// for an explicit side-by-side review, while `citation` contains only stable
/// page/block location metadata and never embeds source text.
public struct DocumentChange: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let blockID: UUID
    public let pageNumber: Int
    public let readingOrderIndex: Int?
    public let kind: DocumentChangeKind
    public let originalText: String?
    public let currentText: String?

    public var citation: String {
        "Page \(pageNumber), block \(blockID.uuidString.lowercased())"
    }

    public init(
        id: UUID = UUID(),
        blockID: UUID,
        pageNumber: Int,
        readingOrderIndex: Int? = nil,
        kind: DocumentChangeKind,
        originalText: String?,
        currentText: String?
    ) {
        self.id = id
        self.blockID = blockID
        self.pageNumber = pageNumber
        self.readingOrderIndex = readingOrderIndex
        self.kind = kind
        self.originalText = originalText
        self.currentText = currentText
    }
}

public enum DocumentComparison {
    /// Compares retained original OCR with the current text in one document.
    public static func changes(in document: ReaderDocument) -> [DocumentChange] {
        document.allBlocks.compactMap { block in
            guard let originalText = block.originalText, originalText != block.text else { return nil }
            return DocumentChange(
                blockID: block.id,
                pageNumber: block.pageNumber,
                readingOrderIndex: block.readingOrderIndex,
                kind: .modified,
                originalText: originalText,
                currentText: block.text
            )
        }
    }

    /// Compares two revisions using stable text-block IDs. A missing block in
    /// either revision is represented as an addition or removal.
    public static func changes(from baseline: ReaderDocument, to current: ReaderDocument) -> [DocumentChange] {
        let baselineBlocks = Dictionary(uniqueKeysWithValues: baseline.allBlocks.map { ($0.id, $0) })
        let currentBlocks = Dictionary(uniqueKeysWithValues: current.allBlocks.map { ($0.id, $0) })
        let ids = Set(baselineBlocks.keys).union(currentBlocks.keys)

        return ids.compactMap { id in
            let before = baselineBlocks[id]
            let after = currentBlocks[id]
            guard before?.text != after?.text else { return nil }

            let block = after ?? before!
            let kind: DocumentChangeKind = before == nil ? .added : after == nil ? .removed : .modified
            return DocumentChange(
                blockID: id,
                pageNumber: block.pageNumber,
                readingOrderIndex: block.readingOrderIndex,
                kind: kind,
                originalText: before?.text,
                currentText: after?.text
            )
        }
        .sorted { lhs, rhs in
            (lhs.pageNumber, lhs.readingOrderIndex ?? Int.max, lhs.blockID.uuidString)
                < (rhs.pageNumber, rhs.readingOrderIndex ?? Int.max, rhs.blockID.uuidString)
        }
    }
}
