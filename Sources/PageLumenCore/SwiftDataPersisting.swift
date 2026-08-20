import Foundation
import SwiftData

@available(macOS 14.0, *)
public final class SwiftDataPersisting: DocumentPersisting, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let storageDirectory: URL?

    public init() throws {
        let appSupportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appDir = appSupportDir.appendingPathComponent("PageLumen", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let storeURL = appDir.appendingPathComponent("recents.store")
        self.storageDirectory = appDir
        let config = ModelConfiguration(url: storeURL)
        self.modelContainer = try ModelContainer(
            for: PersistedDocument.self,
            migrationPlan: PageLumenMigrationPlan.self,
            configurations: config
        )
    }

    public init(configuration: ModelConfiguration) throws {
        self.modelContainer = try ModelContainer(
            for: PersistedDocument.self,
            migrationPlan: PageLumenMigrationPlan.self,
            configurations: configuration
        )
        self.storageDirectory = nil
    }

    public func save(_ document: ReaderDocument) throws {
        let context = ModelContext(modelContainer)
        let jsonData = try JSONEncoder().encode(document)
        let targetID = document.id
        let descriptor = FetchDescriptor<PersistedDocument>(
            predicate: #Predicate { $0.id == targetID }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.title = document.title
            existing.lastOpened = Date()
            existing.pageCount = document.pageCount
                existing.sourceType = document.sourceType.rawValue
                existing.jsonData = jsonData
            existing.storageRevision = 2
        } else {
            let new = PersistedDocument(
                id: document.id,
                title: document.title,
                createdAt: document.createdAt,
                lastOpened: Date(),
                pageCount: document.pageCount,
                sourceType: document.sourceType.rawValue,
                jsonData: jsonData,
                storageRevision: 2
            )
            context.insert(new)
        }
        try context.save()
    }

    public func load(id: UUID) throws -> ReaderDocument? {
        let context = ModelContext(modelContainer)
        let targetID = id
        let descriptor = FetchDescriptor<PersistedDocument>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let persisted = try context.fetch(descriptor).first else {
            return nil
        }
        return try JSONDecoder().decode(ReaderDocument.self, from: persisted.jsonData)
    }

    public func recentDocuments() throws -> [ReaderDocument] {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<PersistedDocument>(
            sortBy: [SortDescriptor(\.lastOpened, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        let persisted = try context.fetch(descriptor)
        return persisted.compactMap {
            try? JSONDecoder().decode(ReaderDocument.self, from: $0.jsonData)
        }
    }

    public func delete(id: UUID) throws {
        let context = ModelContext(modelContainer)
        let targetID = id
        let descriptor = FetchDescriptor<PersistedDocument>(
            predicate: #Predicate { $0.id == targetID }
        )
        for document in try context.fetch(descriptor) {
            context.delete(document)
        }
        try context.save()
    }

    public func forgetAll() throws {
        let context = ModelContext(modelContainer)
        try context.delete(model: PersistedDocument.self)
        try context.save()
    }

    public func storageSizeInBytes() throws -> Int64? {
        guard let storageDirectory else { return nil }
        guard FileManager.default.fileExists(atPath: storageDirectory.path) else { return 0 }
        return try FileManager.default.sizeOfItem(at: storageDirectory)
    }
}

private extension FileManager {
    func sizeOfItem(at url: URL) throws -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue {
            let attributes = try attributesOfItem(atPath: url.path)
            return (attributes[.size] as? NSNumber)?.int64Value ?? 0
        }
        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return try contents.reduce(Int64(0)) { total, child in
            total + (try sizeOfItem(at: child))
        }
    }
}
