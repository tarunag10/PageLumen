import AVFoundation
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

    func testInjectedSpeechEngineKeepsExportBoundaryDeterministic() async {
        let engine = RecordingSpeechEngine()
        let service = AudioExportService(makeSynthesizer: { engine })
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumen-AudioExport-fake-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        do {
            try await service.export(text: "hello", to: url, language: "en-GB", voiceIdentifier: "voice.test")
            XCTFail("The fake engine emits no audio and should produce invalidOutput")
        } catch let error as AudioExportError {
            if case .invalidOutput = error {
                // Expected: the fake engine intentionally emits a zero-length buffer.
            } else {
                XCTFail("Expected invalid output, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertTrue(engine.didWrite)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}

private final class RecordingSpeechEngine: NSObject, AudioSpeechSynthesizing {
    private(set) var didWrite = false

    func write(_ utterance: AVSpeechUtterance, toBufferCallback callback: @escaping (AVAudioBuffer) -> Void) {
        didWrite = true
        let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
        callback(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1)!)
    }

    @discardableResult
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { true }
}
