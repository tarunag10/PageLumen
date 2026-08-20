import Markdown

/// Dialects are a validation policy, not a rewrite instruction. Unknown
/// extensions are retained verbatim by callers; PageLumen never silently
/// converts syntax it cannot prove equivalent.
public enum MarkdownDialect: String, Codable, CaseIterable, Identifiable, Sendable {
    case pageLumenGFM
    case commonMark

    public var id: String { rawValue }

    public var supportsTables: Bool {
        switch self {
        case .pageLumenGFM: return true
        case .commonMark: return false
        }
    }

    public var preservesUnsupportedSyntax: Bool { true }
}

/// The result of validating an exported Markdown document against PageLumen's
/// structural contract. Issues are stable, human-readable values so callers
/// can surface them without exposing parser internals.
public struct MarkdownExportValidation: Equatable, Sendable {
    public let isValid: Bool
    public let issues: [String]

    public init(isValid: Bool, issues: [String] = []) {
        self.isValid = isValid
        self.issues = issues
    }
}

/// A deliberately small boundary around swift-markdown. PageLumen does not
/// accept arbitrary Markdown as an export contract: the title, headings,
/// tables, block quotes, and page markers must remain parseable and stable.
/// Keeping this policy in core lets the app and future import/editor features
/// share one deterministic check.
public enum MarkdownExportContract {
    public static func validate(
        _ markdown: String,
        expectedPageNumbers: [Int] = [],
        dialect: MarkdownDialect = .pageLumenGFM
    ) -> MarkdownExportValidation {
        var issues: [String] = []

        guard !markdown.isEmpty else {
            return MarkdownExportValidation(isValid: false, issues: ["markdown.empty"])
        }
        if markdown.contains("\r") {
            issues.append("markdown.crlf")
        }
        if !markdown.hasSuffix("\n") {
            issues.append("markdown.missing-trailing-newline")
        }

        let document = Document(parsing: markdown)
        let topLevel = Array(document.children)
        guard let title = topLevel.first as? Heading, title.level == 1 else {
            issues.append("markdown.missing-title-heading")
            return MarkdownExportValidation(isValid: false, issues: issues)
        }
        if title.childCount == 0 {
            issues.append("markdown.empty-title-heading")
        }

        let headings = topLevel.compactMap { $0 as? Heading }
        if headings.contains(where: { $0.level < 1 || $0.level > 3 }) {
            issues.append("markdown.heading-level-out-of-range")
        }
        for (previous, next) in zip(headings, headings.dropFirst()) where next.level - previous.level > 1 {
            issues.append("markdown.heading-level-jump")
            break
        }

        let pageMarkers = headings.compactMap { heading -> Int? in
            guard heading.level == 2,
                  let text = (heading.child(at: 0) as? Text)?.string,
                  text.hasPrefix("Page ") else { return nil }
            return Int(text.dropFirst("Page ".count))
        }
        if !expectedPageNumbers.isEmpty, pageMarkers != expectedPageNumbers {
            issues.append("markdown.page-markers-not-deterministic")
        }

        let containsTableSyntax = markdownHasTableSyntax(markdown)
        if containsTableSyntax && !dialect.supportsTables {
            issues.append("markdown.tables-unsupported-by-dialect")
        }
        validateTables(in: markdown, issues: &issues)
        if topLevel.contains(where: { $0 is Table }) {
            let tables = topLevel.compactMap { $0 as? Table }
            if tables.contains(where: { $0.maxColumnCount == 0 || $0.head.childCount == 0 }) {
                issues.append("markdown.table-without-header")
            }
        }

        return MarkdownExportValidation(isValid: issues.isEmpty, issues: issues)
    }

    private static func validateTables(in markdown: String, issues: inout [String]) {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("|"), line.hasSuffix("|") else {
                index += 1
                continue
            }
            guard index + 1 < lines.count else {
                index += 1
                continue
            }
            let separator = lines[index + 1].trimmingCharacters(in: .whitespaces)
            let isSeparator = separator.hasPrefix("|") && separator.hasSuffix("|") &&
                separator.split(separator: "|", omittingEmptySubsequences: true).allSatisfy {
                    $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" }
                }
            guard isSeparator else {
                index += 1
                continue
            }
            let columns = pipeCount(in: line)
            let separatorColumns = pipeCount(in: separator)
            if columns != separatorColumns || columns == 0 {
                issues.append("markdown.table-column-count-mismatch")
            }
            index += 2
            while index < lines.count {
                let row = lines[index].trimmingCharacters(in: .whitespaces)
                guard row.hasPrefix("|"), row.hasSuffix("|") else { break }
                if pipeCount(in: row) != columns {
                    issues.append("markdown.table-column-count-mismatch")
                }
                index += 1
            }
        }
    }

    private static func markdownHasTableSyntax(_ markdown: String) -> Bool {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return zip(lines, lines.dropFirst()).contains { first, second in
            let firstTrimmed = first.trimmingCharacters(in: .whitespaces)
            let secondTrimmed = second.trimmingCharacters(in: .whitespaces)
            return firstTrimmed.hasPrefix("|") && firstTrimmed.hasSuffix("|") &&
                secondTrimmed.hasPrefix("|") && secondTrimmed.hasSuffix("|") &&
                secondTrimmed.split(separator: "|", omittingEmptySubsequences: true).allSatisfy {
                    $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" }
                }
        }
    }

    private static func pipeCount(in line: String) -> Int {
        var escaped = false
        var count = 0
        for character in line {
            if character == "\\" {
                escaped.toggle()
            } else {
                if character == "|" && !escaped { count += 1 }
                escaped = false
            }
        }
        return count
    }
}
