import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum IntelligentExplainerAvailability: Codable, Equatable, Sendable {
    case available
    case unavailable(reason: String)
    case notSupported

    private enum CodingKeys: String, CodingKey { case status, reason }
    private enum Status: String, Codable { case available, unavailable, notSupported }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .available:
            try container.encode(Status.available, forKey: .status)
        case .unavailable:
            try container.encode(Status.unavailable, forKey: .status)
            // Availability is a capability state, not a diagnostic channel.
            // Do not serialize provider text, which could accidentally echo
            // request/source content. The in-memory value remains available
            // to the Settings explanation before persistence/transport.
        case .notSupported:
            try container.encode(Status.notSupported, forKey: .status)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Status.self, forKey: .status) {
        case .available: self = .available
        case .unavailable:
            self = .unavailable(reason: "Apple Intelligence is unavailable on this Mac.")
        case .notSupported: self = .notSupported
        }
    }

}

/// The copy used by UI surfaces before an intelligence request starts.  It
/// deliberately contains policy text, not document text or model prompts.
public struct IntelligentExplainerAvailabilityInfo: Equatable, Sendable {
    public let availability: IntelligentExplainerAvailability
    public let title: String
    public let message: String
    public let privacyBoundary: String
    public let deviceRequirement: String
    public let inputScope: String

    public init(availability: IntelligentExplainerAvailability) {
        self.availability = availability
        self.privacyBoundary = "On-device only; prompts and responses are not retained by PageLumen."
        self.inputScope = "Only the bounded, source-labelled blocks selected for this operation are provided."
        switch availability {
        case .available:
            title = "Available on this Mac"
            message = "Results are drafts and require review against cited source pages."
            deviceRequirement = "Apple Intelligence-compatible Mac with the on-device model ready."
        case .unavailable(let reason):
            title = "Temporarily unavailable"
            message = "\(reason) PageLumen will use its deterministic local fallback."
            deviceRequirement = "Apple Intelligence-compatible Mac and a ready on-device model."
        case .notSupported:
            title = "Not supported on this macOS release"
            message = "Upgrade to a supported macOS release to enable on-device intelligence."
            deviceRequirement = "macOS 26 or later with Apple Intelligence support."
        }
    }

    public var canExecute: Bool {
        if case .available = availability { return true }
        return false
    }
}

/// The outcome of an opt-in Foundation Models request. The legacy string APIs
/// below remain available for callers that only need text; new callers can use
/// this value to explain why a result was not generated.
public enum IntelligentExplainerResult: Equatable, Sendable {
    case generated(String)
    case unavailable(IntelligentExplainerAvailability)
    case failed(reason: String)

    public var text: String? {
        if case .generated(let text) = self { return text }
        return nil
    }
}

public struct IntelligentExplainer: Sendable {
    public init() {}

