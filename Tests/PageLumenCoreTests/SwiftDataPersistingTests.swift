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
}
