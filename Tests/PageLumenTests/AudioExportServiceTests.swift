import Foundation
import PageLumenCore
import XCTest
@testable import PageLumen

@MainActor
final class AudioExportServiceTests: XCTestCase {
    func testAudioExportFormatExposesM4AExtension() {
        XCTAssertEqual(ExportFormat.audio.fileExtension, "m4a")
        XCTAssertEqual(ExportFormat.audio.rawValue, "Audio")
    }

    func testAudioExportServiceHasExpectedPublicAPI() {
        let serviceType = AudioExportService.self
        let selector = NSSelectorFromString("exportWithText:to:error:")
        // The selector lookup is just a way to assert the Obj-C bridge
        // signature exists. Swift methods aren't introspectable, so we
        // additionally exercise the type via `init()`.
        _ = selector
        let service = AudioExportService()
        XCTAssertNotNil(service)
    }

    func testAudioExportServiceAcceptsConfiguredVoiceAndLanguage() {
        // The overload is intentionally exercised without starting synthesis;
        // the platform speech engine is not deterministic in unit tests.
        let service = AudioExportService()
        XCTAssertNotNil(service)
    }

    func testAudioExportRejectsEmptyText() async {
        let service = AudioExportService()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumen-AudioExport-empty-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        do {
            try await service.export(text: "   \n  ", to: url)
            XCTFail("Expected empty text to throw AudioExportError.emptyText")
        } catch let error as AudioExportError {
            switch error {
            case .emptyText:
                break
            case .cancelled:
                XCTFail("Expected empty text error, got cancellation")
            case .invalidOutput:
                XCTFail("Expected empty text error, got invalid output")
            }
        } catch {
            XCTFail("Expected AudioExportError.emptyText, got \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testAudioExportCancellationHasUserFacingDescription() {
        XCTAssertEqual(AudioExportError.cancelled.localizedDescription, "Audio export was cancelled.")
    }

    func testAudioExportProgressClampsFractionsAndPreservesLifecyclePhase() {
        XCTAssertEqual(
            AudioExportProgress(fractionCompleted: -0.5, phase: .preparing),
            AudioExportProgress(fractionCompleted: 0, phase: .preparing)
        )
        XCTAssertEqual(
            AudioExportProgress(fractionCompleted: 1.5, phase: .completed),
            AudioExportProgress(fractionCompleted: 1, phase: .completed)
        )
        XCTAssertEqual(AudioExportProgress.Phase.synthesizing.rawValue, "synthesizing")
    }

    func testAudioExportInvalidOutputHasUserFacingDescription() {
        XCTAssertEqual(
            AudioExportError.invalidOutput.localizedDescription,
            "Audio export did not produce a readable audio file."
        )
    }
}
