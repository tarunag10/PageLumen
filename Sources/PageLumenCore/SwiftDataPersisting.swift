import Foundation
import SwiftData

public enum SwiftDataPersistingError: Error, Equatable, Sendable {
    /// The versioned store could not be opened or migrated. `backupURL` is a
    /// pre-migration copy when one was available and must remain recoverable.
    case migrationFailed(backupURL: String?, reason: String)
}

extension SwiftDataPersistingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .migrationFailed(backupURL, reason):
            if let backupURL {
                return "SwiftData migration failed. Recovery backup: \(backupURL). \(reason)"
            }
            return "SwiftData migration failed without a recovery backup. \(reason)"
        }
    }
}

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
        let preMigrationBackup = try? Self.createRecoveryBackup(for: storeURL)
        do {
            self.modelContainer = try ModelContainer(
                for: PersistedDocument.self,
                migrationPlan: PageLumenMigrationPlan.self,
                configurations: config
            )
            if let preMigrationBackup {
                try? FileManager.default.removeItem(at: preMigrationBackup)
            }
        } catch {
            // Keep the pre-migration copy. The caller can fall back to JSON
            // recents while a future recovery UI restores this artifact.
            throw SwiftDataPersistingError.migrationFailed(
                backupURL: preMigrationBackup?.path,
                reason: error.localizedDescription
            )
        }
    }

    public init(configuration: ModelConfiguration, storeURL: URL? = nil) throws {
        let preMigrationBackup = storeURL.flatMap { try? Self.createRecoveryBackup(for: $0) } ?? nil
        do {
            self.modelContainer = try ModelContainer(
                for: PersistedDocument.self,
                migrationPlan: PageLumenMigrationPlan.self,
                configurations: configuration
            )
            if let preMigrationBackup {
                try? FileManager.default.removeItem(at: preMigrationBackup)
            }
        } catch {
            throw SwiftDataPersistingError.migrationFailed(
                backupURL: preMigrationBackup?.path,
                reason: error.localizedDescription
            )
        }
        self.storageDirectory = nil
    }

    /// Creates a sidecar recovery directory containing the store and its
    /// SQLite journals. It is intentionally public so a recovery UI or a
    /// release diagnostic can present an exact artifact without exposing
    /// document contents.
    public static func createRecoveryBackup(for storeURL: URL, fileManager: FileManager = .default) throws -> URL? {
        let sourceURLs = [storeURL, URL(fileURLWithPath: storeURL.path + "-wal"), URL(fileURLWithPath: storeURL.path + "-shm")]
            .filter { fileManager.fileExists(atPath: $0.path) }
        guard !sourceURLs.isEmpty else { return nil }

        let backupURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("\(storeURL.lastPathComponent).recovery-\(UUID().uuidString).backup", isDirectory: true)
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        do {
            for sourceURL in sourceURLs {
                let name: String
                if sourceURL.path == storeURL.path {
                    name = "store"
                } else if sourceURL.path.hasSuffix("-wal") {
                    name = "store-wal"
                } else {
                    name = "store-shm"
                }
                try fileManager.copyItem(at: sourceURL, to: backupURL.appendingPathComponent(name))
            }
            return backupURL
        } catch {
            try? fileManager.removeItem(at: backupURL)
            throw error
        }
    }

    /// Restores a previously-created recovery directory. Existing store and
    /// journal files are removed only after the backup has been validated.
    public static func restoreRecoveryBackup(_ backupURL: URL, to storeURL: URL, fileManager: FileManager = .default) throws {
        let entries = try fileManager.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: nil)
        guard entries.contains(where: { $0.lastPathComponent == "store" }) else {
            throw SwiftDataPersistingError.migrationFailed(backupURL: backupURL.path, reason: "Recovery backup is incomplete")
        }
        for suffix in ["", "-wal", "-shm"] {
            let destination = URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
        }
        for entry in entries {
            let destinationName: String
            switch entry.lastPathComponent {
            case "store": destinationName = storeURL.lastPathComponent
            case "store-wal": destinationName = storeURL.lastPathComponent + "-wal"
            case "store-shm": destinationName = storeURL.lastPathComponent + "-shm"
            default: continue
            }
            try fileManager.copyItem(at: entry, to: storeURL.deletingLastPathComponent().appendingPathComponent(destinationName))
        }
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
