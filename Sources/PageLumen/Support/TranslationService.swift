import Foundation
import PageLumenCore
#if canImport(Translation)
import Translation
#endif

@MainActor
public final class TranslationService {
    public enum Availability: String, Codable, Sendable, Equatable {
        case available
        case downloadable
        case unsupported
        case unavailable
    }

    @MainActor
    public protocol TranslationProviding {
        var engineName: String { get }
        func availability(for target: Locale.Language) -> Availability
        func translate(_ text: String, to target: Locale.Language) async throws -> String
    }

    public enum TranslationError: LocalizedError {
        case unavailable
        case downloadRequired
        case emptyResult
        case unchangedOutput
        case partialFailure(blockIndex: Int, underlying: String)

        public var errorDescription: String? {
            switch self {
            case .unavailable: return "On-device translation is unavailable for the selected language on this Mac."
            case .downloadRequired: return "The language model must be downloaded and approved before translation can continue."
            case .emptyResult: return "The translation service returned no text."
            case .unchangedOutput: return "Translation returned the source text; no translated export was created."
            case let .partialFailure(blockIndex, underlying):
                return "Translation failed for block \(blockIndex + 1): \(underlying)"
            }
        }
    }

    private let provider: any TranslationProviding

    public init(provider: (any TranslationProviding)? = nil) {
        self.provider = provider ?? AppleTranslationProvider()
    }

    public func availability(for target: Locale.Language) -> Availability {
        provider.availability(for: target)
    }

    public func translate(_ text: String, to target: Locale.Language) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyResult
        }
        switch provider.availability(for: target) {
        case .available:
            break
        case .downloadable:
            throw TranslationError.downloadRequired
        case .unsupported, .unavailable:
            throw TranslationError.unavailable
        }
        let translated = try await provider.translate(text, to: target)
        guard !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyResult
        }
        guard translated.trimmingCharacters(in: .whitespacesAndNewlines)
            != text.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw TranslationError.unchangedOutput
        }
        return translated
    }

    public func translate(document: ReaderDocument, to target: Locale.Language) async throws -> ReaderDocument {
        var copy = document
        var translatedBlockIndex = 0
        for pageIndex in copy.pages.indices {
            for blockIndex in copy.pages[pageIndex].blocks.indices {
                let original = copy.pages[pageIndex].blocks[blockIndex].text
                if !original.isEmpty {
                    let translated: String
                    do {
                        try Task.checkCancellation()
                        translated = try await translate(original, to: target)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch let error as TranslationError {
                        if translatedBlockIndex == 0 { throw error }
                        throw TranslationError.partialFailure(blockIndex: translatedBlockIndex, underlying: error.localizedDescription)
                    } catch {
                        if translatedBlockIndex == 0 { throw error }
                        throw TranslationError.partialFailure(blockIndex: translatedBlockIndex, underlying: error.localizedDescription)
                    }
                    copy.pages[pageIndex].blocks[blockIndex].text = translated
                    copy.pages[pageIndex].blocks[blockIndex].metadata["translatedFrom"] = original
                    copy.pages[pageIndex].blocks[blockIndex].metadata["translationTargetLanguage"] = target.maximalIdentifier
                    copy.pages[pageIndex].blocks[blockIndex].metadata["translationEngine"] = provider.engineName
                    translatedBlockIndex += 1
                }
            }
        }
        return copy
    }
}

@MainActor
private final class AppleTranslationProvider: TranslationService.TranslationProviding {
    let engineName = "Apple Translation"

    func availability(for target: Locale.Language) -> TranslationService.Availability {
        guard #available(macOS 26.0, *) else { return .unsupported }
        // TranslationSession reports missing language models when prepared.
        // Keep the capability conservative until the user invokes translation;
        // the resulting framework error is normalized to `.unavailable`.
        return target.maximalIdentifier.isEmpty ? .unavailable : .available
    }

    func translate(_ text: String, to target: Locale.Language) async throws -> String {
        guard #available(macOS 26.0, *) else {
            throw TranslationService.TranslationError.unavailable
        }
        #if canImport(Translation)
        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: target
        )
        do {
            try await session.prepareTranslation()
            let response = try await session.translate(text)
            guard !response.targetText.isEmpty else { throw TranslationService.TranslationError.emptyResult }
            return response.targetText
        } catch let error as TranslationService.TranslationError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TranslationService.TranslationError.unavailable
        }
        #else
        throw TranslationService.TranslationError.unavailable
        #endif
    }
}
