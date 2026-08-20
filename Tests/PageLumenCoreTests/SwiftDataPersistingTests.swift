import Foundation
import SwiftData
import XCTest
@testable import PageLumenCore

@available(macOS 14.0, *)
final class SwiftDataPersistingTests: XCTestCase {
    private func makePersisting() throws -> SwiftDataPersisting {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try SwiftDataPersisting(configuration: config)
    }

    func testSaveAndLoadRoundTrips() throws {
        let persisting = try makePersisting()
        let first = SampleDataFactory.makeDemoDocument()
        let second = ReaderDocument(
            title: "Alternate Import",
            sourceType: .pdf,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 612, height: 792), blocks: [])]
        )

        try persisting.save(first)
        try persisting.save(second)

        let recents = try persisting.recentDocuments()
        XCTAssertEqual(recents.count, 2)
        XCTAssertEqual(recents.map(\.title), ["Alternate Import", "PageLumen Demo"])

        let loadedFirst = try persisting.load(id: first.id)
        let loadedSecond = try persisting.load(id: second.id)
        XCTAssertEqual(loadedFirst?.title, "PageLumen Demo")
        XCTAssertEqual(loadedSecond?.title, "Alternate Import")
    }

    func testRecentDocumentsSortedByLastOpened() throws {
        let persisting = try makePersisting()

        let first = ReaderDocument(
            title: "First",
            sourceType: .pdf,
            createdAt: Date(timeIntervalSince1970: 0),
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 612, height: 792), blocks: [])]
        )
        let second = ReaderDocument(
            title: "Second",
            sourceType: .pdf,
            createdAt: Date(timeIntervalSince1970: 0),
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 612, height: 792), blocks: [])]
        )
        let third = ReaderDocument(
            title: "Third",
            sourceType: .pdf,
            createdAt: Date(timeIntervalSince1970: 0),
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 612, height: 792), blocks: [])]
        )

        try persisting.save(first)
        // Re-save to bump lastOpened for second and third.
        try persisting.save(first)
        try persisting.save(second)
        try persisting.save(third)

        let recents = try persisting.recentDocuments()
        XCTAssertEqual(recents.count, 3)
        // Most recently saved is first.
        XCTAssertEqual(recents.map(\.title), ["Third", "Second", "First"])
    }

    func testForgetAllEmptiesTheStore() throws {
        let persisting = try makePersisting()
        let first = SampleDataFactory.makeDemoDocument()
        let second = ReaderDocument(
            title: "Other",
            sourceType: .pdf,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 612, height: 792), blocks: [])]
        )

        try persisting.save(first)
        try persisting.save(second)
        XCTAssertEqual(try persisting.recentDocuments().count, 2)

        try persisting.forgetAll()

        let recents = try persisting.recentDocuments()
        XCTAssertTrue(recents.isEmpty)
        let loaded = try persisting.load(id: first.id)
        XCTAssertNil(loaded)
    }

    func testLoadReturnsNilForUnknownID() throws {
        let persisting = try makePersisting()
        let missing = try persisting.load(id: UUID())
        XCTAssertNil(missing)
    }

    func testVersionedSchemaDeclaresAdditiveMigrationPlan() throws {
        XCTAssertEqual(PageLumenSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(PageLumenSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(PageLumenMigrationPlan.schemas.count, 2)
        XCTAssertEqual(PageLumenMigrationPlan.stages.count, 1)

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PersistedDocument.self,
            migrationPlan: PageLumenMigrationPlan.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let persisted = PersistedDocument(
            id: UUID(),
            title: "Migration fixture",
            createdAt: Date(),
            lastOpened: Date(),
            pageCount: 1,
            sourceType: SourceType.pdf.rawValue,
            jsonData: Data("{}".utf8)
        )
        context.insert(persisted)
        try context.save()
        XCTAssertEqual(persisted.storageRevision, 2)
    }

    func testV1StoreMigratesAndPreservesRecents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PageLumenMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("recents.store")
        let configuration = ModelConfiguration(url: storeURL)

        do {
            let oldContainer = try ModelContainer(
                for: PageLumenSchemaV1.PersistedDocument.self,
                configurations: configuration
            )
            let context = ModelContext(oldContainer)
            context.insert(PageLumenSchemaV1.PersistedDocument(
                id: UUID(),
                title: "Legacy recent",
                createdAt: Date(timeIntervalSince1970: 1),
                lastOpened: Date(timeIntervalSince1970: 2),
                pageCount: 3,
                sourceType: SourceType.pdf.rawValue,
                jsonData: Data("{}".utf8)
            ))
            try context.save()
        }

        let migrated = try ModelContainer(
            for: PersistedDocument.self,
            migrationPlan: PageLumenMigrationPlan.self,
            configurations: configuration
        )
        let context = ModelContext(migrated)
        let records = try context.fetch(FetchDescriptor<PersistedDocument>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.title, "Legacy recent")
        XCTAssertNil(records.first?.storageRevision)
    }

    func testMigrationRecoveryBackupPreservesStoreAndSQLiteJournalsAndCanRestore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumenRecovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("recents.store")
        try Data("old-store".utf8).write(to: storeURL)
        try Data("old-wal".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))
        try Data("old-shm".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-shm"))

        let backupURL = try XCTUnwrap(SwiftDataPersisting.createRecoveryBackup(for: storeURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.appendingPathComponent("store").path))
        XCTAssertEqual(try Data(contentsOf: backupURL.appendingPathComponent("store")), Data("old-store".utf8))
        XCTAssertEqual(try Data(contentsOf: backupURL.appendingPathComponent("store-wal")), Data("old-wal".utf8))
        XCTAssertEqual(try Data(contentsOf: backupURL.appendingPathComponent("store-shm")), Data("old-shm".utf8))

        // Simulate a partially-written failed migration. Restoration must
        // replace the base store and both SQLite journals from the backup.
        try Data("partial-new-store".utf8).write(to: storeURL)
        try SwiftDataPersisting.restoreRecoveryBackup(backupURL, to: storeURL)
        XCTAssertEqual(try Data(contentsOf: storeURL), Data("old-store".utf8))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: storeURL.path + "-wal")), Data("old-wal".utf8))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: storeURL.path + "-shm")), Data("old-shm".utf8))
    }

    func testRestoreRecoveryBackupRejectsIncompleteArtifactWithoutDeletingStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumenRecoveryInvalid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("recents.store")
        try Data("still-current".utf8).write(to: storeURL)
        let backupURL = directory.appendingPathComponent("bad.backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
        try Data("not-a-store".utf8).write(to: backupURL.appendingPathComponent("unexpected"))

        XCTAssertThrowsError(try SwiftDataPersisting.restoreRecoveryBackup(backupURL, to: storeURL)) { error in
            guard case let SwiftDataPersistingError.migrationFailed(path, reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, backupURL.path)
            XCTAssertEqual(reason, "Recovery backup is incomplete")
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), Data("still-current".utf8))
    }
}
