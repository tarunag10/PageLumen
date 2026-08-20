import Foundation

public struct SummaryOptions: Equatable, Sendable {
    public var useIntelligence: Bool
    public var maxSentences: Int

    public init(useIntelligence: Bool = false, maxSentences: Int = 0) {
        self.useIntelligence = useIntelligence
        self.maxSentences = maxSentences
    }

    public static let `default` = SummaryOptions(useIntelligence: false, maxSentences: 0)
}

public struct SummaryCitation: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let pageNumber: Int
    public let blockID: UUID
    public let excerpt: String

    public init(pageNumber: Int, blockID: UUID, excerpt: String) {
        self.id = "page-\(pageNumber)-\(blockID.uuidString)"
        self.pageNumber = pageNumber
        self.blockID = blockID
        self.excerpt = excerpt
    }
}

/// A citation that is safe to pass between the intelligence adapter and the
/// review UI.  Unlike `SummaryCitation`, this intentionally contains no
/// extracted text.  Page and block identifiers are enough to navigate back to
/// the source without making a model response or an unavailable-result
/// payload disclose document content.
public struct GroundedSourceReference: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let pageNumber: Int
    public let blockID: UUID

    public init(pageNumber: Int, blockID: UUID) {
        self.id = "page-\(pageNumber)-\(blockID.uuidString)"
        self.pageNumber = pageNumber
        self.blockID = blockID
    }
}

public enum GroundedReviewActionKind: String, Codable, Equatable, Sendable {
    case verifySource
    case inspectOmittedContent
    case reviewLowConfidence
    case reviewUnsupportedClaim
}

/// A bounded next step for a human reviewer.  The action is a location and a
/// reason, never a copy of the source passage.
public struct GroundedReviewAction: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: GroundedReviewActionKind
    public let title: String
    public let reason: String
    public let pageNumber: Int?
    public let blockID: UUID?

    public init(
        kind: GroundedReviewActionKind,
        title: String,
        reason: String,
        pageNumber: Int? = nil,
        blockID: UUID? = nil
    ) {
        self.kind = kind
        self.title = title
        self.reason = reason
        self.pageNumber = pageNumber
        self.blockID = blockID
        let location = [pageNumber.map(String.init), blockID?.uuidString]
            .compactMap { $0 }
            .joined(separator: "-")
        self.id = "\(kind.rawValue)-\(location.isEmpty ? "document" : location)"
    }
}

public struct GroundedSummary: Codable, Equatable, Sendable {
    public let text: String
    public let citations: [SummaryCitation]
    public let groundingWarning: String?
    public let uncertaintyNotes: [String]
    public let unsupportedClaims: [String]
    /// Typed page/block locations supplied to the structured result contract.
    /// This is intentionally redundant with the human-readable citation
    /// excerpts so privacy-sensitive consumers can use IDs only.
    public let citedPageBlockIDs: [GroundedSourceReference]
    public let suggestedReviewActions: [GroundedReviewAction]
    /// Omission and selection scope for the provider request.  This metadata
    /// contains locations and counts only; it never stores prompt excerpts.
    public let contextMetadata: IntelligenceContextMetadata?
    /// Provider/session metadata for an AI-generated result. This never
    /// contains prompt text or provider diagnostics.
    public let provenance: AISummaryProvenance?

