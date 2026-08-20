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

    func testForgetAllNeverDeletesOriginalSourceFile() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let sourceURL = tempDirectory.appendingPathComponent("original.pdf")
        try Data("source bytes".utf8).write(to: sourceURL)
        let persisting = FilePersisting(fileURL: url)
        var document = SampleDataFactory.makeDemoDocument()
        document.sourceURL = sourceURL

        try persisting.save(document)
        try persisting.forgetAll()

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(try Data(contentsOf: sourceURL), Data("source bytes".utf8))
    }

    func testDeleteRemovesOnlyTheRequestedDocument() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let persisting = FilePersisting(fileURL: url)
        let first = SampleDataFactory.makeDemoDocument()
        let second = makeAlternateDocument(title: "Other")
        try persisting.save(first)
        try persisting.save(second)

        try persisting.delete(id: first.id)

        XCTAssertNil(try persisting.load(id: first.id))
        XCTAssertEqual(try persisting.load(id: second.id)?.title, "Other")
        XCTAssertEqual(try persisting.recentDocuments().count, 1)
    }

    func testLoadFromMissingFileReturnsEmpty() throws {
        let url = tempDirectory.appendingPathComponent("does-not-exist.json")
        let persisting = FilePersisting(fileURL: url)

        XCTAssertTrue(try persisting.recentDocuments().isEmpty)
        XCTAssertNil(try persisting.load(id: UUID()))
        XCTAssertEqual(try persisting.storageSizeInBytes(), 0)
    }

    func testSaveFailsWithoutReplacingAnUnwritableParentPath() throws {
        let blocker = tempDirectory.appendingPathComponent("parent-blocker")
        try Data("not a directory".utf8).write(to: blocker)
        let url = blocker.appendingPathComponent("recent.json")
        let persisting = FilePersisting(fileURL: url)

        XCTAssertThrowsError(try persisting.save(SampleDataFactory.makeDemoDocument()))
        XCTAssertEqual(try Data(contentsOf: blocker), Data("not a directory".utf8))
    }

    func testCorruptStoreIsBackedUpAndSurfacesTypedError() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        try Data("not valid JSON".utf8).write(to: url)
        let persisting = FilePersisting(fileURL: url)

        XCTAssertThrowsError(try persisting.recentDocuments()) { error in
            XCTAssertEqual(error as? FilePersistingError, .corruptStore)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let backups = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("recent.json.corrupt-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try FilePersisting(fileURL: url).recentDocuments(), [])
    }

    func testStorageSizeReportsOnlyTheLocalLibraryFile() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let persisting = FilePersisting(fileURL: url)
        XCTAssertEqual(try persisting.storageSizeInBytes(), 0)

        try persisting.save(SampleDataFactory.makeDemoDocument())

        let size = try XCTUnwrap(persisting.storageSizeInBytes())
        XCTAssertGreaterThan(size, 0)
        let fileSize = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)
        XCTAssertEqual(size, fileSize.int64Value)
    }

    func testWritesVersionedEnvelopeAndReadsLegacyArray() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let persisting = FilePersisting(fileURL: url)
        try persisting.save(SampleDataFactory.makeDemoDocument())

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, FilePersisting.schemaVersion)
        XCTAssertNotNil(object["documents"] as? [[String: Any]])

        // Version 0 was a top-level array. It remains readable for upgrades.
        let documents = try XCTUnwrap(object["documents"] as? [[String: Any]])
        try JSONSerialization.data(withJSONObject: documents).write(to: url)
        XCTAssertEqual(try persisting.recentDocuments().count, 1)
        try persisting.save(makeAlternateDocument(title: "Migrated"))
        let upgraded = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(upgraded["schemaVersion"] as? Int, FilePersisting.schemaVersion)
        XCTAssertEqual(try persisting.recentDocuments().count, 2)
    }

    func testDocumentsWithoutSemanticFieldsRemainReadable() throws {
        let document = SampleDataFactory.makeDemoDocument()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        object.removeValue(forKey: "metadata")
        if var pages = object["pages"] as? [[String: Any]] {
            pages = pages.map { page in
                var legacyPage = page
                legacyPage.removeValue(forKey: "pageLabel")
                return legacyPage
            }
            object["pages"] = pages
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(ReaderDocument.self, from: data)

        XCTAssertEqual(decoded.id, document.id)
        XCTAssertEqual(decoded.metadata, [:])
        XCTAssertTrue(decoded.pages.allSatisfy { $0.pageLabel == nil })
    }

    func testUnsupportedSchemaVersionIsPreservedForRecovery() throws {
        let url = tempDirectory.appendingPathComponent("recent.json")
        let future: [String: Any] = ["schemaVersion": 99, "documents": [[String: Any]]()]
        let data = try JSONSerialization.data(withJSONObject: future)
        try data.write(to: url)

        XCTAssertThrowsError(try FilePersisting(fileURL: url).recentDocuments()) { error in
            XCTAssertEqual(error as? FilePersistingError, .unsupportedSchemaVersion(99))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil).count, 1)
    }

    private func makeAlternateDocument(title: String) -> ReaderDocument {
        ReaderDocument(
            title: title,
            sourceType: .pdf,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 612, height: 792), blocks: [])]
        )
    }
}
