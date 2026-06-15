import SwiftUI
import TipKit
import XCTest
@testable import PageLumen

final class PageLumenTipsTests: XCTestCase {
    func testAllTipsHaveNonEmptyTitle() {
        XCTAssertFalse(String(describing: DropZoneTip().title).isEmpty)
        XCTAssertFalse(String(describing: ReviewIssueTip().title).isEmpty)
        XCTAssertFalse(String(describing: ExportAccessibilityTip().title).isEmpty)
        XCTAssertFalse(String(describing: BoostContrastTip().title).isEmpty)
    }

    func testAllTipsHaveNonEmptyMessage() {
        XCTAssertFalse(String(describing: DropZoneTip().message).isEmpty)
        XCTAssertFalse(String(describing: ReviewIssueTip().message).isEmpty)
        XCTAssertFalse(String(describing: ExportAccessibilityTip().message).isEmpty)
        XCTAssertFalse(String(describing: BoostContrastTip().message).isEmpty)
    }
}
