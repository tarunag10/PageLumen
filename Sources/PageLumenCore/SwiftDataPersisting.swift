import Foundation
import SwiftData

@available(macOS 14.0, *)
public final class SwiftDataPersisting: DocumentPersisting, @unchecked Sendable {
    private let modelContainer: ModelContainer

    public init() {
        let appSupportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appDir = appSupportDir.appendingPathComponent("PageLumen", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let storeURL = appDir.appendingPathComponent("recents.store")
        let config = ModelConfiguration(url: storeURL)
        // SwiftData must be able to initialize the on-disk store. If it
        // cannot, the app cannot persist recents, so we surface a clear
        // fatal error. DocumentStore.init falls back to FilePersisting on
        // macOS versions that cannot import SwiftData at all.
        do {
            self.modelContainer = try ModelContainer(
                for: PersistedDocument.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    public init(configuration: ModelConfiguration) throws {
        self.modelContainer = try ModelContainer(
            for: PersistedDocument.self,
            configurations: configuration
        )
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
        } else {
            let new = PersistedDocument(
                id: document.id,
                title: document.title,
                createdAt: document.createdAt,
                lastOpened: Date(),
                pageCount: document.pageCount,
                sourceType: document.sourceType.rawValue,
                jsonData: jsonData
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

    public func forgetAll() throws {
        let context = ModelContext(modelContainer)
        try context.delete(model: PersistedDocument.self)
        try context.save()
    }
}
