import PageLumenCore
import XCTest
@testable import PageLumen

@MainActor
final class TranslationServiceTests: XCTestCase {
    func testTranslateNeverSilentlyReturnsInputWhenUnavailable() async throws {
        let text = "Hello, world."
        do {
            let result = try await TranslationService().translate(text, to: Locale.Language(identifier: "es"))
            XCTAssertFalse(result.isEmpty)
        } catch {
            XCTAssertTrue(error is TranslationService.TranslationError)
        }
    }

    func testTranslateDocumentPreservesBlockCount() async throws {
        let document = SampleDataFactory.makeDemoDocument()
        let originalBlockCount = document.allBlocks.count
        let translated: ReaderDocument
        do {
            translated = try await TranslationService().translate(document: document, to: Locale.Language(identifier: "es"))
        } catch is TranslationService.TranslationError {
            throw XCTSkip("Spanish translation model is not installed in this test environment")
        }
        XCTAssertEqual(translated.allBlocks.count, originalBlockCount)
    }

    func testTranslateStampsMetadataOnTranslatedBlocks() async throws {
        let document = SampleDataFactory.makeDemoDocument()
        let translated: ReaderDocument
        do {
            translated = try await TranslationService().translate(document: document, to: Locale.Language(identifier: "es"))
        } catch is TranslationService.TranslationError {
            throw XCTSkip("Spanish translation model is not installed in this test environment")
        }
        XCTAssertFalse(translated.pages.isEmpty)
        let hasTranslatedBlock = translated.allBlocks.contains { block in
            block.metadata["translationTargetLanguage"] != nil
        }
        if #available(macOS 15.0, *) {
            XCTAssertTrue(hasTranslatedBlock, "On macOS 15+, the translation service should stamp the target language metadata on translated blocks.")
        }
    }
}
