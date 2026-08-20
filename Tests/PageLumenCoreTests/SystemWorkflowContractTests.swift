import XCTest
@testable import PageLumenCore

final class SystemWorkflowContractTests: XCTestCase {
    func testSupportedDocumentURLsAreCaseInsensitiveAndBounded() {
        XCTAssertTrue(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/scan.PDF")))
        XCTAssertTrue(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/photo.HeIc")))
        XCTAssertFalse(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/notes.txt")))
        XCTAssertFalse(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/no-extension")))
    }

    func testPackagedCapabilitiesMatchCurrentTargets() {
        let packaged: Set<PageLumenSystemWorkflowContract.PackagedCapability> = [.finderOpenFile, .finderQuickAction, .shareExtension, .quickLookThumbnail]
        for capability in PageLumenSystemWorkflowContract.PackagedCapability.allCases {
            XCTAssertEqual(capability.isPackagedInCurrentTarget, packaged.contains(capability), "Unexpected packaging claim for \(capability.rawValue)")
        }
    }

    func testExtensionSelectionFiltersUnsupportedFilesAndCapsHostWorkload() {
        let supported = (0..<25).map { URL(fileURLWithPath: "/tmp/scan\($0).pdf") }
        let urls = supported + [URL(fileURLWithPath: "/tmp/notes.txt")]

        let accepted = PageLumenSystemWorkflowContract.acceptedExtensionURLs(urls)

        XCTAssertEqual(accepted.count, PageLumenSystemWorkflowContract.maximumExtensionInputCount)
        XCTAssertEqual(accepted, Array(supported.prefix(20)))
    }

    func testQuickLookPoliciesAreInputBoundedAndAvailabilityIndependent() {
        let thumbnailURL = URL(fileURLWithPath: "/tmp/scan.PDF")
        let imageURL = URL(fileURLWithPath: "/tmp/photo.png")
        let unsupportedURL = URL(fileURLWithPath: "/tmp/notes.txt")

        let thumbnail = PageLumenSystemWorkflowContract.quickLookPolicy(for: thumbnailURL, mode: .thumbnail)
        XCTAssertEqual(thumbnail, .thumbnail)
        XCTAssertEqual(thumbnail?.boundedPageCount(for: 50), 1)
        XCTAssertEqual(thumbnail?.boundedPixelSize(width: 4_000, height: 2_000)?.width, 512)
        XCTAssertEqual(thumbnail?.boundedPixelSize(width: 4_000, height: 2_000)?.height, 256)

        let preview = PageLumenSystemWorkflowContract.quickLookPolicy(for: imageURL, mode: .preview)
        XCTAssertEqual(preview, .preview)
        XCTAssertEqual(preview?.boundedPageCount(for: 50), 3)
        XCTAssertNil(preview?.boundedPixelSize(width: .infinity, height: 20))
        XCTAssertNil(PageLumenSystemWorkflowContract.quickLookPolicy(for: unsupportedURL, mode: .preview))
    }
}
