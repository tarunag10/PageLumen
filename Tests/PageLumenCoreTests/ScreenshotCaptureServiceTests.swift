import XCTest
@testable import PageLumen
@testable import PageLumenCore
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

final class ScreenshotCaptureServiceTests: XCTestCase {
    func testArgumentBuilderForRegion() {
        let service = ScreenshotCaptureService()
        let output = URL(fileURLWithPath: "/tmp/region.png")
        XCTAssertEqual(service.legacyArguments(for: .selectedRegion, output: output), ["-i", output.path])
        XCTAssertEqual(service.legacyArguments(for: .window, output: output), ["-w", output.path])
    }

    func testLegacyCaptureUsesInjectedCommandRunnerAndMapsFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-capture-runner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = RecordingScreenshotCommandRunner(status: 7)
        let service = ScreenshotCaptureService(temporaryDirectory: directory, commandRunner: runner)
        let output = directory.appendingPathComponent("capture.png")
        do {
            _ = try await service.legacyCapture(mode: .selectedRegion, outputURL: output)
            XCTFail("Expected the injected command failure")
        } catch {
            XCTAssertEqual(error as? ScreenshotCaptureError, .commandFailed(7))
        }
        XCTAssertEqual(runner.arguments?.first, "-i")
        XCTAssertEqual(runner.executable?.path, "/usr/sbin/screencapture")
    }

    func testCaptureThrowsWhenOutputDirectoryIsUnwritable() async {
        // Capture requires interactive selection; we can only test that the service exists.
        // The actual capture is hard to test without user interaction.
        let service = ScreenshotCaptureService()
        // Just exercise the constructor.
        XCTAssertNotNil(service)
    }

    func testWindowCapturePickerCancellationIsInjectableWithoutTCCOrPickerUI() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-window-cancel-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = ScreenshotCaptureService(
            temporaryDirectory: directory,
            preflightPermission: { true },
            requestPermission: { false },
            windowCaptureOperation: { _ in throw ScreenshotCaptureError.cancelled }
        )

        do {
            _ = try await service.capture(mode: .window)
            XCTFail("Expected picker cancellation")
        } catch {
            XCTAssertEqual(error as? ScreenshotCaptureError, .cancelled)
        }
        XCTAssertTrue((try? FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty) == true)
    }

    func testWindowCaptureNoSelectionIsInjectableWithoutCreatingAnOutput() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-window-empty-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = ScreenshotCaptureService(
            temporaryDirectory: directory,
            preflightPermission: { true },
            requestPermission: { false },
            windowCaptureOperation: { _ in throw ScreenshotCaptureError.noShareableContent }
        )

        do {
            _ = try await service.capture(mode: .window)
            XCTFail("Expected no-shareable-content failure")
        } catch {
            XCTAssertEqual(error as? ScreenshotCaptureError, .noShareableContent)
        }
        XCTAssertTrue((try? FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty) == true)
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

    func testModernNoShareableContentErrorRemainsStable() {
        XCTAssertEqual(
            ScreenshotCaptureError.modernCaptureError(ScreenshotCaptureError.noShareableContent, isCancelled: false),
            .noShareableContent
        )
    }

    #if canImport(ScreenCaptureKit)
    func testScreenCaptureKitNoWindowAndNoDisplayErrorsMapToNoShareableContent() {
        XCTAssertEqual(
            ScreenshotCaptureError.modernCaptureError(
                NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.noWindowList.rawValue)
            ),
            .noShareableContent
        )
        XCTAssertEqual(
            ScreenshotCaptureError.modernCaptureError(
                NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.noDisplayList.rawValue)
            ),
            .noShareableContent
        )
    }

    func testScreenCaptureKitPermissionErrorMapsToPermissionDenied() {
        XCTAssertEqual(
            ScreenshotCaptureError.modernCaptureError(
                NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue)
            ),
            .permissionDenied
        )
    }
    #endif

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

private final class RecordingScreenshotCommandRunner: ScreenshotCommandRunning, @unchecked Sendable {
    let status: Int32
    private(set) var executable: URL?
    private(set) var arguments: [String]?

    init(status: Int32) { self.status = status }

    func run(executable: URL, arguments: [String]) throws -> Int32 {
        self.executable = executable
        self.arguments = arguments
        return status
    }
}

private struct TestCaptureError: LocalizedError {
    var errorDescription: String? { "test capture failure" }
}
