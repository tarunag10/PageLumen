import XCTest
@testable import PageLumenCore

final class ModelComparisonTests: XCTestCase {
    func testComparisonRejectsDifferentCorpusRevisions() {
        let a = snapshot(id: "foundation", revision: "r1", risk: 0.1, cost: 1)
        let b = snapshot(id: "prototype", revision: "r2", risk: 0.01, cost: 0.1)
        XCTAssertEqual(ModelComparator.compare(a, b), .incomparable("Evaluation corpus revisions do not match"))
    }

    func testComparisonPrefersLowerUnsupportedClaimRateBeforeCost() {
        let a = snapshot(id: "foundation", revision: "r1", risk: 0.02, cost: 10)
        let b = snapshot(id: "prototype", revision: "r1", risk: 0.05, cost: 1)
        XCTAssertEqual(ModelComparator.compare(a, b), .preferred("foundation"))
    }

    func testComparisonDoesNotChooseWhenRequiredMetricsAreUnavailable() {
        let a = snapshot(id: "foundation", revision: "r1", risk: nil, cost: 1)
        let b = snapshot(id: "prototype", revision: "r1", risk: 0.05, cost: 1)
        XCTAssertEqual(ModelComparator.compare(a, b), .unavailable("Both models require measured safety and cost metrics"))
    }

    private func snapshot(id: String, revision: String, risk: Double?, cost: Double?) -> ModelEvaluationSnapshot {
        ModelEvaluationSnapshot(modelIdentifier: id, corpusRevision: revision,
                                 unsupportedClaimRate: risk, citationCoverage: 1,
                                 medianLatencyMilliseconds: 10, operationalCost: cost)
    }
}
