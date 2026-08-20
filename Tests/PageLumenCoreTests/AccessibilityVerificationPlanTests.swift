import XCTest
@testable import PageLumenCore

final class AccessibilityVerificationPlanTests: XCTestCase {
    func testReleasePlanCoversEveryRequiredAccessibilityDimension() {
        let dimensions = Set(AccessibilityVerificationPlan.releaseItems.map(\.dimension))

        XCTAssertEqual(dimensions, Set(AccessibilityVerificationDimension.allCases))
        XCTAssertEqual(AccessibilityVerificationPlan.releaseItems.count, AccessibilityVerificationDimension.allCases.count)
        XCTAssertTrue(AccessibilityVerificationPlan.releaseItems.allSatisfy { $0.requiresParticipant })
    }

    func testReleasePlanItemsHaveObservableInstructionsAndOutcomes() {
        for item in AccessibilityVerificationPlan.releaseItems {
            XCTAssertFalse(item.workflow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, item.dimension.rawValue)
            XCTAssertFalse(item.expectedOutcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, item.dimension.rawValue)
            XCTAssertFalse(item.dimension.systemSetting.isEmpty, item.dimension.rawValue)
        }
    }
}
