import Foundation

/// A privacy-safe, serializable location used to reopen a document in the
/// Review workspace. It contains identifiers and coordinates only; document
/// text is intentionally never embedded in a deep-link payload.
public struct ReviewSelectionPayload: Codable, Hashable, Sendable {
    public let documentID: UUID?
    public let pageNumber: Int
    public let blockID: UUID?
    public let issueID: String?

    public init(
        documentID: UUID? = nil,
        pageNumber: Int,
        blockID: UUID? = nil,
        issueID: String? = nil
    ) {
        self.documentID = documentID
        self.pageNumber = pageNumber
        self.blockID = blockID
        self.issueID = issueID
    }
}
