import Foundation

/// A user-facing excerpt that keeps the text tied to the exact document page
/// and reading-order block from which it was copied.
public struct DocumentQuote: Equatable, Codable, Sendable {
    public let documentTitle: String
    public let pageNumber: Int
    public let blockNumber: Int
    public let text: String

    public init(documentTitle: String, pageNumber: Int, blockNumber: Int, text: String) {
        self.documentTitle = documentTitle
        self.pageNumber = pageNumber
        self.blockNumber = blockNumber
        self.text = text
    }

    public var citation: String {
        "\(documentTitle), page \(pageNumber), block \(blockNumber)"
    }

    /// Plain text is deliberately used so the result is useful to VoiceOver,
    /// braille displays, notes apps, and terminals without requiring rich text.
    public var accessibleExcerpt: String {
        "\(text)\n\n— \(citation)"
    }

    public static func from(document: ReaderDocument, block: TextBlock) -> DocumentQuote {
        DocumentQuote(
            documentTitle: document.title,
            pageNumber: block.pageNumber,
            blockNumber: block.readingOrderIndex + 1,
            text: textForCopy(block.text)
        )
    }

    private static func textForCopy(_ rawText: String) -> String {
        rawText
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
