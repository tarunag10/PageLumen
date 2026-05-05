import Foundation

public enum SampleDataFactory {
    public static func makeDemoDocument() -> ReaderDocument {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 900, height: 1_200),
            ocrStatus: .complete,
            blocks: [
                TextBlock(
                    pageNumber: 1,
                    type: .heading,
                    text: "IMPORT FLOW",
                    bounds: BoundingBox(x: 70, y: 64, width: 420, height: 40),
                    confidence: 0.98,
                    readingOrderIndex: 0
                ),
                TextBlock(
                    pageNumber: 1,
                    type: .paragraph,
                    text: "PageLumen turns inaccessible visual documents into readable, structured, audio-friendly, and exportable content.",
                    bounds: BoundingBox(x: 70, y: 130, width: 650, height: 72),
                    confidence: 0.95,
                    readingOrderIndex: 1
                ),
                TextBlock(
                    pageNumber: 1,
                    type: .table,
                    text: "| Item | Status |\n| PDF import | Ready |\n| OCR confidence | Visible |",
                    bounds: BoundingBox(x: 70, y: 230, width: 520, height: 130),
                    confidence: 0.88,
                    readingOrderIndex: 2
                ),
                TextBlock(
                    pageNumber: 1,
                    type: .figure,
                    text: "Bar chart showing successful extraction, review, and export steps.",
                    bounds: BoundingBox(x: 70, y: 390, width: 530, height: 110),
                    confidence: 0.82,
                    readingOrderIndex: 3
                )
            ],
            tables: [
                TableRegion(
                    pageNumber: 1,
                    bounds: BoundingBox(x: 70, y: 230, width: 520, height: 130),
                    rows: [["Item", "Status"], ["PDF import", "Ready"], ["OCR confidence", "Visible"]],
                    explanation: "This table appears to contain 3 rows and 2 columns. The visible header or first row reads: Item, Status.",
                    confidence: 0.88
                )
            ],
            figures: [
                FigureRegion(
                    pageNumber: 1,
                    bounds: BoundingBox(x: 70, y: 390, width: 530, height: 110),
                    chartType: .bar,
                    visibleText: "Bar chart showing successful extraction, review, and export steps.",
                    description: "The chart appears to show the app workflow moving from extraction to review and export.",
                    confidence: 0.82
                )
            ]
        )

        return ReaderDocument(
            title: "PageLumen Demo",
            sourceType: .sample,
            language: "en",
            processingStatus: .complete,
            pages: [page],
            outline: [OutlineItem(title: "IMPORT FLOW", pageNumber: 1)],
            summary: "Page 1: PageLumen turns inaccessible visual documents into readable, structured, audio-friendly, and exportable content."
        )
    }
}
