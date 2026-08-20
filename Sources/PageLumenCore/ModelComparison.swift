import Foundation

public struct ModelEvaluationSnapshot: Codable, Equatable, Sendable {
    public let modelIdentifier: String
    public let corpusRevision: String
    public let unsupportedClaimRate: Double?
    public let citationCoverage: Double?
    public let medianLatencyMilliseconds: Double?
    public let operationalCost: Double?

    public init(modelIdentifier: String, corpusRevision: String,
                unsupportedClaimRate: Double?, citationCoverage: Double?,
                medianLatencyMilliseconds: Double?, operationalCost: Double?) {
        self.modelIdentifier = modelIdentifier
        self.corpusRevision = corpusRevision
        self.unsupportedClaimRate = unsupportedClaimRate
        self.citationCoverage = citationCoverage
        self.medianLatencyMilliseconds = medianLatencyMilliseconds
        self.operationalCost = operationalCost
    }
}

public enum ModelComparisonDecision: Equatable, Sendable {
    case preferred(String)
    case unavailable(String)
    case incomparable(String)
}

/// Compares only complete, same-corpus measurements. Safety comes before cost.
public enum ModelComparator {
    public static func compare(_ left: ModelEvaluationSnapshot,
                               _ right: ModelEvaluationSnapshot) -> ModelComparisonDecision {
        guard left.corpusRevision == right.corpusRevision else {
            return .incomparable("Evaluation corpus revisions do not match")
        }
        guard let leftRisk = left.unsupportedClaimRate,
              let rightRisk = right.unsupportedClaimRate,
              let leftCost = left.operationalCost,
              let rightCost = right.operationalCost else {
            return .unavailable("Both models require measured safety and cost metrics")
        }
        if leftRisk < rightRisk { return .preferred(left.modelIdentifier) }
        if rightRisk < leftRisk { return .preferred(right.modelIdentifier) }
        if leftCost < rightCost { return .preferred(left.modelIdentifier) }
        if rightCost < leftCost { return .preferred(right.modelIdentifier) }
        return .incomparable("Measured safety and cost are tied")
    }
}
