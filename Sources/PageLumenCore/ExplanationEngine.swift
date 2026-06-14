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

    public func betterSummary(for document: ReaderDocument, length: SummaryLength) -> String {
        guard !document.allBlocks.isEmpty else {
            return "No readable extracted text is available yet."
        }

        let allExportable = document.pages.flatMap { page in
            DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: false)
        }
        guard !allExportable.isEmpty else {
            return "No readable extracted text is available yet."
        }

        let (headingBudget, bodyBudget) = budgets(for: length)
        let headings = allExportable.filter { $0.type == .heading }
        let bodies = allExportable.filter { $0.type != .heading }

        var collected: [String] = []
        var collectedHeadings = 0
        var collectedBodies = 0

        switch length {
        case .short:
            for block in bodies.prefix(bodyBudget) {
                collected.append(speechFriendly(block))
                collectedBodies += 1
            }
            if let firstHeading = headings.first, collectedBodies <= 1 {
                collected.insert(anchorLine(for: firstHeading), at: 0)
            } else if let firstHeading = headings.first, collected.allSatisfy({ !$0.contains(firstHeading.text) }) {
                collected.insert(anchorLine(for: firstHeading), at: 0)
            }
        case .medium:
            for block in allExportable {
                if block.type == .heading {
                    if collectedHeadings >= headingBudget { continue }
                    collected.append(anchorLine(for: block))
                    collectedHeadings += 1
                } else {
                    if collectedBodies >= bodyBudget { continue }
                    collected.append(speechFriendly(block))
                    collectedBodies += 1
                }
            }
        case .detailed:
            for block in allExportable {
                if block.type == .heading {
                    collected.append(anchorLine(for: block))
                    collectedHeadings += 1
                } else {
                    collected.append(speechFriendly(block))
                    collectedBodies += 1
                }
            }
        }

        if collected.isEmpty {
            return "No readable extracted text is available yet."
        }

        var result = collected.joined(separator: " ")
        if document.pages.contains(where: { $0.warning != nil }) {
            result += " Some pages include confidence warnings, so review the source before sharing."
        }
        return result
    }

    private func budgets(for length: SummaryLength) -> (headings: Int, bodies: Int) {
        switch length {
        case .short: return (1, 2)
        case .medium: return (3, 4)
        case .detailed: return (Int.max, Int.max)
        }
    }

    private func anchorLine(for block: TextBlock) -> String {
        let cleaned = cleanText(block.text)
        return "Section: \(cleaned)."
    }

    private func speechFriendly(_ block: TextBlock) -> String {
        let cleaned = cleanText(block.text)
        let rewritten = VisibleReferenceRewriter.rewrite(cleaned)
        if block.type == .figure || block.type == .table {
            return rewritten.isEmpty ? rewritten : "\(rewritten)."
        }
        return rewritten
    }

    private func cleanText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum VisibleReferenceRewriter {
    private static let figurePattern = #"(?i)\b(see|refer to|shown in|shown on|as in|in)\s+figure\s+\d+[a-z]?\b"#
    private static let tablePattern = #"(?i)\b(see|refer to|shown in|shown on|as in|in)\s+table\s+\d+[a-z]?\b"#
    private static let pagePattern = #"(?i)\b(on|see)\s+page\s+\d+\b"#
    private static let sectionPattern = #"(?i)\b(see|refer to|as in)\s+section\s+\d+(\.\d+)*\b"#

    static func rewrite(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: figurePattern, with: "a figure on this page", options: .regularExpression)
        result = result.replacingOccurrences(of: tablePattern, with: "a table on this page", options: .regularExpression)
        result = result.replacingOccurrences(of: pagePattern, with: "on a nearby page", options: .regularExpression)
        result = result.replacingOccurrences(of: sectionPattern, with: "in another section", options: .regularExpression)
        return result
    }
}
