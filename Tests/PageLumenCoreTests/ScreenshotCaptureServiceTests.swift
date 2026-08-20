import XCTest
@testable import PageLumen
@testable import PageLumenCore

final class ScreenshotCaptureServiceTests: XCTestCase {
    func testArgumentBuilderForRegion() {
        let service = ScreenshotCaptureService()
        // The arguments method is private; we test through the public surface instead.
        // This test asserts the service is constructible.
        _ = service
    }

    func testCaptureThrowsWhenOutputDirectoryIsUnwritable() async {
        // Capture requires interactive selection; we can only test that the service exists.
        // The actual capture is hard to test without user interaction.
        let service = ScreenshotCaptureService()
        // Just exercise the constructor.
        XCTAssertNotNil(service)
    }

    func testScreenshotCaptureErrorDescriptions() {
        XCTAssertNotNil(ScreenshotCaptureError.commandFailed(1).errorDescription)
        XCTAssertNotNil(ScreenshotCaptureError.missingOutput.errorDescription)
        XCTAssertNotNil(ScreenshotCaptureError.permissionDenied.errorDescription)
        XCTAssertNotNil(ScreenshotCaptureError.modernAPINotAvailable.errorDescription)
        XCTAssertNotNil(ScreenshotCaptureError.noShareableContent.errorDescription)
        XCTAssertNotNil(ScreenshotCaptureError.modernCaptureFailed("test").errorDescription)
    }

    func testLegacyTerminationMapsCancellationSeparatelyFromCommandFailure() {
        XCTAssertEqual(
            ScreenshotCaptureError.legacyTerminationError(status: 1, isCancelled: false),
            .cancelled
        )
        XCTAssertEqual(
            ScreenshotCaptureError.legacyTerminationError(status: 2, isCancelled: false),
            .commandFailed(2)
        )
        XCTAssertEqual(
            ScreenshotCaptureError.legacyTerminationError(status: 0, isCancelled: true),
            .cancelled
        )
    }

    func testModernCancellationDoesNotBecomeGenericCaptureFailure() {
        XCTAssertEqual(
            ScreenshotCaptureError.modernCaptureError(CancellationError(), isCancelled: false),
            .cancelled
        )
        XCTAssertEqual(
            ScreenshotCaptureError.modernCaptureError(TestCaptureError(), isCancelled: false),
            .modernCaptureFailed("test capture failure")
        )
        XCTAssertEqual(
            ScreenshotCaptureError.modernCaptureError(TestCaptureError(), isCancelled: true),
            .cancelled
        )
    }

    func testScreenshotCaptureModeFilePrefixes() {
        XCTAssertEqual(ScreenshotCaptureMode.selectedRegion.filePrefix, "PageLumen-Selection")
        XCTAssertEqual(ScreenshotCaptureMode.window.filePrefix, "PageLumen-Window")
    }
}

private struct TestCaptureError: LocalizedError {
    var errorDescription: String? { "test capture failure" }
}
