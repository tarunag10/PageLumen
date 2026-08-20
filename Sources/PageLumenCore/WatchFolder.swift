import Foundation

public struct WatchFolderCandidate: Identifiable, Equatable, Sendable {
    public var id: URL { url }
    public var url: URL
    public var byteSize: Int64

    public init(url: URL, byteSize: Int64) {
        self.url = url
        self.byteSize = byteSize
    }
}

/// A confirmed watch-folder import that failed. The URL is retained only so
/// the person can retry the same security-scoped file; presentation should use
/// `fileName` and `message`, never the full path.
public struct WatchFolderImportFailure: Identifiable, Equatable, Sendable {
    public let id: URL
    public let fileName: String
    public let message: String

    public init(url: URL, message: String) {
        self.id = url
        self.fileName = url.lastPathComponent.isEmpty ? "Unnamed file" : url.lastPathComponent
        self.message = Self.privacySafeMessage(message, fileURL: url)
    }

    public init(url: URL, error: Error) {
        self.init(url: url, message: error.localizedDescription)
    }

    /// Removes the source path from importer errors. This deliberately keeps
    /// the error useful while preventing a watch-folder location from leaking
    /// into status text, accessibility output, or screenshots.
    public static func privacySafeMessage(_ message: String, fileURL: URL) -> String {
        let replacements = [
            fileURL.standardizedFileURL.path,
            fileURL.resolvingSymlinksInPath().path,
            fileURL.path
        ].filter { !$0.isEmpty }
        var sanitized = message
        for path in replacements {
            sanitized = sanitized.replacingOccurrences(of: path, with: "[path omitted]")
        }
        // Some Foundation errors include a parent path without the exact file
        // path. Strip path-shaped whitespace-delimited tokens as a final guard.
        sanitized = sanitized
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in token.contains("/") ? "[path omitted]" : String(token) }
            .joined(separator: " ")
        return sanitized.isEmpty ? "Import failed" : sanitized
    }
}

public enum WatchFolderError: LocalizedError, Equatable, Sendable {
    case notDirectory
    case inaccessible
    case invalidBookmark

    public var errorDescription: String? {
        switch self {
        case .notDirectory: return "The selected watch folder is not a directory."
        case .inaccessible: return "PageLumen could not read the selected watch folder."
        case .invalidBookmark: return "The saved watch-folder permission is no longer valid. Select the folder again."
        }
    }
}

/// Bounded, deterministic discovery for an explicitly selected folder. This
/// type never starts importing by itself; callers must present candidates and
/// obtain confirmation before handing URLs to DocumentProcessor.
public struct WatchFolderScanner: Sendable {
    public static let defaultLimit = 100
    public static let supportedExtensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic"]

    public init() {}

    public func candidates(
        in folderURL: URL,
        excluding excludedURLs: Set<URL> = [],
        limit: Int = WatchFolderScanner.defaultLimit
    ) throws -> [WatchFolderCandidate] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) else {
            throw WatchFolderError.inaccessible
        }
        guard isDirectory.boolValue else { throw WatchFolderError.notDirectory }
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw WatchFolderError.inaccessible
        }

        let excludedPaths = Set(excludedURLs.map { $0.standardizedFileURL.path })
        return urls
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) && !excludedPaths.contains($0.standardizedFileURL.path) }
            .compactMap { url in
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true else { return nil }
                return WatchFolderCandidate(url: url, byteSize: Int64(values.fileSize ?? 0))
            }
            .sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
            .prefix(max(0, limit))
            .map { $0 }
    }
}

public struct WatchFolderBookmark: Codable, Equatable, Sendable {
    public let data: Data

    public init(data: Data) { self.data = data }

    public static func create(for folderURL: URL) throws -> Self {
        do {
            return Self(data: try folderURL.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil))
        } catch {
            throw WatchFolderError.inaccessible
        }
    }

    public func resolve() throws -> URL {
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale { throw WatchFolderError.invalidBookmark }
            return url
        } catch let error as WatchFolderError {
            throw error
        } catch {
            throw WatchFolderError.invalidBookmark
        }
    }
}

/// Opt-in polling monitor. It reports candidates but never imports them; the
/// caller must show confirmation and pass selected URLs to the import flow.
public final class WatchFolderMonitor: @unchecked Sendable {
    private let scanner: WatchFolderScanner
    private var task: Task<Void, Never>?
    private var accessedFolder: URL?

    public init(scanner: WatchFolderScanner = WatchFolderScanner()) {
        self.scanner = scanner
    }

    public func start(
        bookmark: WatchFolderBookmark,
        intervalNanoseconds: UInt64 = 5_000_000_000,
        onCandidates: @escaping @MainActor @Sendable ([WatchFolderCandidate]) async -> Void,
        onError: @escaping @MainActor @Sendable (WatchFolderError) async -> Void = { _ in }
    ) throws {
        stop()
        let folder = try bookmark.resolve()
        guard folder.startAccessingSecurityScopedResource() else {
            throw WatchFolderError.inaccessible
        }
        accessedFolder = folder
        task = Task { [scanner] in
            var seen = Set<URL>()
            while !Task.isCancelled {
                do {
                    let candidates = try scanner.candidates(in: folder, excluding: seen)
                    if !candidates.isEmpty {
                        seen.formUnion(candidates.map(\.url))
                        await onCandidates(candidates)
                    }
                } catch let error as WatchFolderError {
                    await onError(error)
                    break
                } catch {
                    await onError(.inaccessible)
                    break
                }
                do {
                    try await Task.sleep(nanoseconds: intervalNanoseconds)
                } catch {
                    break
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        if let accessedFolder {
            accessedFolder.stopAccessingSecurityScopedResource()
            self.accessedFolder = nil
        }
    }

    deinit { stop() }
}
