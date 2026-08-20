import XCTest
@testable import PageLumen

final class ScreenshotCaptureErrorTests: XCTestCase {
    func testCancelledCaptureHasRecoverableDescription() {
        XCTAssertEqual(
            ScreenshotCaptureError.cancelled.localizedDescription,
            "Screenshot capture was cancelled."
        )
    }
}
