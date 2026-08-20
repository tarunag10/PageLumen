import Foundation

/// The non-content metadata for one bounded intelligence request.  It tells a
/// caller which source locations were available to the model without copying
/// extracted passages into a second persistence or telemetry boundary.
public struct IntelligenceContextMetadata: Codable, Equatable, Sendable {
    public let isSelectionScoped: Bool
    public let requestedBlockCount: Int
    public let sourceBlockCount: Int
    public let includedBlockCount: Int
    public let omittedBlockCount: Int
    public let includedPageNumbers: [Int]
    public let omittedPageNumbers: [Int]
    public let includedSectionLabels: [String]
    public let omittedSectionLabels: [String]

    public init(
        isSelectionScoped: Bool,
        requestedBlockCount: Int,
        sourceBlockCount: Int,
        includedBlockCount: Int,
        omittedBlockCount: Int,
        includedPageNumbers: [Int],
        omittedPageNumbers: [Int],
        includedSectionLabels: [String],
        omittedSectionLabels: [String]
    ) {
        self.isSelectionScoped = isSelectionScoped
        self.requestedBlockCount = requestedBlockCount
        self.sourceBlockCount = sourceBlockCount
        self.includedBlockCount = includedBlockCount
        self.omittedBlockCount = omittedBlockCount
        self.includedPageNumbers = includedPageNumbers
        self.omittedPageNumbers = omittedPageNumbers
        self.includedSectionLabels = includedSectionLabels
        self.omittedSectionLabels = omittedSectionLabels
    }
}

/// A prompt assembled from source-labelled blocks and bounded before it is
/// handed to an intelligence provider.  The prompt is intentionally an
/// ephemeral value; only `metadata` is suitable for persistence or telemetry.
public struct BoundedIntelligenceContext: Equatable, Sendable {
    public let prompt: String
    public let metadata: IntelligenceContextMetadata

    public init(prompt: String, metadata: IntelligenceContextMetadata) {
        self.prompt = prompt
        self.metadata = metadata
    }
}

public enum IntelligenceContextBuilder {
    /// Builds a source-labelled, deterministic context for a summary request.
    /// Selection IDs are resolved against exportable source blocks in reading
    /// order.  Unknown IDs are ignored and never become invented source text.
    public static func summary(
        for document: ReaderDocument,
        length: SummaryLength,
        selectedBlockIDs: Set<UUID>? = nil,
        maximumCharacters: Int = 12_000
    ) -> BoundedIntelligenceContext {
        let sourceBlocks = document.pages
            .flatMap { DocumentEditing.exportableBlocks(on: $0, includeHeadersAndFooters: false) }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let selection = selectedBlockIDs?.filter { id in sourceBlocks.contains { $0.id == id } } ?? []
        let candidates: [TextBlock]
        if selectedBlockIDs == nil || selection.isEmpty {
            candidates = sourceBlocks
        } else {
            candidates = sourceBlocks.filter { selection.contains($0.id) }
        }

        let blockLimit = blockBudget(for: length)
        let bounded = Array(candidates.prefix(blockLimit))
        let includedIDs = Set(bounded.map(\.id))
        let omitted = sourceBlocks.filter { !includedIDs.contains($0.id) }
        let sections = sectionLabels(for: document)
        let includedPages = orderedUnique(bounded.map(\.pageNumber))
        let omittedPages = orderedUnique(omitted.map(\.pageNumber))
        let includedSections = bounded.compactMap { sections[$0.id] }.orderedUnique()
        let omittedSections = omitted.compactMap { sections[$0.id] }.orderedUnique()
        let metadata = IntelligenceContextMetadata(
            isSelectionScoped: selectedBlockIDs != nil,
            requestedBlockCount: selectedBlockIDs == nil ? sourceBlocks.count : selection.count,
            sourceBlockCount: sourceBlocks.count,
            includedBlockCount: bounded.count,
            omittedBlockCount: omitted.count,
            includedPageNumbers: includedPages,
            omittedPageNumbers: omittedPages,
            includedSectionLabels: includedSections,
            omittedSectionLabels: omittedSections
        )

        let audience = audienceHint(for: length)
        let lines = bounded.map { block in
            let pageLabel = document.pages.first(where: { $0.pageNumber == block.pageNumber })?.pageLabel
            let page = pageLabel.map { "page \(block.pageNumber), label \($0)" } ?? "page \(block.pageNumber)"
            let section = sections[block.id].map { ", section \"\($0)\"" } ?? ""
            return "[Source \(page)\(section), block \(block.id.uuidString)] \(clean(block.text))"
        }
        let omission = omissionLine(metadata)
        let instruction = "Summarize only the provided source blocks in \(audience). Ground every sentence in those blocks. Do not add outside knowledge, invent values, or treat page/section locations listed as omitted as evidence. Preserve uncertainty and tell the reader when the source is incomplete."
        var prompt = instruction + "\n\n" + lines.joined(separator: "\n")
        if !omission.isEmpty {
            prompt += "\n\n" + omission
        }
        if prompt.count > maximumCharacters, maximumCharacters > 0 {
            // The block limit is the primary bound.  This second guard keeps a
            // pathological OCR block from defeating the provider budget.
            let marker = "\n[Source text truncated by PageLumen's safety bound.]"
            let prefixLimit = max(0, maximumCharacters - marker.count)
            prompt = String(prompt.prefix(prefixLimit)) + marker
        }
        return BoundedIntelligenceContext(prompt: prompt, metadata: metadata)
    }

    private static func blockBudget(for length: SummaryLength) -> Int {
        switch length {
        case .short: return 4
        case .medium: return 8
        case .detailed: return 16
        }
    }

    private static func audienceHint(for length: SummaryLength) -> String {
        switch length {
        case .short: return "one or two sentences"
        case .medium: return "a short paragraph"
        case .detailed: return "a detailed walkthrough"
        }
    }

    private static func sectionLabels(for document: ReaderDocument) -> [UUID: String] {
        var labels: [UUID: String] = [:]
        for page in document.pages {
            var current: String?
            for block in page.blocks.sorted(by: { $0.readingOrderIndex < $1.readingOrderIndex }) {
                if block.type == .heading {
                    let value = clean(block.text)
                    current = value.isEmpty ? nil : String(value.prefix(120))
                }
                if let current { labels[block.id] = current }
            }
        }
        return labels
    }

    private static func omissionLine(_ metadata: IntelligenceContextMetadata) -> String {
        guard metadata.omittedBlockCount > 0 else { return "" }
        let pages = metadata.omittedPageNumbers.map(String.init).joined(separator: ", ")
        let sections = metadata.omittedSectionLabels.map { "\"\($0)\"" }.joined(separator: ", ")
        var line = "[Omitted source locations: \(metadata.omittedBlockCount) block(s)"
        if !pages.isEmpty { line += "; pages \(pages)" }
        if !sections.isEmpty { line += "; sections \(sections)" }
        return line + "; content not provided.]"
    }

    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func orderedUnique(_ values: [Int]) -> [Int] {
        var seen = Set<Int>()
        return values.filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == String {
    func orderedUnique() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
