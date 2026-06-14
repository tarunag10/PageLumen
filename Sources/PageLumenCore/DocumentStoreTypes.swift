import AppKit
import Foundation

public protocol DocumentImporting: Sendable {
    func process(url: URL, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument
    func process(securityScopedURL url: URL, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument
    func processClipboardImage(_ image: NSImage, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument
}

public protocol DocumentPersisting: Sendable {
    func save(_ document: ReaderDocument) throws
    func load(id: UUID) throws -> ReaderDocument?
    func recentDocuments() throws -> [ReaderDocument]
    func forgetAll() throws
}
