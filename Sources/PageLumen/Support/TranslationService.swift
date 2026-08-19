import Foundation
import PageLumenCore
#if canImport(Translation)
import Translation
#endif

@MainActor
public final class TranslationService {
    public enum TranslationError: LocalizedError {
        case unavailable
        case emptyResult

        public var errorDescription: String? {
            switch self {
            case .unavailable: return "On-device translation is unavailable for the selected language on this Mac."
            case .emptyResult: return "The translation service returned no text."
            }
        }
    }

    public init() {}

    public func translate(_ text: String, to target: Locale.Language) async throws -> String {
        guard #available(macOS 26.0, *) else {
            throw TranslationError.unavailable
        }
        #if canImport(Translation)
            return try await translateOnMacOS15(text: text, to: target)
        #else
            throw TranslationError.unavailable
        #endif
    }

    public func translate(document: ReaderDocument, to target: Locale.Language) async throws -> ReaderDocument {
        var copy = document
        for pageIndex in copy.pages.indices {
            for blockIndex in copy.pages[pageIndex].blocks.indices {
                let original = copy.pages[pageIndex].blocks[blockIndex].text
                if !original.isEmpty {
                    let translated = try await translate(original, to: target)
                    copy.pages[pageIndex].blocks[blockIndex].text = translated
                    copy.pages[pageIndex].blocks[blockIndex].metadata["translationTargetLanguage"] = target.maximalIdentifier
                }
            }
        }
        return copy
    }

    @available(macOS 26.0, *)
    private func translateOnMacOS15(text: String, to target: Locale.Language) async throws -> String {
        #if canImport(Translation)
        // The standalone session initializer requires an installed source
        // language. The current MVP only advertises translation for English
        // source documents; other source languages are rejected by the UI.
        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: target
        )
        try await session.prepareTranslation()
        let response = try await session.translate(text)
        guard !response.targetText.isEmpty else { throw TranslationError.emptyResult }
        return response.targetText
        #else
        throw TranslationError.unavailable
        #endif
    }
}
