import Foundation
import PageLumenCore
#if canImport(Translation)
import Translation
#endif

@MainActor
public final class TranslationService {
    public init() {}

    public func translate(_ text: String, to target: Locale.Language) async throws -> String {
        if #available(macOS 15.0, *) {
            return try await translateOnMacOS15(text: text, to: target)
        }
        return text
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

    @available(macOS 15.0, *)
    private func translateOnMacOS15(text: String, to target: Locale.Language) async throws -> String {
        return text
    }
}
