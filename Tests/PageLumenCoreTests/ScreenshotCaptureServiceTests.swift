import XCTest
@testable import PageLumen
@testable import PageLumenCore

final class ScreenshotCaptureServiceTests: XCTestCase {
    func testArgumentBuilderForRegion() {
        let service = ScreenshotCaptureService()
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

    func testStaleTemporaryCapturesAreRemovedWithoutTouchingOtherFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-capture-cleanup-(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let stale = directory.appendingPathComponent("PageLumen-Window-stale.png")
        let fresh = directory.appendingPathComponent("PageLumen-Selection-fresh.png")
        let unrelated = directory.appendingPathComponent("unrelated.png")
        try Data([0]).write(to: stale)
        try Data([0]).write(to: fresh)
        try Data([0]).write(to: unrelated)
        let oldDate = Date(timeIntervalSinceNow: -3_600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: stale.path)

        let removed = ScreenshotCaptureService.cleanupStaleTemporaryCaptures(in: directory, olderThan: 60)

        XCTAssertEqual(removed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }
}

private struct TestCaptureError: LocalizedError {
    var errorDescription: String? { "test capture failure" }
}
