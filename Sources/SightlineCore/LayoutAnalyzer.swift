import Foundation

public struct LayoutAnalyzer: Sendable {
    public init() {}

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
        let layoutType = classifyLayout(for: page)
        let ordered = orderedBlocks(page.blocks, layoutType: layoutType, pageWidth: page.size.width)
            .enumerated()
            .map { index, block in
                var copy = block
                copy.readingOrderIndex = index
                if isLikelyHeading(copy) {
                    copy.type = .heading
                } else if isLikelyTable(copy) {
                    copy.type = .table
                } else if isLikelyFigure(copy) {
                    copy.type = .figure
                }
                return copy
            }

        var page = page
        page.layoutType = layoutType
        page.blocks = ordered
        page.ocrStatus = .complete
        page.warning = ordered.contains { $0.confidence < 0.65 } ? "Some extracted text has low OCR confidence and should be reviewed." : nil
        page.tables = detectTables(in: ordered)
        page.figures = detectFigures(in: ordered)
        return page
    }

    public func classifyLayout(for page: ReaderPage) -> LayoutType {
        guard page.blocks.count > 2 else { return .singleColumn }
        let leftCount = page.blocks.filter { $0.bounds.midX < page.size.width * 0.45 }.count
        let rightCount = page.blocks.filter { $0.bounds.midX > page.size.width * 0.55 }.count
        let fullWidthCount = page.blocks.filter { $0.bounds.width > page.size.width * 0.68 }.count

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

    private func positionSort(_ lhs: TextBlock, _ rhs: TextBlock) -> Bool {
        if abs(lhs.bounds.minY - rhs.bounds.minY) > 12 {
            return lhs.bounds.minY < rhs.bounds.minY
        }
        return lhs.bounds.minX < rhs.bounds.minX
    }

    private func isLikelyHeading(_ block: TextBlock) -> Bool {
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3, text.count <= 80 else { return false }
        if text == text.uppercased(), text.rangeOfCharacter(from: .letters) != nil {
            return true
        }
        if text.range(of: #"^\d+(\.\d+)*\s+\S+"#, options: .regularExpression) != nil {
            return true
        }
        return block.bounds.height >= 30 && !text.hasSuffix(".")
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
                .map { row in row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
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