    public init(
        text: String,
        citations: [SummaryCitation],
        groundingWarning: String? = nil,
        uncertaintyNotes: [String] = [],
        unsupportedClaims: [String] = [],
        citedPageBlockIDs: [GroundedSourceReference]? = nil,
        suggestedReviewActions: [GroundedReviewAction] = [],
        contextMetadata: IntelligenceContextMetadata? = nil,
        provenance: AISummaryProvenance? = nil
    ) {
        self.text = text
        self.citations = citations
        self.groundingWarning = groundingWarning
        self.uncertaintyNotes = uncertaintyNotes
        self.unsupportedClaims = unsupportedClaims
        self.citedPageBlockIDs = citedPageBlockIDs ?? citations.map {
            GroundedSourceReference(pageNumber: $0.pageNumber, blockID: $0.blockID)
        }
        self.suggestedReviewActions = suggestedReviewActions
        self.contextMetadata = contextMetadata
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey {
        case text, citations, groundingWarning, uncertaintyNotes, unsupportedClaims,
             citedPageBlockIDs, suggestedReviewActions, contextMetadata, provenance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        citations = try container.decode([SummaryCitation].self, forKey: .citations)
        groundingWarning = try container.decodeIfPresent(String.self, forKey: .groundingWarning)
        uncertaintyNotes = try container.decodeIfPresent([String].self, forKey: .uncertaintyNotes) ?? []
        unsupportedClaims = try container.decodeIfPresent([String].self, forKey: .unsupportedClaims) ?? []
        citedPageBlockIDs = try container.decodeIfPresent([GroundedSourceReference].self, forKey: .citedPageBlockIDs)
            ?? citations.map { GroundedSourceReference(pageNumber: $0.pageNumber, blockID: $0.blockID) }
        suggestedReviewActions = try container.decodeIfPresent([GroundedReviewAction].self, forKey: .suggestedReviewActions) ?? []
        contextMetadata = try container.decodeIfPresent(IntelligenceContextMetadata.self, forKey: .contextMetadata)
        provenance = try container.decodeIfPresent(AISummaryProvenance.self, forKey: .provenance)
    }
}

/// A privacy-safe boundary for an intelligence request. Only a generated
/// result carries source excerpts; unavailable and failed outcomes carry no
/// document content and can therefore be surfaced without leaking prompts.
public enum GroundedIntelligenceResult: Codable, Equatable, Sendable {
    case generated(GroundedSummary)
    case unavailable(IntelligentExplainerAvailability)
    case failed(reason: String)

    public var summary: GroundedSummary? {
        if case .generated(let summary) = self { return summary }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case status, summary, availability, reason
    }

    private enum Status: String, Codable {
        case generated, unavailable, failed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .generated(let summary):
            try container.encode(Status.generated, forKey: .status)
            try container.encode(summary, forKey: .summary)
        case .unavailable(let availability):
            try container.encode(Status.unavailable, forKey: .status)
            try container.encode(availability, forKey: .availability)
        case .failed(let reason):
            try container.encode(Status.failed, forKey: .status)
            // Do not serialize provider diagnostics: they can accidentally
            // echo a prompt or source excerpt.
            _ = reason
            try container.encode("On-device intelligence request failed.", forKey: .reason)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Status.self, forKey: .status) {
        case .generated:
            self = .generated(try container.decode(GroundedSummary.self, forKey: .summary))
        case .unavailable:
            self = .unavailable(try container.decode(IntelligentExplainerAvailability.self, forKey: .availability))
        case .failed:
            _ = try container.decode(String.self, forKey: .reason)
            self = .failed(reason: "On-device intelligence request failed.")
        }
    }
}

public struct ExplanationEngine: Sendable {
    private let intelligenceProvider: any IntelligenceExplaining

    public init(intelligenceProvider: any IntelligenceExplaining = IntelligentExplainer()) {
        self.intelligenceProvider = intelligenceProvider
    }

    public func explain(table: TableRegion) -> String {
        let columnCount = table.rows.map(\.count).max() ?? 0
        let rowCount = table.rows.count
        let header = table.rows.first?.joined(separator: ", ") ?? "No readable header"
        var explanation = "This table appears to contain \(rowCount) rows and \(columnCount) columns. The visible header or first row reads: \(header)."

        if let firstDataRow = table.rows.dropFirst().first {
            explanation += " The first data row reads: \(firstDataRow.joined(separator: ", "))."
        }

        if table.confidence < 0.75 {
            explanation += " The table structure is uncertain and should be reviewed against the source page."
        }

        return explanation
    }

    public func explain(figure: FigureRegion) -> String {
        let typeText = figure.chartType == .unknown ? "chart or figure" : "\(figure.chartType.rawValue) chart"
        var description = "The \(typeText) appears to show visible text: \(figure.visibleText)."
        if figure.confidence < 0.75 || !figure.uncertaintyNotes.isEmpty {
            description += " Exact values may be hard to read; verify the source image before relying on this description."
        }
        return description
    }

    public func summary(for document: ReaderDocument, length: SummaryLength) -> String {
        let blocks = document.allBlocks.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !blocks.isEmpty else {
            return "No readable extracted text is available yet."
        }

        let limit: Int
        switch length {
        case .short:
            limit = 2
        case .medium:
            limit = 5
        case .detailed:
            limit = 10
        }

        let sentences = blocks.prefix(limit).map { block -> String in
            let cleaned = block.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return "Page \(block.pageNumber): \(cleaned)"
        }

        var summary = sentences.joined(separator: " ")
        if document.pages.contains(where: { $0.warning != nil }) {
            summary += " Some pages include confidence warnings, so review the source before sharing."
        }
        return summary
    }

