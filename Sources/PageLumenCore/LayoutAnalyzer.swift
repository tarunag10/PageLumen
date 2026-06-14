import Foundation

public struct LayoutAnalyzer: Sendable {
    private let profile: OCRProfile

    public init(profile: OCRProfile = .general) {
        self.profile = profile
    }

    public func analyze(document: ReaderDocument) -> ReaderDocument {
        var analyzedPages = markRepeatedHeadersAndFooters(in: document.pages.map(analyze(page:)))
        let outline = analyzedPages.flatMap { page in
            page.blocks
                .filter { $0.type == .heading }
                .map { OutlineItem(title: $0.text, pageNumber: page.pageNumber, level: headingLevel(for: $0, on: page)) }
        }

        for pageIndex in analyzedPages.indices {
            analyzedPages[pageIndex].tables = analyzedPages[pageIndex].tables.map { table in
                var copy = table
                copy.explanation = ExplanationEngine().explain(table: table)
                return copy
            }
            analyzedPages[pageIndex].figures = analyzedPages[pageIndex].figures.map { figure in
                var copy = figure
                copy.description = copy.description.isEmpty ? ExplanationEngine().explain(figure: figure) : copy.description
                return copy
            }
        }

        var document = document
        document.pages = analyzedPages
        document.outline = outline
        document.summary = ExplanationEngine().summary(for: document, length: .short)
        document.processingStatus = .complete
        return document
    }

    public func analyze(page: ReaderPage) -> ReaderPage {
        var page = page
        page.blocks = mergeAdjacentOCRLines(page.blocks, pageWidth: page.size.width)
        page.blocks = applyProfileTransforms(to: page.blocks, on: page)

        let layoutType = classifyLayout(for: page)
        let figureCandidates = page.blocks.filter(isLikelyFigure)
        let ordered = orderedBlocks(page.blocks, layoutType: layoutType, pageSize: page.size)
            .enumerated()
            .map { index, block in
                var copy = block
                copy.readingOrderIndex = index
                if isLikelyTable(copy) {
                    copy.type = .table
                } else if isLikelyFigure(copy) {
                    copy.type = .figure
                } else if isLikelyHeading(copy) {
                    copy.type = .heading
                }
                // Footnote: short text near the bottom of the page. Reuse
                // `.footer` because the block enum has no dedicated footnote
                // case yet (per Phase 6.3.1 in the audit plan).
                if isLikelyFootnote(copy, on: page) {
                    copy.type = .footer
                }
                // Caption: short text whose vertical center sits near a figure
                // candidate. This runs after the figure check so a block that
                // both contains the word "Figure" and sits near another figure
                // is correctly tagged as the caption, not a duplicate figure.
                if isLikelyCaption(copy, on: page, figureCandidates: figureCandidates) {
                    copy.type = .caption
                }
                return copy
            }

        page.layoutType = layoutType
        page.blocks = ordered
        page.ocrStatus = .complete
        page.warning = ordered.contains { $0.confidence < 0.65 } ? "Some extracted text has low OCR confidence and should be reviewed." : nil
        page.tables = detectTables(in: ordered)
        page.figures = detectFigures(in: ordered)
        return page
    }

    public func classifyLayout(for page: ReaderPage) -> LayoutType {
        if profile == .receipts, page.blocks.contains(where: isLikelyTable) {
            return .form
        }

        guard page.blocks.count > 2 else { return .singleColumn }
        let fullWidthCount = page.blocks.filter { $0.bounds.width > page.size.width * 0.68 }.count

        if profile == .slides, isSparseLargeTextPage(page) {
            return .slide
        }

        // A persistent narrow column at the edge of the page (e.g. a marginalia
        // strip or pull-quote) is a sidebar — flag the page as `.mixed` so the
        // ordering pass can defer it to the end of the reading order instead of
        // interleaving it with the body text.
        if hasSidebar(page) {
            return .mixed
        }

        let columnCenters = detectColumnCenters(in: page.blocks, pageWidth: page.size.width)
        if columnCenters.count >= 2, fullWidthCount < page.blocks.count / 2 {
            return .multiColumn
        }

        if page.blocks.contains(where: { $0.text.contains(":") && $0.bounds.width < page.size.width * 0.45 }) {
            return .form
        }

        if page.blocks.count <= 8 && page.blocks.contains(where: isLikelyHeading) {
            return .slide
        }

        return .singleColumn
    }

