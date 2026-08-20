import XCTest
@testable import PageLumenCore

final class SystemWorkflowContractTests: XCTestCase {
    func testSupportedDocumentURLsAreCaseInsensitiveAndBounded() {
        XCTAssertTrue(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/scan.PDF")))
        XCTAssertTrue(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/photo.HeIc")))
        XCTAssertFalse(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/notes.txt")))
        XCTAssertFalse(PageLumenSystemWorkflowContract.supportsDocumentURL(URL(fileURLWithPath: "/tmp/no-extension")))
    }

    func testOnlyFinderOpenFileIsDeclaredPackagedUntilExtensionsAreValidated() {
        XCTAssertTrue(PageLumenSystemWorkflowContract.PackagedCapability.finderOpenFile.isPackagedInCurrentTarget)
        for capability in PageLumenSystemWorkflowContract.PackagedCapability.allCases where capability != .finderOpenFile {
            XCTAssertFalse(capability.isPackagedInCurrentTarget, "Unexpectedly claims (capability.rawValue) is packaged")
        }
    }
}