    public func summary(for document: ReaderDocument, length: SummaryLength, options: SummaryOptions) async -> String {
        let fallback = self.summary(for: document, length: length)
        guard options.useIntelligence else { return fallback }

        guard case .available = intelligenceProvider.availability else { return fallback }

        switch await intelligenceProvider.summaryResult(for: document, length: length, selectedBlockIDs: nil) {
        case .generated(let intelligent) where !intelligent.isEmpty:
            return intelligent
        case .generated, .unavailable, .failed:
            return fallback
        }
    }

    public func betterSummary(for document: ReaderDocument, length: SummaryLength) -> String {
        guard !document.allBlocks.isEmpty else {
            return "No readable extracted text is available yet."
        }

        let allExportable = document.pages.flatMap { page in
            DocumentEditing.exportableBlocks(on: page, includeHeadersAndFooters: false)
        }
        guard !allExportable.isEmpty else {
            return "No readable extracted text is available yet."
        }

        let (headingBudget, bodyBudget) = budgets(for: length)
        let headings = allExportable.filter { $0.type == .heading }
        let bodies = allExportable.filter { $0.type != .heading }

        var collected: [String] = []
        var collectedHeadings = 0
        var collectedBodies = 0

        switch length {
        case .short:
            for block in bodies.prefix(bodyBudget) {
                collected.append(speechFriendly(block))
                collectedBodies += 1
            }
            if let firstHeading = headings.first, collectedBodies <= 1 {
                collected.insert(anchorLine(for: firstHeading), at: 0)
            } else if let firstHeading = headings.first, collected.allSatisfy({ !$0.contains(firstHeading.text) }) {
                collected.insert(anchorLine(for: firstHeading), at: 0)
            }
        case .medium:
            for block in allExportable {
                if block.type == .heading {
                    if collectedHeadings >= headingBudget { continue }
                    collected.append(anchorLine(for: block))
                    collectedHeadings += 1
                } else {
                    if collectedBodies >= bodyBudget { continue }
                    collected.append(speechFriendly(block))
                    collectedBodies += 1
                }
            }
        case .detailed:
            for block in allExportable {
                if block.type == .heading {
                    collected.append(anchorLine(for: block))
                    collectedHeadings += 1
                } else {
                    collected.append(speechFriendly(block))
                    collectedBodies += 1
                }
            }
        }

        if collected.isEmpty {
            return "No readable extracted text is available yet."
        }

        var result = collected.joined(separator: " ")
        if document.pages.contains(where: { $0.warning != nil }) {
            result += " Some pages include confidence warnings, so review the source before sharing."
        }
        return result
    }

    /// Produces the user-facing summary together with the exact extracted
    /// blocks that support it. This is the contract used by AI and export
    /// surfaces: a result is either cited or explicitly marked as needing
    /// source verification.
    public func groundedSummary(
        for document: ReaderDocument,
        length: SummaryLength,
        selectedBlockIDs: Set<UUID>? = nil
    ) -> GroundedSummary {
        let blocks = document.pages
            .flatMap { DocumentEditing.exportableBlocks(on: $0, includeHeadersAndFooters: false) }
        let scopedBlocks: [TextBlock]
        if let selectedBlockIDs, !selectedBlockIDs.isEmpty {
            scopedBlocks = blocks.filter { selectedBlockIDs.contains($0.id) }
        } else {
            scopedBlocks = blocks
        }
        let selected = Array(scopedBlocks.prefix(maxCitationBlocks(for: length)))
        let text = selectedBlockIDs == nil || selectedBlockIDs?.isEmpty == true
            ? betterSummary(for: document, length: length)
            : deterministicSummary(for: selected, length: length, document: document)
        let contextMetadata = selectedBlockIDs.map {
            IntelligenceContextBuilder.summary(for: document, length: length, selectedBlockIDs: $0).metadata
        }
        let citations = selected.map {
            SummaryCitation(
                pageNumber: $0.pageNumber,
                blockID: $0.id,
                excerpt: String(cleanText($0.text).prefix(240))
            )
        }
        let warning = citations.isEmpty || document.pages.contains(where: { $0.warning != nil })
            ? "Verify this summary against the original source before relying on it."
            : nil
        let notes = document.pages.contains(where: { $0.warning != nil })
            ? ["One or more source pages contain extraction warnings."]
            : []
        return GroundedSummary(
            text: text,
            citations: citations,
            groundingWarning: warning,
            uncertaintyNotes: notes,
            suggestedReviewActions: reviewActions(
                selected: selected,
                totalSourceBlockCount: scopedBlocks.count,
                document: document,
                unsupportedClaims: []
            ),
            contextMetadata: contextMetadata
        )
    }

