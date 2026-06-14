import XCTest
@testable import PageLumenCore

final class DocumentPersistingTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumenPersisting-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testSavePersistsDocumentsToJSONFileAndLoadReturnsThem() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let persisting = FilePersisting(fileURL: url)
        let first = SampleDataFactory.makeDemoDocument()
        let second = makeAlternateDocument(title: "Alternate Import")

        try persisting.save(first)
        try persisting.save(second)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let recents = try persisting.recentDocuments()
        XCTAssertEqual(recents.count, 2)
        // Newest-first ordering: the most recent save is at index 0.
        XCTAssertEqual(recents[0].title, "Alternate Import")
        XCTAssertEqual(recents[1].title, "PageLumen Demo")

        let loadedFirst = try persisting.load(id: first.id)
        let loadedSecond = try persisting.load(id: second.id)
        XCTAssertEqual(loadedFirst?.title, "PageLumen Demo")
        XCTAssertEqual(loadedSecond?.title, "Alternate Import")
    }

    func testSaveDedupesByIDAndSourceURL() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let persisting = FilePersisting(fileURL: url)
        let first = SampleDataFactory.makeDemoDocument()
        try persisting.save(first)

        // Re-saving the same document by id should not duplicate.
        try persisting.save(first)
        XCTAssertEqual(try persisting.recentDocuments().count, 1)
    }

    func testForgetAllEmptiesTheLibrary() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let persisting = FilePersisting(fileURL: url)
        try persisting.save(SampleDataFactory.makeDemoDocument())
        try persisting.save(makeAlternateDocument(title: "Other"))
        XCTAssertEqual(try persisting.recentDocuments().count, 2)

        try persisting.forgetAll()

        let recents = try persisting.recentDocuments()
        XCTAssertTrue(recents.isEmpty)
        let loaded = try persisting.load(id: SampleDataFactory.makeDemoDocument().id)
        XCTAssertNil(loaded)
    }

    func testLoadFromMissingFileReturnsEmpty() throws {
        let url = tempDirectory.appendingPathComponent("does-not-exist.json")
        let persisting = FilePersisting(fileURL: url)

        XCTAssertTrue(try persisting.recentDocuments().isEmpty)
        XCTAssertNil(try persisting.load(id: UUID()))
    }

    private func makeAlternateDocument(title: String) -> ReaderDocument {
        ReaderDocument(
            title: title,
            sourceType: .pdf,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 612, height: 792), blocks: [])]
        )
    }
}
