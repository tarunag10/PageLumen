import SnapshotTesting
import XCTest
@testable import PageLumenCore

/// Golden export tests use SnapshotTesting's text diffing so format changes
/// produce an actionable line-level review instead of a broad assertion.
final class ExportSnapshotTests: XCTestCase {
    func testDemoMarkdownExportSnapshot() {
        let markdown = ExportEngine().markdown(
            for: SampleDataFactory.makeDemoDocument(),
            options: .full
        )

        assertSnapshot(of: markdown, as: .lines, named: "demo-markdown")
    }

    func testDemoTaggedHTMLExportSnapshot() {
        let html = ExportEngine().taggedHTML(
            for: SampleDataFactory.makeDemoDocument(),
            options: .full
        )

        let normalized = html.replacingOccurrences(
            of: #"block-[0-9a-fA-F-]{36}"#,
            with: "block-UUID",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        assertSnapshot(of: normalized, as: .lines, named: "demo-tagged-html")
    }

    func testRepresentativeLegalMarkdownExportSnapshot() {
        let document = representativeDocument(
            title: "Legal Filing",
            language: "en-GB",
            blocks: [
                ("heading", "STATEMENT OF CASE"),
                ("paragraph", "The claimant relies on the following facts."),
                ("heading", "SCHEDULE 1"),
                ("paragraph", "The parties reserve their rights.")
            ]
        )
        assertSnapshot(of: ExportEngine().markdown(for: document, options: .full), as: .lines, named: "legal-markdown")
    }

    func testRepresentativeMultilingualMarkdownExportSnapshot() {
        let document = representativeDocument(
            title: "Multilingual Text",
            language: "hi",
            blocks: [
                ("heading", "English heading"),
                ("paragraph", "हिन्दी पाठ — 中文文本 — Texto español")
            ]
        )
        assertSnapshot(of: ExportEngine().markdown(for: document, options: .full), as: .lines, named: "multilingual-markdown")
    }

    func testRepresentativeFormsAndTablesTaggedHTMLSnapshot() {
        let document = representativeDocument(
            title: "Receipt Form",
            language: "en",
            blocks: [
                ("heading", "RECEIPT"),
                ("table", "Subtotal | $18.50\nTax | $1.48\nTotal | $19.98")
            ],
            tableRows: [["Field", "Value"], ["Subtotal", "$18.50"], ["Tax", "$1.48"], ["Total", "$19.98"]]
        )
        assertSnapshot(of: normalizedHTML(ExportEngine().taggedHTML(for: document, options: .full)), as: .lines, named: "receipt-tagged-html")
    }

    func testRepresentativeLinksAndFigureTaggedHTMLSnapshot() {
        let document = representativeDocument(
            title: "Slide Links",
            language: "en",
            blocks: [("heading", "QUARTERLY REVIEW"), ("figure", "Chart of export readiness")],
            figureDescription: "A line chart showing export readiness increasing.",
            links: [ReaderLink(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000091")!,
                pageNumber: 1,
                bounds: BoundingBox(x: 1, y: 1, width: 2, height: 2),
                label: "Release notes",
                url: URL(string: "https://example.com/releases")
            )]
        )
        assertSnapshot(of: normalizedHTML(ExportEngine().taggedHTML(for: document, options: .full)), as: .lines, named: "links-figure-tagged-html")
    }

    private func normalizedHTML(_ html: String) -> String {
        html.replacingOccurrences(
            of: #"block-[0-9a-fA-F-]{36}"#,
            with: "block-UUID",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func representativeDocument(
        title: String,
        language: String,
        blocks: [(String, String)],
        tableRows: [[String]] = [],
        figureDescription: String? = nil,
        links: [ReaderLink] = []
    ) -> ReaderDocument {
        let pageBounds = BoundingBox(x: 40, y: 40, width: 520, height: 700)
        let textBlocks = blocks.enumerated().map { index, item in
            let type: BlockType
            switch item.0 {
            case "heading": type = .heading
            case "table": type = .table
            case "figure": type = .figure
            default: type = .paragraph
            }
            return TextBlock(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                pageNumber: 1,
                type: type,
                text: item.1,
                bounds: BoundingBox(x: 40, y: Double(60 + index * 80), width: 500, height: 50),
                confidence: 0.96,
                readingOrderIndex: index
            )
        }
        let table = tableRows.isEmpty ? [] : [TableRegion(pageNumber: 1, bounds: pageBounds, rows: tableRows, explanation: "A reviewed table.", confidence: 0.95)]
        let figures = figureDescription.map { [FigureRegion(pageNumber: 1, bounds: pageBounds, chartType: .line, visibleText: "Chart", description: $0, confidence: 0.9)] } ?? []
        return ReaderDocument(
            title: title,
            sourceType: .sample,
            language: language,
            processingStatus: .complete,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 600, height: 800), ocrStatus: .complete, blocks: textBlocks, tables: table, figures: figures, links: links)]
        )
    }
}
