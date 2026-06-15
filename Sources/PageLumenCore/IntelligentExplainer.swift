import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum IntelligentExplainerAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
    case notSupported
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

    public func summary(for document: ReaderDocument, length: SummaryLength) async -> String {
        guard #available(macOS 26.0, *) else { return "" }
        return await summarizeOnMacOS26(document: document, length: length)
    }

    public func explain(table: TableRegion) async -> String {
        guard #available(macOS 26.0, *) else { return "" }
        return await explainTableOnMacOS26(table: table)
    }

    public func explain(figure: FigureRegion) async -> String {
        guard #available(macOS 26.0, *) else { return "" }
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
    private func summarizeOnMacOS26(document: ReaderDocument, length: SummaryLength) async -> String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return "" }
        do {
            let session = LanguageModelSession()
            let prompt = Self.summaryPrompt(document: document, length: length)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
        #else
        return ""
        #endif
    }

    @available(macOS 26.0, *)
    private func explainTableOnMacOS26(table: TableRegion) async -> String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return "" }
        do {
            let session = LanguageModelSession()
            let prompt = Self.tablePrompt(table: table)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
        #else
        return ""
        #endif
    }

    @available(macOS 26.0, *)
    private func explainFigureOnMacOS26(figure: FigureRegion) async -> String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return "" }
        do {
            let session = LanguageModelSession()
            let prompt = Self.figurePrompt(figure: figure)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
        #else
        return ""
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
    private static func summaryPrompt(document: ReaderDocument, length: SummaryLength) -> String {
        let body = document.allBlocks
            .prefix(blockBudget(for: length))
            .map { "Page \($0.pageNumber): \($0.text)" }
            .joined(separator: "\n")
        let audience = audienceHint(for: length)
        return "Summarize the following extracted document text in \(audience). Ground every sentence in the provided text only; do not add outside knowledge. Do not invent figures, tables, or values.\n\n\(body)"
    }

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

    @available(macOS 26.0, *)
    private static func blockBudget(for length: SummaryLength) -> Int {
        switch length {
        case .short: return 4
        case .medium: return 8
        case .detailed: return 16
        }
    }

    @available(macOS 26.0, *)
    private static func audienceHint(for length: SummaryLength) -> String {
        switch length {
        case .short: return "one or two sentences"
        case .medium: return "a short paragraph"
        case .detailed: return "a detailed walkthrough"
        }
    }
    #endif
}
