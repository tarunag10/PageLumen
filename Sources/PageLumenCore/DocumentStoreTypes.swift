import AppKit
import Foundation

public protocol DocumentImporting: Sendable {
    func process(url: URL, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument
    func process(securityScopedURL url: URL, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument
    func processClipboardImage(_ image: NSImage, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument
}

public extension DocumentImporting {
    /// Compatibility default keeps lightweight test/import providers working
    /// while the production processor accepts quality and page-range choices.
    func process(url: URL, options: ProcessingImportOptions, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument {
        try await process(url: url, onProgress: onProgress)
    }

    func process(securityScopedURL url: URL, options: ProcessingImportOptions, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument {
        try await process(securityScopedURL: url, onProgress: onProgress)
    }
}

public protocol DocumentPersisting: Sendable {
    func save(_ document: ReaderDocument) throws
    func load(id: UUID) throws -> ReaderDocument?
    func recentDocuments() throws -> [ReaderDocument]
    func delete(id: UUID) throws
    func forgetAll() throws

    /// Returns the on-disk footprint of this persistence store when it can be
    /// measured. A nil value means the implementation cannot expose a stable
    /// filesystem footprint.
    func storageSizeInBytes() throws -> Int64?
}

public extension DocumentPersisting {
    func storageSizeInBytes() throws -> Int64? { nil }
}
