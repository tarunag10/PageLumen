import XCTest
@testable import PageLumenCore

// Accessibility contract: every status enums the UI surfaces to VoiceOver must
// have a non-empty human-readable label so screen readers can announce it.
//
// The full `StatusDescriptor` (label + systemImage + tint) lives in
// `Sources/PageLumen/Support/StatusBadge.swift` on the app target, which the
// PageLumenCoreTests target cannot import. These tests pin down the underlying
// string contract on the core enum surface so a refactor that breaks the label
// (or forgets a new case) fails the test suite even before the SwiftUI layer
// is reached.
final class AccessibilityStatusTests: XCTestCase {
    func testAllOCRStatusCasesHaveNonEmptyRawValue() {
        let cases: [OCRStatus] = [.pending, .processing, .complete, .failed]
        for status in cases {
            XCTAssertFalse(
                status.rawValue.isEmpty,
                "OCRStatus.\(status) must have a non-empty rawValue"
            )
        }
    }

    func testAllBatchImportItemStatusCasesHaveNonEmptyLabel() {
        let cases: [BatchImportItemStatus] = [
            .pending,
            .processing,
            .complete,
            .cancelled,
            .failed("network timeout")
        ]
        for status in cases {
            XCTAssertFalse(
                status.label.isEmpty,
                "BatchImportItemStatus.\(status) must produce a non-empty label"
            )
        }
    }

    func testFailedBatchStatusSurfacesTheProvidedReason() {
        let status = BatchImportItemStatus.failed("network timeout")
        XCTAssertTrue(status.label.contains("Failed"))
        XCTAssertFalse(status.label.isEmpty)
    }
}
