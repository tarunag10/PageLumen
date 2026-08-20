import Foundation

/// A small repository boundary over the existing persistence adapters. It keeps
/// library/search consumers independent from SwiftData and makes the retention
/// policy explicit: only documents already approved for local recents are read.
public protocol DocumentRepository: Sendable {
    /// Metadata-only reads for library lists. Full page/block payloads are
    /// loaded explicitly with `document(id:)`.
    func recentMetadata() throws -> [DocumentMetadata]
    func metadata(id: UUID) throws -> DocumentMetadata?
    func document(id: UUID) throws -> ReaderDocument?
    func search(query: String, limit: Int) throws -> [LibrarySearchResult]
}

public struct DocumentMetadata: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var sourceType: SourceType
    public var sourceURL: URL?
    public var createdAt: Date
    public var language: String?
    public var processingStatus: ProcessingStatus
    public var pageCount: Int
    public var unresolvedFindingCount: Int

    public init(
        id: UUID,
        title: String,
        sourceType: SourceType,
        sourceURL: URL?,
        createdAt: Date,
        language: String?,
        processingStatus: ProcessingStatus,
        pageCount: Int,
        unresolvedFindingCount: Int
    ) {
        self.id = id
        self.title = title
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.language = language
        self.processingStatus = processingStatus
        self.pageCount = pageCount
        self.unresolvedFindingCount = unresolvedFindingCount
    }
}

public struct LibrarySearchResult: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var documentID: UUID
    public var title: String
    public var pageNumber: Int
    public var blockID: UUID?
    public var snippet: String

    public init(documentID: UUID, title: String, pageNumber: Int, blockID: UUID?, snippet: String) {
        self.documentID = documentID
        self.title = title
        self.pageNumber = pageNumber
        self.blockID = blockID
        self.snippet = snippet
        self.id = "\(documentID.uuidString)-\(pageNumber)-\(blockID?.uuidString ?? snippet)"
    }
}

public final class LocalDocumentRepository: DocumentRepository, @unchecked Sendable {
    private let persisting: any DocumentPersisting

    public init(persisting: any DocumentPersisting) {
        self.persisting = persisting
    }

    public func recentMetadata() throws -> [DocumentMetadata] {
        try persisting.recentDocuments().map(metadata(for:))
    }

    public func metadata(id: UUID) throws -> DocumentMetadata? {
        guard let document = try persisting.load(id: id) else { return nil }
        return metadata(for: document)
    }

    public func document(id: UUID) throws -> ReaderDocument? {
        try persisting.load(id: id)
    }

    public func search(query: String, limit: Int = 20) throws -> [LibrarySearchResult] {
        let terms = Self.tokens(query)
        guard !terms.isEmpty else { return [] }
        let documents = try persisting.recentDocuments()
        var results: [LibrarySearchResult] = []
        for document in documents {
            for page in document.pages {
                for block in page.blocks.sorted(by: { $0.readingOrderIndex < $1.readingOrderIndex }) {
                    let searchable = block.text.lowercased()
                    guard terms.allSatisfy({ searchable.contains($0) }) else { continue }
                    results.append(LibrarySearchResult(
                        documentID: document.id,
                        title: document.title,
                        pageNumber: page.pageNumber,
                        blockID: block.id,
                        snippet: Self.snippet(for: block.text, terms: terms)
                    ))
                    if results.count >= max(1, limit) { return results }
                }
            }
        }
        return results
    }

    private func metadata(for document: ReaderDocument) -> DocumentMetadata {
        DocumentMetadata(
            id: document.id,
            title: document.title,
            sourceType: document.sourceType,
            sourceURL: document.sourceURL,
            createdAt: document.createdAt,
            language: document.language,
            processingStatus: document.processingStatus,
            pageCount: document.pageCount,
            unresolvedFindingCount: DocumentEditing.reviewFindings(for: document).filter { !$0.isResolved }.count
        )
    }

    private static func tokens(_ value: String) -> [String] {
        value.lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols))
            .filter { $0.count >= 2 }
    }

    private static func snippet(for text: String, terms: [String]) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let term = terms.first, let range = normalized.lowercased().range(of: term) else {
            return String(normalized.prefix(160))
        }
        let start = normalized.distance(from: normalized.startIndex, to: range.lowerBound)
        let lower = max(0, start - 60)
        let upper = min(normalized.count, start + term.count + 100)
        let lowerIndex = normalized.index(normalized.startIndex, offsetBy: lower)
        let upperIndex = normalized.index(normalized.startIndex, offsetBy: upper)
        return String(normalized[lowerIndex..<upperIndex])
    }
}
