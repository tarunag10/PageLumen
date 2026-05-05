import XCTest
@testable import SightlineCore

final class BatchImportQueueTests: XCTestCase {
    func testEnqueueCreatesPendingItemsForSupportedURLs() {
        let urls = [
            URL(fileURLWithPath: "/tmp/alpha.pdf"),
            URL(fileURLWithPath: "/tmp/beta.png"),
            URL(fileURLWithPath: "/tmp/notes.txt")
        ]

        let queue = BatchImportQueue(urls: urls)

        XCTAssertEqual(queue.items.map(\.fileName), ["alpha.pdf", "beta.png"])
        XCTAssertEqual(queue.items.map(\.status), [.pending, .pending])
        XCTAssertEqual(queue.pendingItem?.fileName, "alpha.pdf")
    }

    func testQueueTransitionsThroughProcessingCompleteAndFailed() {
        let urls = [
            URL(fileURLWithPath: "/tmp/alpha.pdf"),
            URL(fileURLWithPath: "/tmp/beta.jpg")
        ]
        var queue = BatchImportQueue(urls: urls)
        let firstID = queue.items[0].id
        let secondID = queue.items[1].id
        let document = SampleDataFactory.makeDemoDocument()

        queue.markProcessing(firstID)
        XCTAssertEqual(queue.items[0].status, .processing)
        XCTAssertEqual(queue.completedCount, 0)

        queue.markCompleted(firstID, document: document)
        XCTAssertEqual(queue.items[0].status, .complete)
        XCTAssertEqual(queue.items[0].document?.title, "Sightline Reader Demo")
        XCTAssertEqual(queue.completedCount, 1)

        queue.markProcessing(secondID)
        queue.markFailed(secondID, message: "Could not read file")
        XCTAssertEqual(queue.items[1].status, .failed("Could not read file"))
        XCTAssertEqual(queue.failedCount, 1)
        XCTAssertNil(queue.pendingItem)
    }
}
