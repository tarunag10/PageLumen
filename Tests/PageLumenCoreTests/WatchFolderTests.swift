import Foundation
import XCTest
@testable import PageLumenCore

final class WatchFolderTests: XCTestCase {
    func testScannerFiltersSortsBoundsAndExcludesKnownFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let beta = folder.appendingPathComponent("beta.pdf")
        let alpha = folder.appendingPathComponent("alpha.png")
        let ignored = folder.appendingPathComponent("ignored.txt")
        try Data(repeating: 1, count: 4).write(to: beta)
        try Data(repeating: 2, count: 8).write(to: alpha)
        try Data([0]).write(to: ignored)

        let candidates = try WatchFolderScanner().candidates(in: folder, excluding: [beta], limit: 10)

        XCTAssertEqual(candidates.map(\.url.lastPathComponent), ["alpha.png"])
        XCTAssertEqual(candidates.first?.byteSize, 8)
    }

    func testScannerRejectsFilesAndAppliesLimit() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("one.pdf")
        try Data([0]).write(to: file)

        XCTAssertThrowsError(try WatchFolderScanner().candidates(in: file)) { error in
            XCTAssertEqual(error as? WatchFolderError, .notDirectory)
        }
        XCTAssertEqual(try WatchFolderScanner().candidates(in: folder, limit: 0), [])
    }

    func testSecurityScopedBookmarkRoundTripsSelectedFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let bookmark = try WatchFolderBookmark.create(for: folder)
        XCTAssertEqual(try bookmark.resolve().standardizedFileURL, folder.standardizedFileURL)
    }

    func testMonitorReportsCandidatesWithoutImportingThem() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("incoming.pdf")
        try Data([1, 2, 3]).write(to: file)
        let bookmark = try WatchFolderBookmark.create(for: folder)
        let monitor = WatchFolderMonitor()
        let expectation = expectation(description: "candidate reported")
        var reported: [WatchFolderCandidate] = []

        try monitor.start(bookmark: bookmark, intervalNanoseconds: 1_000_000) { candidates in
            reported = candidates
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 2)
        monitor.stop()

        XCTAssertEqual(reported.map(\.url.lastPathComponent), ["incoming.pdf"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "Monitoring must not import or delete files")
    }

    func testMonitorReportsFolderFailureInsteadOfSilentlyContinuing() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumen-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bookmark = try WatchFolderBookmark.create(for: folder)
        let monitor = WatchFolderMonitor()
        let expectation = expectation(description: "monitor error reported")
        var reportedError: WatchFolderError?

        try monitor.start(bookmark: bookmark, intervalNanoseconds: 1_000_000, onCandidates: { _ in }) { error in
            reportedError = error
            expectation.fulfill()
        }
        try FileManager.default.removeItem(at: folder)
        await fulfillment(of: [expectation], timeout: 2)
        monitor.stop()

        XCTAssertEqual(reportedError, .inaccessible)
    }

    func testImportFailureKeepsFilenameAndRedactsSourcePath() {
        let file = URL(fileURLWithPath: "/Users/example/Private Watch Folder/incoming.pdf")
        let failure = WatchFolderImportFailure(
            url: file,
            message: "Could not read /Users/example/Private Watch Folder/incoming.pdf: permission denied"
        )

        XCTAssertEqual(failure.fileName, "incoming.pdf")
        XCTAssertEqual(failure.message, "Could not read [path omitted]: permission denied")
        XCTAssertFalse(failure.message.contains("Private Watch Folder"))
        XCTAssertFalse(failure.message.contains(file.path))
    }

    func testImportFailureProvidesFallbackMessageForEmptyErrors() {
        let file = URL(fileURLWithPath: "/tmp/incoming.pdf")
        let failure = WatchFolderImportFailure(url: file, message: "")

        XCTAssertEqual(failure.fileName, "incoming.pdf")
        XCTAssertEqual(failure.message, "Import failed")
    }
}
