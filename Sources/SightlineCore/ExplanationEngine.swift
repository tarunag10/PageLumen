import Foundation

public struct ExplanationEngine: Sendable {
    public init() {}

    public func explain(table: TableRegion) -> String {
        let columnCount = table.rows.map(\.count).max() ?? 0
        let rowCount = table.rows.count
        let header = table.rows.first?.joined(separator: ", ") ?? "No readable header"
        var explanation = "This table appears to contain \(rowCount) rows and \(columnCount) columns. The visible header or first row reads: \(header)."

        if let firstDataRow = table.rows.dropFirst().first {
            explanation += " The first data row reads: \(firstDataRow.joined(separator: ", "))."
        }

        if table.confidence < 0.75 {
            explanation += " The table structure is uncertain and should be reviewed against the source page."
        }

        return explanation
    }

    public func explain(figure: FigureRegion) -> String {
        let typeText = figure.chartType == .unknown ? "chart or figure" : "\(figure.chartType.rawValue) chart"
        var description = "The \(typeText) appears to show visible text: \(figure.visibleText)."
        if figure.confidence < 0.75 || !figure.uncertaintyNotes.isEmpty {
            description += " Exact values may be hard to read; verify the source image before relying on this description."
        }
        return description
    }

    public func summary(for document: ReaderDocument, length: SummaryLength) -> String {
        let blocks = document.allBlocks.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !blocks.isEmpty else {
            return "No readable extracted text is available yet."
        }

        let limit: Int
        switch length {
        case .short:
            limit = 2
        case .medium:
            limit = 5
        case .detailed:
            limit = 10
        }

        let sentences = blocks.prefix(limit).map { block -> String in
            let cleaned = block.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return "Page \(block.pageNumber): \(cleaned)"
        }

        var summary = sentences.joined(separator: " ")
        if document.pages.contains(where: { $0.warning != nil }) {
            summary += " Some pages include confidence warnings, so review the source before sharing."
        }
        return summary
    }
}
