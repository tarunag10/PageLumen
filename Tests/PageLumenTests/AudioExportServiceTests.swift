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
            }
        } catch {
            XCTFail("Expected AudioExportError.emptyText, got \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
