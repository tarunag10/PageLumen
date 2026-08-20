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

    func testWindowCaptureExposesAUserSelectionCapability() {
        let service = ScreenshotCaptureService()

        #if canImport(ScreenCaptureKit)
        if #available(macOS 14.0, *) {
            XCTAssertEqual(service.windowSelectionCapability, .contentSharingPicker)
        } else {
            XCTAssertEqual(service.windowSelectionCapability, .legacyInteractivePicker)
        }
        #else
        XCTAssertEqual(service.windowSelectionCapability, .legacyInteractivePicker)
        #endif
    }

    func testLegacyWindowArgumentsRetainInteractivePicker() {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("capture.png")
        XCTAssertEqual(
            ScreenshotCaptureService().legacyArguments(for: .window, output: output),
            ["-w", output.path]
        )
    }
}
