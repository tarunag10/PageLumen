import Foundation

/// Deterministic structural checks for generated HTML. This is intentionally
/// a small, dependency-free contract rather than a claim of WCAG or PDF/UA
/// conformance. It catches regressions in the guarantees PageLumen itself
/// controls before an artifact is written.
public struct HTMLExportValidation: Equatable, Sendable {
    public let isValid: Bool
    public let issues: [String]

    public init(isValid: Bool, issues: [String] = []) {
        self.isValid = isValid
        self.issues = issues
    }
}

public enum HTMLExportContract {
    /// Validates generated HTML or Tagged HTML. `tagged` enables the stronger
    /// figure/landmark requirements used by the recommended export.
    public static func validate(_ html: String, tagged: Bool = false) -> HTMLExportValidation {
        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return HTMLExportValidation(isValid: false, issues: ["html.empty"])
        }

        var issues: [String] = []
        let lowercased = html.lowercased()

        if let htmlTag = firstMatch(pattern: #"<html\b([^>]*)>"#, in: html),
           let language = attribute(named: "lang", in: htmlTag.fullMatch),
           !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Language is present and non-empty.
        } else {
            issues.append("html.missing-language")
            // Continue checking the remaining structure so the report gives
            // an actionable complete list rather than only the first defect.
            if !lowercased.contains("<html") { issues.append("html.missing-root") }
        }

        if !lowercased.contains("<main") {
            issues.append("html.missing-main-landmark")
        }
        if tagged && !lowercased.contains("<a href=\"#content\">") {
            issues.append("html.missing-skip-link")
        }

        let headings = allMatches(pattern: #"<h([1-6])\b[^>]*>(.*?)</h\1>"#, in: html)
        if headings.isEmpty || headings.first?.capture(1) != "1" {
            issues.append("html.missing-title-heading")
        }
        for heading in headings where visibleText(heading.capture(2)).isEmpty {
            issues.append("html.empty-heading")
            break
        }
        let headingLevels = headings.compactMap { Int($0.capture(1)) }
        for (previous, next) in zip(headingLevels, headingLevels.dropFirst()) where next - previous > 1 {
            issues.append("html.heading-level-jump")
            break
        }

        for table in allMatches(pattern: #"<table\b[^>]*>(.*?)</table>"#, in: html) {
            let contents = table.capture(1).lowercased()
            if !contents.contains("<thead") && !contents.contains("scope=\"col\"") {
                issues.append("html.table-without-header")
            }
            if !contents.contains("<th") {
                issues.append("html.table-without-header-cell")
            }
        }

        for figure in allMatches(pattern: #"<figure\b[^>]*>(.*?)</figure>"#, in: html) {
            let contents = figure.capture(1)
            let hasCaption = !visibleText(firstMatch(pattern: #"<figcaption\b[^>]*>(.*?)</figcaption>"#, in: contents)?.capture(1) ?? "").isEmpty
            let hasLabel = !tagged || attribute(named: "aria-label", in: contents)?.isEmpty == false
            if !hasCaption || !hasLabel {
                issues.append("html.figure-missing-description")
            }
            if tagged && !contents.lowercased().contains("role=\"img\"") {
                issues.append("html.figure-missing-image-role")
            }
        }

        for link in allMatches(pattern: #"<a\b([^>]*)>"#, in: html) {
            guard let href = attribute(named: "href", in: link.fullMatch),
                  !href.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                issues.append("html.link-missing-target")
                continue
            }
            let scheme = href.split(separator: ":", maxSplits: 1).first.map(String.init)?.lowercased()
            if scheme == "javascript" || scheme == "data" {
                issues.append("html.link-unsafe-target")
            }
        }

        // A raw ampersand in text/attributes is almost always an escaping
        // regression. Recognise the entities emitted by ExportEngine and
        // numeric entities so valid output is not rejected.
        if html.range(of: #"&(?!amp;|lt;|gt;|quot;|#\d+;|#x[0-9a-fA-F]+;)"#, options: .regularExpression) != nil {
            issues.append("html.unescaped-ampersand")
        }

        return HTMLExportValidation(isValid: issues.isEmpty, issues: stableUnique(issues))
    }

    private struct Match {
        let fullMatch: String
        let captures: [String]
        func capture(_ index: Int) -> String {
            guard index > 0, index <= captures.count else { return "" }
            return captures[index - 1]
        }
    }

    private static func firstMatch(pattern: String, in text: String) -> Match? {
        allMatches(pattern: pattern, in: text).first
    }

    private static func allMatches(pattern: String, in text: String) -> [Match] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).map { result in
            let full = String(text[Range(result.range, in: text)!])
            let captures = (1..<result.numberOfRanges).map { index -> String in
                guard result.range(at: index).location != NSNotFound,
                      let range = Range(result.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
            return Match(fullMatch: full, captures: captures)
        }
    }

    private static func attribute(named name: String, in tag: String) -> String? {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: name) + "\\s*=\\s*[\\\"']([^\\\"']*)[\\\"']"
        return firstMatch(pattern: pattern, in: tag)?.capture(1)
    }

    private static func visibleText(_ value: String) -> String {
        value.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stableUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }
    }
}
