import Foundation

public enum FilePersistingError: Error, Equatable, Sendable {
    case corruptStore
    case unsupportedSchemaVersion(Int)
}

public final class FilePersisting: DocumentPersisting, @unchecked Sendable {
    public static let recentDocumentsLimit = 12
    /// Version of the on-disk JSON envelope. Legacy array stores are accepted
    /// and upgraded on the next successful write.
    public static let schemaVersion = 1

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let writeData: (Data, URL) throws -> Void

    public init(fileURL: URL, writeData: @escaping (Data, URL) throws -> Void = { data, url in
        try data.write(to: url, options: .atomic)
    }) {
        self.fileURL = fileURL
        self.writeData = writeData
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public convenience init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            .map { $0.appendingPathComponent("PageLumen", isDirectory: true) }
        let directory = support ?? FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent("Library", isDirectory: true).appendingPathComponent("recent.json")
        self.init(fileURL: url)
    }

    public var storageURL: URL { fileURL }

    public func storageSizeInBytes() throws -> Int64? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return 0 }
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    public func save(_ document: ReaderDocument) throws {
        var documents = try loadAll()
        documents.removeAll { existing in
            existing.id == document.id || (existing.sourceURL != nil && existing.sourceURL == document.sourceURL)
        }
        documents.insert(document, at: 0)
        if documents.count > Self.recentDocumentsLimit {
            documents = Array(documents.prefix(Self.recentDocumentsLimit))
        }
        try persist(documents)
    }

    public func load(id: UUID) throws -> ReaderDocument? {
        try loadAll().first { $0.id == id }
    }

    public func recentDocuments() throws -> [ReaderDocument] {
        try loadAll()
    }

    public func delete(id: UUID) throws {
        var documents = try loadAll()
        documents.removeAll { $0.id == id }
        try persist(documents)
    }

    public func forgetAll() throws {
        try persist([])
    }

    private func loadAll() throws -> [ReaderDocument] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return []
        }
        do {
            if let envelope = try? decoder.decode(PersistedLibrary.self, from: data) {
                guard envelope.schemaVersion == Self.schemaVersion else {
                    throw FilePersistingError.unsupportedSchemaVersion(envelope.schemaVersion)
                }
                return envelope.documents
            }

            // Version 0 was an unversioned top-level array. Keep it readable
            // so upgrades never strand a person's local recents.
            return try decoder.decode([ReaderDocument].self, from: data)
        } catch let error as FilePersistingError {
            // A future schema must remain in place for a newer binary to
            // recover; do not relabel it as corruption or move it aside.
            throw error
        } catch {
            // Preserve the bytes for recovery instead of silently converting a
            // damaged local library into an empty one. The next save can create
            // a fresh store while the renamed backup remains user-recoverable.
            let backup = fileURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(UUID().uuidString)")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            throw FilePersistingError.corruptStore
        }
    }

    private func persist(_ documents: [ReaderDocument]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(PersistedLibrary(schemaVersion: Self.schemaVersion, documents: documents))
        try writeData(data, fileURL)
    }
}

private struct PersistedLibrary: Codable {
    let schemaVersion: Int
    let documents: [ReaderDocument]
}
