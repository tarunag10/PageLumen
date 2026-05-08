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
                .map { OutlineItem(title: $0.text, pageNumber: page.pageNumber, level: headingLevel(for: $0.text)) }
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
        let ordered = orderedBlocks(page.blocks, layoutType: layoutType, pageWidth: page.size.width)
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
        let leftCount = page.blocks.filter { $0.bounds.midX < page.size.width * 0.45 }.count
        let rightCount = page.blocks.filter { $0.bounds.midX > page.size.width * 0.55 }.count
        let fullWidthCount = page.blocks.filter { $0.bounds.width > page.size.width * 0.68 }.count

        if profile == .slides, isSparseLargeTextPage(page) {
            return .slide
        }

        if leftCount >= 2 && rightCount >= 2 && fullWidthCount < page.blocks.count / 2 {
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
                metadata: ["source": "receipt-profile", "profile": profile.rawValue]
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

    private func orderedBlocks(_ blocks: [TextBlock], layoutType: LayoutType, pageWidth: Double) -> [TextBlock] {
        switch layoutType {
        case .multiColumn:
            let fullWidth = blocks.filter { $0.bounds.width > pageWidth * 0.68 }.sorted(by: positionSort)
            let columnBlocks = blocks.filter { $0.bounds.width <= pageWidth * 0.68 }
            let left = columnBlocks.filter { $0.bounds.midX < pageWidth / 2 }.sorted(by: positionSort)
            let right = columnBlocks.filter { $0.bounds.midX >= pageWidth / 2 }.sorted(by: positionSort)
            let topFullWidth = fullWidth.filter { $0.bounds.minY < (left.first?.bounds.minY ?? .greatestFiniteMagnitude) }
            let remainingFullWidth = fullWidth.filter { block in !topFullWidth.contains(where: { $0.id == block.id }) }
            return topFullWidth + left + right + remainingFullWidth
        default:
            return blocks.sorted(by: positionSort)
        }
    }

    private func mergeAdjacentOCRLines(_ blocks: [TextBlock], pageWidth: Double) -> [TextBlock] {
        let sorted = blocks.sorted(by: positionSort)
        var merged: [TextBlock] = []

        for block in sorted {
            guard shouldMergeOCRLine(block) else {
                merged.append(block)
                continue
            }

            if let lastIndex = merged.indices.last,
               shouldMerge(block, after: merged[lastIndex], pageWidth: pageWidth) {
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
        let source = block.metadata["source"] ?? ""
        return source == "vision-ocr" || source == "embedded-pdf"
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
        if text.range(of: #"^\d+(\.\d+)*\s+\S+"#, options: .regularExpression) != nil {
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

    private func headingLevel(for title: String) -> Int {
        title.range(of: #"^\d+\.\d+"#, options: .regularExpression) == nil ? 1 : 2
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
