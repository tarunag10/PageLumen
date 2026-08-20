import XCTest
@testable import PageLumen

final class ScreenshotCaptureErrorTests: XCTestCase {
    func testLegacyCommandArgumentsAreDeterministic() {
        let service = ScreenshotCaptureService()
        let output = URL(fileURLWithPath: "/tmp/selection.png")
        XCTAssertEqual(service.legacyArguments(for: .selectedRegion, output: output), ["-i", output.path])
        XCTAssertEqual(service.legacyArguments(for: .window, output: output), ["-w", output.path])
    }
    func testCancelledCaptureHasRecoverableDescription() {
        XCTAssertEqual(
            ScreenshotCaptureError.cancelled.localizedDescription,
            "Screenshot capture was cancelled."
        )
    }
}
