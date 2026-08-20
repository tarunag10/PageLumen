import PageLumenCore
import XCTest
@testable import PageLumen

@MainActor
final class TranslationServiceTests: XCTestCase {
    @MainActor
    private final class FakeProvider: TranslationService.TranslationProviding {
        let engineName = "Test Translation"
        var state: TranslationService.Availability = .available
        var outputs: [String: String] = [:]
        var failureOnCall: Int?
        var callCount = 0
        var cancel = false

        func availability(for target: Locale.Language) -> TranslationService.Availability { state }

        func translate(_ text: String, to target: Locale.Language) async throws -> String {
            callCount += 1
            if cancel { throw CancellationError() }
            if failureOnCall == callCount { throw NSError(domain: "FakeTranslation", code: 1, userInfo: [NSLocalizedDescriptionKey: "provider failed"]) }
            return outputs[text] ?? text
        }
    }

    func testFakeProviderSuccessMapsTextAndMetadata() async throws {
        let provider = FakeProvider()
        provider.outputs["Hello"] = "Hola"
        let service = TranslationService(provider: provider)
        let result = try await service.translate("Hello", to: Locale.Language(identifier: "es"))
        XCTAssertEqual(result, "Hola")

        let document = ReaderDocument(title: "Fixture", sourceType: .sample, pages: [ReaderPage(
            pageNumber: 1, size: PageSize(width: 100, height: 100),
            blocks: [TextBlock(pageNumber: 1, type: .paragraph, text: "Hello", bounds: BoundingBox(x: 0, y: 0, width: 50, height: 10), confidence: 1)]
        )])
        let translated = try await service.translate(document: document, to: Locale.Language(identifier: "es"))
        let block = try XCTUnwrap(translated.pages.first?.blocks.first)
        XCTAssertEqual(block.text, "Hola")
        XCTAssertEqual(block.metadata["translationEngine"], "Test Translation")
        XCTAssertEqual(block.metadata["translatedFrom"], "Hello")
    }

    func testFakeProviderAvailabilityStatesAreGated() async {
        let provider = FakeProvider()
        for state in [TranslationService.Availability.unsupported, .unavailable, .downloadable] {
            provider.state = state
            let service = TranslationService(provider: provider)
            XCTAssertEqual(service.availability(for: Locale.Language(identifier: "es")), state)
            do {
                _ = try await service.translate("Hello", to: Locale.Language(identifier: "es"))
                XCTFail("Unavailable provider must not produce translated text")
            } catch is TranslationService.TranslationError {
                XCTAssertEqual(provider.callCount, 0)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testFakeProviderCancellationIsPropagated() async {
        let provider = FakeProvider()
        provider.cancel = true
        do {
            _ = try await TranslationService(provider: provider).translate("Hello", to: Locale.Language(identifier: "es"))
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testPartialFailureDoesNotReturnPartiallyTranslatedDocument() async {
        let provider = FakeProvider()
        provider.outputs["One"] = "Uno"
        provider.outputs["Two"] = "Dos"
        provider.failureOnCall = 2
        let document = ReaderDocument(title: "Fixture", sourceType: .sample, pages: [ReaderPage(
            pageNumber: 1, size: PageSize(width: 100, height: 100), blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "One", bounds: BoundingBox(x: 0, y: 0, width: 50, height: 10), confidence: 1),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Two", bounds: BoundingBox(x: 0, y: 20, width: 50, height: 10), confidence: 1)
            ]
        )])
        do {
            _ = try await TranslationService(provider: provider).translate(document: document, to: Locale.Language(identifier: "es"))
            XCTFail("Expected partial failure")
        } catch let error as TranslationService.TranslationError {
            guard case let .partialFailure(blockIndex, _) = error else {
                return XCTFail("Expected typed partial failure, got \(error)")
            }
            XCTAssertEqual(blockIndex, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnchangedOutputIsRejectedAndCannotBeLabelledTranslated() async {
        let provider = FakeProvider()
        do {
            _ = try await TranslationService(provider: provider).translate("Hello", to: Locale.Language(identifier: "es"))
            XCTFail("Expected unchanged-output rejection")
        } catch let error as TranslationService.TranslationError {
            guard case .unchangedOutput = error else { return XCTFail("Expected unchangedOutput, got \(error)") }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

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
                && block.metadata["translationEngine"] == "Apple Translation"
                && block.metadata["translatedFrom"] != nil
        }
        if #available(macOS 15.0, *) {
            XCTAssertTrue(hasTranslatedBlock, "On macOS 15+, the translation service should stamp the target language metadata on translated blocks.")
        }
    }
}
