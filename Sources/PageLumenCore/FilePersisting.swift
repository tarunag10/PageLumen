import Foundation

public final class FilePersisting: DocumentPersisting, @unchecked Sendable {
    public static let recentDocumentsLimit = 12

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
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
            return try decoder.decode([ReaderDocument].self, from: data)
        } catch {
            return []
        }
    }

    private func persist(_ documents: [ReaderDocument]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(documents)
        try data.write(to: fileURL, options: .atomic)
    }
}
