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
        )
        assertSnapshot(of: normalized, as: .lines, named: "demo-tagged-html")
    }
}
