import Foundation

public struct SummaryEvaluation: Codable, Equatable, Sendable {
    public let citationCoverage: Double
    public let hasGroundingWarningWhenNeeded: Bool
    public let passed: Bool

    public init(citationCoverage: Double, hasGroundingWarningWhenNeeded: Bool, passed: Bool) {
        self.citationCoverage = citationCoverage
        self.hasGroundingWarningWhenNeeded = hasGroundingWarningWhenNeeded
        self.passed = passed
    }
}

/// Deterministic, offline quality gate for summaries. It deliberately does
/// not judge prose quality; it verifies the properties PageLumen can prove:
/// every cited block exists in the source and uncertain documents are marked.
public enum SummaryEvaluator {
    public static func evaluate(_ summary: GroundedSummary, against document: ReaderDocument) -> SummaryEvaluation {
        let sourceIDs = Set(document.allBlocks.map(\.id))
        let valid = summary.citations.filter { sourceIDs.contains($0.blockID) }.count
        let coverage = summary.citations.isEmpty ? 0 : Double(valid) / Double(summary.citations.count)
        let needsWarning = summary.citations.isEmpty || document.pages.contains(where: { $0.warning != nil })
        let warningOK = !needsWarning || summary.groundingWarning != nil
        return SummaryEvaluation(
            citationCoverage: coverage,
            hasGroundingWarningWhenNeeded: warningOK,
            passed: coverage == 1 && warningOK
        )
    }
}