    /// Returns the deterministic, cited result used when intelligence is
    /// disabled, unsupported, or fails. The reason is kept as policy metadata
    /// in the warning/uncertainty fields; no model prompt or error payload is
    /// included. This gives callers a complete result without pretending it
    /// was generated by Apple Intelligence.
    public func deterministicFallbackSummary(
        for document: ReaderDocument,
        length: SummaryLength,
        reason: String,
        selectedBlockIDs: Set<UUID>? = nil
    ) -> GroundedSummary {
        let baseline = groundedSummary(for: document, length: length, selectedBlockIDs: selectedBlockIDs)
        let safeReason = reason
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let warning = "Deterministic local summary; no generative model was used. \(safeReason)"
        return GroundedSummary(
            text: baseline.text,
            citations: baseline.citations,
            groundingWarning: warning,
            uncertaintyNotes: baseline.uncertaintyNotes + ["This is a fallback result and must be checked against the cited source."],
            unsupportedClaims: baseline.unsupportedClaims,
            citedPageBlockIDs: baseline.citedPageBlockIDs,
            suggestedReviewActions: baseline.suggestedReviewActions + [
                GroundedReviewAction(
                    kind: .verifySource,
                    title: "Verify the deterministic summary",
                    reason: "No generative model was used; compare the draft with the cited source blocks."
                )
            ],
            contextMetadata: baseline.contextMetadata
        )
    }

    /// Requests an on-device summary while retaining deterministic source
    /// citations. The result never falls back to an empty string: callers can
    /// distinguish an unavailable model from a failed request and decide how
    /// to present or retry it. Prompts and model errors are not persisted.
    public func groundedIntelligenceSummary(
        for document: ReaderDocument,
        length: SummaryLength,
        selectedBlockIDs: Set<UUID>? = nil
    ) async -> GroundedIntelligenceResult {
        let sourceBlocks = document.pages
            .flatMap { DocumentEditing.exportableBlocks(on: $0, includeHeadersAndFooters: false) }
        guard !sourceBlocks.isEmpty else {
            return .failed(reason: "No readable extracted text is available yet.")
        }

        let result = await intelligenceProvider.summaryResult(
            for: document,
            length: length,
            selectedBlockIDs: selectedBlockIDs
        )
        switch result {
        case .unavailable(let availability):
            return .unavailable(availability)
        case .failed(let reason):
            // Keep provider diagnostics out of the user-facing/result
            // boundary.  The typed result only needs a bounded, single-line
            // policy reason; it must never echo a prompt or source excerpt.
            return .failed(reason: "On-device intelligence request failed: \(safeDiagnostic(reason))")
        case .generated(let text):
            let scopedBlocks = selectedBlockIDs.flatMap { ids in
                sourceBlocks.filter { ids.contains($0.id) }
            } ?? sourceBlocks
            let selected = Array(scopedBlocks.prefix(maxCitationBlocks(for: length)))
            let contextMetadata = IntelligenceContextBuilder.summary(
                for: document,
                length: length,
                selectedBlockIDs: selectedBlockIDs
            ).metadata
            let citations = selected.map {
                SummaryCitation(
                    pageNumber: $0.pageNumber,
                    blockID: $0.id,
                    excerpt: String(cleanText($0.text).prefix(240))
                )
            }
            var notes: [String] = []
            if contextMetadata.omittedBlockCount > 0 {
                notes.append("The model received \(contextMetadata.includedBlockCount) of \(contextMetadata.sourceBlockCount) readable source blocks.")
            }
            if document.pages.contains(where: { $0.warning != nil }) {
                notes.append("One or more source pages contain extraction warnings.")
            }
            let warning = notes.isEmpty ? nil : "Verify this generated draft against the original source before relying on it."
            let actions = reviewActions(
                selected: selected,
                totalSourceBlockCount: scopedBlocks.count,
                document: document,
                unsupportedClaims: []
            )
            let provenance = AISummaryProvenance(
                provider: "apple-foundation-models",
                modelIdentifier: "SystemLanguageModel.default",
                summaryLength: length,
                context: contextMetadata,
                citedPageBlockIDs: citations.map {
                    GroundedSourceReference(pageNumber: $0.pageNumber, blockID: $0.blockID)
                }
            )
            return .generated(
                GroundedSummary(
                    text: text,
                    citations: citations,
                    groundingWarning: warning,
                    uncertaintyNotes: notes,
                    suggestedReviewActions: actions,
                    contextMetadata: contextMetadata,
                    provenance: provenance
                )
            )
        }
    }

