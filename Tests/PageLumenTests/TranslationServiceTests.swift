import PageLumenCore
import XCTest
@testable import PageLumen

@MainActor
final class TranslationServiceTests: XCTestCase {
    func testTranslateReturnsInputOnUnsupportedOS() async throws {
        let text = "Hello, world."
        let result = try await TranslationService().translate(text, to: Locale.Language(identifier: "es"))
        XCTAssertEqual(result, text)
    }

    func testTranslateDocumentPreservesBlockCount() async throws {
        let document = SampleDataFactory.makeDemoDocument()
        let originalBlockCount = document.allBlocks.count
        let translated = try await TranslationService().translate(document: document, to: Locale.Language(identifier: "es"))
        XCTAssertEqual(translated.allBlocks.count, originalBlockCount)
    }

    func testTranslateStampsMetadataOnTranslatedBlocks() async throws {
        let document = SampleDataFactory.makeDemoDocument()
        let translated = try await TranslationService().translate(document: document, to: Locale.Language(identifier: "es"))
        XCTAssertFalse(translated.pages.isEmpty)
        let hasTranslatedBlock = translated.allBlocks.contains { block in
            block.metadata["translationTargetLanguage"] != nil
        }
        if #available(macOS 15.0, *) {
            XCTAssertTrue(hasTranslatedBlock, "On macOS 15+, the translation service should stamp the target language metadata on translated blocks.")
        }
    }
}
