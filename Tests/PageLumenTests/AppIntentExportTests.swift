#if canImport(AppIntents)
import AppIntents
import Foundation
import PageLumenCore
import XCTest
@testable import PageLumen

final class AppIntentExportTests: XCTestCase {
    func testTaggedHTMLBridgeWritesToCallerProvidedURLWithoutPrompting() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumen-intent-\(UUID().uuidString)")
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: destination) }

        try PageLumenIntentBridge.exportTaggedHTML(
            document: SampleDataFactory.makeDemoDocument(),
            to: destination
        )

        let html = try String(contentsOf: destination, encoding: .utf8)
        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("PageLumen Demo"))
    }

    func testTaggedHTMLBridgeSurfacesValidationFailure() {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumen-intent-invalid-\(UUID().uuidString)")
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: destination) }

        let document = ReaderDocument(title: "Empty", sourceType: .sample, pages: [])
        XCTAssertThrowsError(try PageLumenIntentBridge.exportTaggedHTML(document: document, to: destination)) { error in
            guard case PageLumenIntentExportError.validation = error else {
                return XCTFail("Expected a typed Tagged HTML validation error, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }
}
#endif