    /// A selection-scoped local summary used when intelligence is disabled or
    /// unavailable.  It deliberately uses only the selected blocks so the
    /// fallback has the same scope as the opted-in request.
    private func deterministicSummary(
        for blocks: [TextBlock],
        length: SummaryLength,
        document: ReaderDocument
    ) -> String {
        guard !blocks.isEmpty else { return "No readable extracted text is available for this selection." }
        let limit: Int
        switch length {
        case .short: limit = 2
        case .medium: limit = 5
        case .detailed: limit = 10
        }
        let body = blocks.prefix(limit).map { block in
            let prefix = block.type == .heading ? "Section: " : "Page \(block.pageNumber): "
            return prefix + speechFriendly(block)
        }
        var result = body.joined(separator: " ")
        if document.pages.contains(where: { $0.warning != nil }) {
            result += " Some pages include confidence warnings, so review the source before sharing."
        }
        return result
    }

    private func reviewActions(
        selected: [TextBlock],
        totalSourceBlockCount: Int,
        document: ReaderDocument,
        unsupportedClaims: [String]
    ) -> [GroundedReviewAction] {
        var actions: [GroundedReviewAction] = []
        if selected.count < totalSourceBlockCount {
            actions.append(
                GroundedReviewAction(
                    kind: .inspectOmittedContent,
                    title: "Inspect omitted source content",
                    reason: "The result was generated from a bounded subset of readable source blocks."
                )
            )
        }
        for page in document.pages where page.warning != nil {
            actions.append(
                GroundedReviewAction(
                    kind: .reviewLowConfidence,
                    title: "Review page \(page.pageNumber)",
                    reason: "This page has an extraction warning; compare the result with the original page.",
                    pageNumber: page.pageNumber
                )
            )
        }
        if !unsupportedClaims.isEmpty {
            actions.append(
                GroundedReviewAction(
                    kind: .reviewUnsupportedClaim,
                    title: "Review unsupported claims",
                    reason: "One or more claims could not be grounded in the selected source blocks."
                )
            )
        }
        if actions.isEmpty && selected.isEmpty {
            actions.append(
                GroundedReviewAction(
                    kind: .verifySource,
                    title: "Verify against the source",
                    reason: "No source block could be cited for this result."
                )
            )
        }
        return actions
    }

    private func maxCitationBlocks(for length: SummaryLength) -> Int {
        switch length {
        case .short: return 3
        case .medium: return 8
        case .detailed: return 24
        }
    }

    private func safeDiagnostic(_ reason: String) -> String {
        let cleaned = reason
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(160))
    }

    private func budgets(for length: SummaryLength) -> (headings: Int, bodies: Int) {
        switch length {
        case .short: return (1, 2)
        case .medium: return (3, 4)
        case .detailed: return (Int.max, Int.max)
        }
    }

    private func anchorLine(for block: TextBlock) -> String {
        let cleaned = cleanText(block.text)
        return "Section: \(cleaned)."
    }

    private func speechFriendly(_ block: TextBlock) -> String {
        let cleaned = cleanText(block.text)
        let rewritten = VisibleReferenceRewriter.rewrite(cleaned)
        if block.type == .figure || block.type == .table {
            return rewritten.isEmpty ? rewritten : "\(rewritten)."
        }
        return rewritten
    }

    private func cleanText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum VisibleReferenceRewriter {
    private static let figurePattern = #"(?i)\b(see|refer to|shown in|shown on|as in|in)\s+figure\s+\d+[a-z]?\b"#
    private static let tablePattern = #"(?i)\b(see|refer to|shown in|shown on|as in|in)\s+table\s+\d+[a-z]?\b"#
    private static let pagePattern = #"(?i)\b(on|see)\s+page\s+\d+\b"#
    private static let sectionPattern = #"(?i)\b(see|refer to|as in)\s+section\s+\d+(\.\d+)*\b"#

    static func rewrite(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: figurePattern, with: "a figure on this page", options: .regularExpression)
        result = result.replacingOccurrences(of: tablePattern, with: "a table on this page", options: .regularExpression)
        result = result.replacingOccurrences(of: pagePattern, with: "on a nearby page", options: .regularExpression)
        result = result.replacingOccurrences(of: sectionPattern, with: "in another section", options: .regularExpression)
        return result
    }
}
