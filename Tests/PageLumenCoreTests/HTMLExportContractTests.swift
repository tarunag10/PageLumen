import XCTest
@testable import PageLumenCore

final class HTMLExportContractTests: XCTestCase {
    func testGeneratedHTMLContractCoversLanguageLandmarkStructureAndEscaping() {
        var document = SampleDataFactory.makeDemoDocument()
        document.title = "R&D <review>"
        document.language = "en-GB"

        let html = ExportEngine().html(for: document, options: .full)
        let validation = HTMLExportContract.validate(html)

        XCTAssertTrue(validation.isValid, validation.issues.joined(separator: ", "))
        XCTAssertTrue(html.contains("<html lang=\"en-GB\">") )
        XCTAssertTrue(html.contains("<title>R&amp;D &lt;review&gt;</title>"))
        XCTAssertFalse(html.contains("<title>R&D <review>"))
    }

    func testTaggedHTMLContractRequiresAccessibleFigureAndTableStructure() {
        let html = ExportEngine().taggedHTML(for: SampleDataFactory.makeDemoDocument(), options: .full)
        let validation = HTMLExportContract.validate(html, tagged: true)

        XCTAssertTrue(validation.isValid, validation.issues.joined(separator: ", "))
        XCTAssertTrue(html.contains("<main id=\"content\">") )
        XCTAssertTrue(html.contains("scope=\"col\""))
        XCTAssertTrue(html.contains("role=\"img\""))
        XCTAssertTrue(html.contains("Skip to content"))
    }

    func testContractRejectsHeadingJumpUnsafeLinkAndUnlabelledFigure() {
        let malformed = """
        <!doctype html>
        <html lang="en"><body><main><h1>Title</h1><h3>Jump</h3>
        <a href="javascript:alert(1)">bad</a><figure><figcaption></figcaption></figure>
        </main></body></html>
        """

        let validation = HTMLExportContract.validate(malformed, tagged: true)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.issues.contains("html.heading-level-jump"))
        XCTAssertTrue(validation.issues.contains("html.link-unsafe-target"))
        XCTAssertTrue(validation.issues.contains("html.figure-missing-description"))
        XCTAssertTrue(validation.issues.contains("html.figure-missing-image-role"))
    }

    func testGeneratedHTMLPreservesSafeAndInternalLinksAndOmitsUnsafeSchemes() {
        var document = SampleDataFactory.makeDemoDocument()
        let bounds = BoundingBox(x: 10, y: 10, width: 40, height: 20)
        document.pages[0].links = [
            ReaderLink(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, pageNumber: 1, bounds: bounds, label: "Project & docs", url: URL(string: "https://example.com/a?x=1&y=2")),
            ReaderLink(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, pageNumber: 1, bounds: bounds, label: "Next page", targetPageNumber: 2),
            ReaderLink(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, pageNumber: 1, bounds: bounds, label: "Unsafe", url: URL(string: "javascript:alert(1)")!)
        ]

        let html = ExportEngine().taggedHTML(for: document, options: .full)

        XCTAssertTrue(html.contains("https://example.com/a?x=1&amp;y=2"))
        XCTAssertTrue(html.contains("href=\"#page-2-heading\""))
        XCTAssertTrue(html.contains("Project &amp; docs"))
        XCTAssertFalse(html.contains("javascript:"))
        XCTAssertTrue(HTMLExportContract.validate(html, tagged: true).isValid)
    }
}