    public var availability: IntelligentExplainerAvailability {
        if #available(macOS 26.0, *) {
            return Self.checkAvailabilityOnMacOS26()
        } else {
            return .notSupported
        }
    }

    public var availabilityInfo: IntelligentExplainerAvailabilityInfo {
        IntelligentExplainerAvailabilityInfo(availability: availability)
    }

    public func summary(for document: ReaderDocument, length: SummaryLength) async -> String {
        let result = await summaryResult(for: document, length: length)
        return result.text ?? ""
    }

    public func summaryResult(for document: ReaderDocument, length: SummaryLength) async -> IntelligentExplainerResult {
        await summaryResult(for: document, length: length, selectedBlockIDs: nil)
    }

    /// Requests a summary for an explicit block selection.  The selection is
    /// resolved and bounded before any provider call; unknown IDs are ignored
    /// and the provider sees source labels plus an omission notice, never an
    /// unbounded document dump.
    public func summaryResult(
        for document: ReaderDocument,
        length: SummaryLength,
        selectedBlockIDs: Set<UUID>?
    ) async -> IntelligentExplainerResult {
        guard #available(macOS 26.0, *) else {
            return .unavailable(.notSupported)
        }
        guard case .available = availability else {
            return .unavailable(availability)
        }
        let context = IntelligenceContextBuilder.summary(
            for: document,
            length: length,
            selectedBlockIDs: selectedBlockIDs
        )
        guard context.metadata.includedBlockCount > 0 else {
            return .failed(reason: "No readable extracted text is available for this selection.")
        }
        return await summarizeOnMacOS26(context: context)
    }

    public func explain(table: TableRegion) async -> String {
        let result = await explainTableResult(table: table)
        return result.text ?? ""
    }

    public func explainTableResult(table: TableRegion) async -> IntelligentExplainerResult {
        guard #available(macOS 26.0, *) else {
            return .unavailable(.notSupported)
        }
        guard case .available = availability else {
            return .unavailable(availability)
        }
        return await explainTableOnMacOS26(table: table)
    }

    public func explain(figure: FigureRegion) async -> String {
        let result = await explainFigureResult(figure: figure)
        return result.text ?? ""
    }

    public func explainFigureResult(figure: FigureRegion) async -> IntelligentExplainerResult {
        guard #available(macOS 26.0, *) else {
            return .unavailable(.notSupported)
        }
        guard case .available = availability else {
            return .unavailable(availability)
        }
        return await explainFigureOnMacOS26(figure: figure)
    }

    @available(macOS 26.0, *)
    private static func checkAvailabilityOnMacOS26() -> IntelligentExplainerAvailability {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: describe(reason: reason))
        }
        #else
        return .unavailable(reason: "FoundationModels framework not available in this build")
        #endif
    }

    @available(macOS 26.0, *)
    private func summarizeOnMacOS26(context: BoundedIntelligenceContext) async -> IntelligentExplainerResult {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return .unavailable(Self.checkAvailabilityOnMacOS26()) }
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: context.prompt,
                generating: GeneratedSummaryPayload.self
            )
            // Page references are schema-validated but are not trusted as the
            // app's citations. GroundedSummary derives citations from the
            // bounded source blocks supplied to this request.
            let text = response.content.body.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failed(reason: "The on-device model returned an empty response.") : .generated(text)
        } catch {
            return .failed(reason: error.localizedDescription)
        }
        #else
        return .unavailable(.unavailable(reason: "FoundationModels framework not available in this build"))
        #endif
    }

    @available(macOS 26.0, *)
    private func explainTableOnMacOS26(table: TableRegion) async -> IntelligentExplainerResult {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return .unavailable(Self.checkAvailabilityOnMacOS26()) }
        do {
            let session = LanguageModelSession()
            let prompt = Self.tablePrompt(table: table)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failed(reason: "The on-device model returned an empty response.") : .generated(text)
        } catch {
            return .failed(reason: error.localizedDescription)
        }
        #else
        return .unavailable(.unavailable(reason: "FoundationModels framework not available in this build"))
        #endif
    }

    @available(macOS 26.0, *)
    private func explainFigureOnMacOS26(figure: FigureRegion) async -> IntelligentExplainerResult {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return .unavailable(Self.checkAvailabilityOnMacOS26()) }
        do {
            let session = LanguageModelSession()
            let prompt = Self.figurePrompt(figure: figure)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failed(reason: "The on-device model returned an empty response.") : .generated(text)
        } catch {
            return .failed(reason: error.localizedDescription)
        }
        #else
        return .unavailable(.unavailable(reason: "FoundationModels framework not available in this build"))
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func describe(reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This Mac does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled in System Settings."
        case .modelNotReady:
            return "The on-device model is still downloading or preparing."
        @unknown default:
            return "Apple Intelligence is unavailable for an unknown reason."
        }
    }

    @available(macOS 26.0, *)
    @available(macOS 26.0, *)
    private static func tablePrompt(table: TableRegion) -> String {
        let rows = table.rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        return "Describe the following table in plain language for a screen-reader user. Mention row/column counts, the header, and the first data row. If confidence is below 0.75, advise the user to verify against the source.\nConfidence: \(table.confidence)\n\n\(rows)"
    }

    @available(macOS 26.0, *)
    private static func figurePrompt(figure: FigureRegion) -> String {
        let typeText = figure.chartType == .unknown ? "chart or figure" : "\(figure.chartType.rawValue) chart"
        return "Describe the following \(typeText) in plain language for a screen-reader user, grounded only in the visible text. Mention uncertainty if the confidence is below 0.75 or uncertainty notes are present.\nConfidence: \(figure.confidence)\nUncertainty notes: \(figure.uncertaintyNotes.joined(separator: "; "))\n\nVisible text: \(figure.visibleText)"
    }

    #endif
}

#if canImport(FoundationModels)
/// The only Foundation Models response shape currently accepted by PageLumen.
/// Page references are model-side hints; trusted citations remain local
/// page/block IDs validated by the grounding layer.
@available(macOS 26.0, *)
@Generable(description: "A concise document summary grounded only in the supplied source blocks.")
private struct GeneratedSummaryPayload {
    var body: String
    var pageReferences: [Int]
}
#endif