    private func applyProfileTransforms(to blocks: [TextBlock], on page: ReaderPage) -> [TextBlock] {
        switch profile {
        case .receipts:
            return receiptTableBlocks(from: blocks, on: page) ?? blocks
        default:
            return blocks
        }
    }

    private func receiptTableBlocks(from blocks: [TextBlock], on page: ReaderPage) -> [TextBlock]? {
        let rows = blocks.compactMap(receiptRow)
        guard rows.count >= 2 else {
            return nil
        }

        let bounds = blocks.map(\.bounds).reduce(blocks[0].bounds, union)
        let text = rows
            .map { "\($0.0)\t\($0.1)" }
            .joined(separator: "\n")
        return [
            TextBlock(
                pageNumber: page.pageNumber,
                type: .table,
                text: text,
                bounds: bounds,
                confidence: blocks.map(\.confidence).min() ?? 0.8,
                metadata: ["source": BlockSource.receiptProfile.metadataValue, "profile": profile.rawValue]
            )
        ]
    }

    private func receiptRow(from block: TextBlock) -> (String, String)? {
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = text.firstIndex(of: ":") else {
            return nil
        }

        let key = text[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = text[text.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !value.isEmpty else {
            return nil
        }
        return (key, value)
    }

    private func isSparseLargeTextPage(_ page: ReaderPage) -> Bool {
        guard page.blocks.count <= 8 else {
            return false
        }

        let largeTextCount = page.blocks.filter { $0.bounds.height >= 26 || $0.bounds.width > page.size.width * 0.45 }.count
        return largeTextCount >= max(2, page.blocks.count / 2)
    }

    private func orderedBlocks(_ blocks: [TextBlock], layoutType: LayoutType, pageSize: PageSize) -> [TextBlock] {
        let pageWidth = pageSize.width
        switch layoutType {
        case .multiColumn:
            return multiColumnOrder(blocks, pageWidth: pageWidth)
        case .mixed:
            // Pull sidebar blocks out of the main reading flow and append them
            // at the end so screen readers don't interrupt the body for a
            // recurring marginal column.
            let sidebarIDs = sidebarCandidates(in: blocks, pageSize: pageSize)
            let mainBlocks = blocks.filter { !sidebarIDs.contains($0.id) }
            let sidebar = blocks.filter { sidebarIDs.contains($0.id) }.sorted(by: positionSort)
            let mainCenters = detectColumnCenters(in: mainBlocks, pageWidth: pageWidth)
            let orderedMain: [TextBlock]
            if mainCenters.count >= 2 {
                orderedMain = multiColumnOrder(mainBlocks, pageWidth: pageWidth)
            } else {
                orderedMain = mainBlocks.sorted(by: positionSort)
            }
            return orderedMain + sidebar
        default:
            return blocks.sorted(by: positionSort)
        }
    }

    private func multiColumnOrder(_ blocks: [TextBlock], pageWidth: Double) -> [TextBlock] {
        let fullWidth = blocks.filter { $0.bounds.width > pageWidth * 0.68 }.sorted(by: positionSort)
        let columnBlocks = blocks.filter { $0.bounds.width <= pageWidth * 0.68 }
        let columnCenters = detectColumnCenters(in: columnBlocks, pageWidth: pageWidth)

        // Fall back to the old 2-column split (left of midpoint vs right of
        // midpoint) when clustering finds fewer than two distinct columns —
        // this preserves the original behavior for documents where every
        // block lives in one wide column.
        guard columnCenters.count >= 2 else {
            let left = columnBlocks.filter { $0.bounds.midX < pageWidth / 2 }.sorted(by: positionSort)
            let right = columnBlocks.filter { $0.bounds.midX >= pageWidth / 2 }.sorted(by: positionSort)
            let topFullWidth = fullWidth.filter { $0.bounds.minY < (left.first?.bounds.minY ?? .greatestFiniteMagnitude) }
            let remainingFullWidth = fullWidth.filter { block in !topFullWidth.contains(where: { $0.id == block.id }) }
            return topFullWidth + left + right + remainingFullWidth
        }

        // Bucket each block into the column whose center is closest to the
        // block's horizontal midpoint, then read each column top-to-bottom.
        var columns: [[TextBlock]] = Array(repeating: [], count: columnCenters.count)
        for block in columnBlocks {
            let nearest = columnCenters.enumerated().min { lhs, rhs in
                abs(block.bounds.midX - lhs.element) < abs(block.bounds.midX - rhs.element)
            }
            if let nearest {
                columns[nearest.offset].append(block)
            }
        }
        let orderedColumns = columns.flatMap { $0.sorted(by: positionSort) }

        let firstColumnTop = columns
            .compactMap { $0.map(\.bounds.minY).min() }
            .min() ?? .greatestFiniteMagnitude
        let topFullWidth = fullWidth.filter { $0.bounds.minY < firstColumnTop }
        let remainingFullWidth = fullWidth.filter { block in !topFullWidth.contains(where: { $0.id == block.id }) }
        return topFullWidth + orderedColumns + remainingFullWidth
    }

    /// Find approximate column-center x-coordinates by clustering block midXs.
    /// Two midXs whose horizontal gap exceeds `pageWidth / 10` start a new
    /// cluster; only clusters with at least two blocks are returned, so a lone
    /// stray block can't masquerade as a column.
    internal func detectColumnCenters(in blocks: [TextBlock], pageWidth: Double) -> [Double] {
        guard !blocks.isEmpty else { return [] }
        let midXs = blocks.map(\.bounds.midX).sorted()
        let gapThreshold = max(40.0, pageWidth / 10)

        var clusters: [[Double]] = []
        var current: [Double] = []
        for value in midXs {
            if let last = current.last, value - last > gapThreshold {
                clusters.append(current)
                current = [value]
            } else {
                current.append(value)
            }
        }
        if !current.isEmpty {
            clusters.append(current)
        }

        return clusters
            .filter { $0.count >= 2 }
            .map { values in values.reduce(0, +) / Double(values.count) }
    }

    /// IDs of blocks that look like a sidebar on this page: very narrow, tall,
    /// and hugging the left or right edge. We require all three signals to
    /// avoid mistaking a short caption or pull-quote for a sidebar.
    internal func sidebarCandidates(in blocks: [TextBlock], pageSize: PageSize) -> Set<UUID> {
        let widthLimit = pageSize.width * 0.18
        let heightFloor = pageSize.height * 0.3
        let edgeBand = pageSize.width * 0.3
        var result: Set<UUID> = []
        for block in blocks {
            guard block.bounds.width < widthLimit, block.bounds.height >= heightFloor else {
                continue
            }
            let isLeftEdge = block.bounds.maxX <= edgeBand
            let isRightEdge = block.bounds.minX >= pageSize.width - edgeBand
            guard isLeftEdge || isRightEdge else { continue }
            result.insert(block.id)
        }
        return result
    }

    private func hasSidebar(_ page: ReaderPage) -> Bool {
        let sidebars = sidebarCandidates(in: page.blocks, pageSize: page.size)
        return !sidebars.isEmpty && page.blocks.count > sidebars.count
    }

    private func mergeAdjacentOCRLines(_ blocks: [TextBlock], pageWidth: Double) -> [TextBlock] {
        let sorted = blocks.sorted(by: positionSort)
        var merged: [TextBlock] = []
        let yBucketTolerance: Double = 48

        for block in sorted {
            guard shouldMergeOCRLine(block) else {
                merged.append(block)
                continue
            }

            if let lastIndex = merged.indices.last,
               shouldMerge(block, after: merged[lastIndex], pageWidth: pageWidth),
               abs(block.bounds.minY - merged[lastIndex].bounds.minY) <= yBucketTolerance {
                merged[lastIndex] = merge(merged[lastIndex], with: block)
            } else {
                merged.append(block)
            }
        }

        return merged
    }

    private func shouldMergeOCRLine(_ block: TextBlock) -> Bool {
        guard block.type == .paragraph || block.type == .unknown else {
            return false
        }
        return block.blockSource == .visionOCR || block.blockSource == .embeddedPDF
    }

    private func shouldMerge(_ block: TextBlock, after previous: TextBlock, pageWidth: Double) -> Bool {
        guard shouldMergeOCRLine(previous), block.pageNumber == previous.pageNumber else {
            return false
        }
        guard !isLikelyHeading(previous), !isLikelyHeading(block), !isLikelyTable(previous), !isLikelyTable(block) else {
            return false
        }

        let maxIndentDelta = max(28, pageWidth * 0.045)
        let verticalGap = block.bounds.minY - previous.bounds.maxY
        let maxLineGap = max(10, min(previous.bounds.height, block.bounds.height) * 1.25)
        let sameColumn = abs(block.bounds.minX - previous.bounds.minX) <= maxIndentDelta
        let overlaps = horizontalOverlap(previous.bounds, block.bounds) >= min(previous.bounds.width, block.bounds.width) * 0.45

        return sameColumn && overlaps && verticalGap >= -4 && verticalGap <= maxLineGap
    }

    private func merge(_ previous: TextBlock, with block: TextBlock) -> TextBlock {
        var copy = previous
        copy.text = [previous.text, block.text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        copy.bounds = union(previous.bounds, block.bounds)
        copy.confidence = min(previous.confidence, block.confidence)
        let mergedLineCount = (Int(copy.metadata["mergedLineCount"] ?? "1") ?? 1) + 1
        copy.metadata["mergedLineCount"] = "\(mergedLineCount)"
        return copy
    }

    private func horizontalOverlap(_ lhs: BoundingBox, _ rhs: BoundingBox) -> Double {
        max(0, min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX))
    }

    private func union(_ lhs: BoundingBox, _ rhs: BoundingBox) -> BoundingBox {
        let minX = min(lhs.minX, rhs.minX)
        let minY = min(lhs.minY, rhs.minY)
        let maxX = max(lhs.maxX, rhs.maxX)
        let maxY = max(lhs.maxY, rhs.maxY)
        return BoundingBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func positionSort(_ lhs: TextBlock, _ rhs: TextBlock) -> Bool {
        if abs(lhs.bounds.minY - rhs.bounds.minY) > 12 {
            return lhs.bounds.minY < rhs.bounds.minY
        }
        return lhs.bounds.minX < rhs.bounds.minX
    }

    private func isLikelyHeading(_ block: TextBlock) -> Bool {
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3, text.count <= 80 else { return false }
        if profile == .academic, isKnownAcademicHeading(text) {
            return true
        }
        if profile == .slides, block.bounds.height >= 30 && !text.hasSuffix(".") {
            return true
        }
        if text == text.uppercased(), text.rangeOfCharacter(from: .letters) != nil {
            return true
        }
        // Multi-level numbered headings (e.g. "1.1 Background", "1.1.1 Method").
        if text.range(of: #"^\d+(\.\d+)+\s+\S+"#, options: .regularExpression) != nil {
            return true
        }
        // Top-level numbered headings (e.g. "1. Introduction"). Required as a
        // separate clause because the multi-level regex only matches when at
        // least one ".digit" group follows the leading number.
        if text.range(of: #"^\d+\.\s+\S+"#, options: .regularExpression) != nil {
            return true
        }
        return block.bounds.height >= 30 && !text.hasSuffix(".")
    }

    private func isKnownAcademicHeading(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return [
            "abstract",
            "introduction",
            "methods",
            "methodology",
            "results",
            "discussion",
            "conclusion",
            "references",
            "bibliography",
            "appendix"
        ].contains(normalized)
    }

    private func isLikelyTable(_ block: TextBlock) -> Bool {
        block.text.contains("|") || block.text.components(separatedBy: "\t").count >= 3
    }

    private func isLikelyFigure(_ block: TextBlock) -> Bool {
        let lower = block.text.lowercased()
        return lower.contains("chart") || lower.contains("figure") || lower.contains("axis") || lower.contains("legend")
    }

    internal func isLikelyFootnote(_ block: TextBlock, on page: ReaderPage) -> Bool {
        // Footnotes are short text in the bottom 10% of the page. We skip
        // tables and figures because their visual identity is more important
        // than their position; everything else (paragraphs, prematurely
        // promoted headings such as "1 See attached references...", etc.) is
        // fair game.
        guard block.type != .table, block.type != .figure else {
            return false
        }
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 240 else { return false }
        return block.bounds.midY >= page.size.height * 0.9
    }

    internal func isLikelyCaption(_ block: TextBlock, on page: ReaderPage, figureCandidates: [TextBlock]? = nil) -> Bool {
        let candidates = figureCandidates ?? page.blocks.filter(isLikelyFigure)
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 240 else { return false }
        for figure in candidates where figure.id != block.id {
            let dy = abs(block.bounds.midY - figure.bounds.midY)
            if dy <= figure.bounds.height * 0.3 {
                return true
            }
        }
        return false
    }

    private func detectTables(in blocks: [TextBlock]) -> [TableRegion] {
        blocks.filter { $0.type == .table }.compactMap { block in
            let rows = block.text
                .split(separator: "\n")
                .map { row in
                    let delimiter: Character = row.contains("|") ? "|" : "\t"
                    return row.split(separator: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }
                .filter { !$0.isEmpty }
            guard !rows.isEmpty else { return nil }
            return TableRegion(pageNumber: block.pageNumber, bounds: block.bounds, rows: rows, confidence: min(block.confidence, 0.78))
        }
    }

    private func detectFigures(in blocks: [TextBlock]) -> [FigureRegion] {
        blocks.filter { $0.type == .figure }.map { block in
            let lower = block.text.lowercased()
            let chartType: ChartType
            if lower.contains("bar") { chartType = .bar }
            else if lower.contains("line") { chartType = .line }
            else if lower.contains("pie") { chartType = .pie }
            else if lower.contains("scatter") { chartType = .scatter }
            else { chartType = .unknown }

            return FigureRegion(
                pageNumber: block.pageNumber,
                bounds: block.bounds,
                chartType: chartType,
                visibleText: block.text,
                description: "",
                confidence: min(block.confidence, 0.72),
                uncertaintyNotes: ["Generated from visible OCR text and broad layout cues."]
            )
        }
    }

    internal func headingLevel(for block: TextBlock, on page: ReaderPage) -> Int {
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // L3: "1.1.1 Method" — three-level numbering takes precedence over the
        // shorter numbering patterns.
        if text.range(of: #"^\d+\.\d+\.\d+\s+\S"#, options: .regularExpression) != nil {
            return 3
        }
        // L2: "1.1 Background" — checked before L1's "1." pattern so we don't
        // shadow it.
        if text.range(of: #"^\d+\.\d+\s+\S"#, options: .regularExpression) != nil {
            return 2
        }
        // L0: a document title is a very tall block in the top region of the
        // first page. We never promote later pages or shorter blocks because
        // a real H0 only appears once in a document.
        if page.pageNumber == 1,
           block.bounds.height >= 40,
           block.bounds.midY <= page.size.height * 0.3 {
            return 0
        }
        // L1: top-level numbered section, e.g. "1. Introduction".
        if text.range(of: #"^\d+\.\s+\S"#, options: .regularExpression) != nil {
            return 1
        }
        // L1: short all-caps text such as "INTRODUCTION".
        if text == text.uppercased(),
           text.rangeOfCharacter(from: .letters) != nil,
           text.count <= 80 {
            return 1
        }
        // L1: a moderately tall block (>= 28 pt) is most likely an H1.
        if block.bounds.height >= 28 {
            return 1
        }
        return 1
    }

    private func markRepeatedHeadersAndFooters(in pages: [ReaderPage]) -> [ReaderPage] {
        guard pages.count > 1 else {
            return pages
        }

        let headerCandidates = repeatedTexts(in: pages, region: .top)
        let footerCandidates = repeatedTexts(in: pages, region: .bottom)

        return pages.map { page in
            var copy = page
            for index in copy.blocks.indices {
                let normalized = normalize(copy.blocks[index].text)
                if isTop(copy.blocks[index], on: page), headerCandidates.contains(normalized) {
                    copy.blocks[index].type = .header
                } else if isBottom(copy.blocks[index], on: page), footerCandidates.contains(normalized) {
                    copy.blocks[index].type = .footer
                }
            }
            return copy
        }
    }

    private enum PageRegion {
        case top
        case bottom
    }

    private func repeatedTexts(in pages: [ReaderPage], region: PageRegion) -> Set<String> {
        var counts: [String: Set<Int>] = [:]

        for page in pages {
            for block in page.blocks {
                let inRegion = region == .top ? isTop(block, on: page) : isBottom(block, on: page)
                guard inRegion else { continue }
                let normalized = normalize(block.text)
                guard normalized.count > 2 else { continue }
                counts[normalized, default: []].insert(page.pageNumber)
            }
        }

        return Set(counts.filter { $0.value.count >= 2 }.map(\.key))
    }

    private func isTop(_ block: TextBlock, on page: ReaderPage) -> Bool {
        block.bounds.midY <= page.size.height * 0.14
    }

    private func isBottom(_ block: TextBlock, on page: ReaderPage) -> Bool {
        block.bounds.midY >= page.size.height * 0.86
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
