#if canImport(AppIntents)
import AppIntents
import AppKit
import Foundation
import PageLumenCore

struct PageLumenDocumentEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "PageLumen document")
    static var defaultQuery = PageLumenDocumentQuery()

    var id: UUID
    var title: String
    var pageCount: Int
    var unresolvedFindings: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: "\(pageCount) pages · \(unresolvedFindings) unresolved findings"
        )
    }
}

struct PageLumenDocumentQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [PageLumenDocumentEntity] {
        libraryEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PageLumenDocumentEntity] {
        libraryEntities()
    }

    private func libraryEntities() -> [PageLumenDocumentEntity] {
        guard let repository = PageLumenIntentBridge.repository(),
              let documents = try? repository.recentMetadata() else { return [] }
        return documents.map { metadata in
            PageLumenDocumentEntity(
                id: metadata.id,
                title: metadata.title,
                pageCount: metadata.pageCount,
                unresolvedFindings: metadata.unresolvedFindingCount
            )
        }
    }
}

struct SearchPageLumenLibraryIntent: AppIntent {
    static var title: LocalizedStringResource = "Search PageLumen Library"
    static var description = IntentDescription("Search documents already retained in PageLumen's local library.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search text")
    var query: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let repository = PageLumenIntentBridge.repository() else {
            return .result(value: "Local library is unavailable.", dialog: "PageLumen's local library is unavailable.")
        }
        let results = try repository.search(query: query, limit: 10)
        guard !results.isEmpty else {
            return .result(value: "No local matches found.", dialog: "No matching PageLumen documents were found.")
        }
        let text = results.map { "\($0.title), page \($0.pageNumber): \($0.snippet)" }.joined(separator: "\n")
        return .result(value: text, dialog: "Found \(results.count) local match\(results.count == 1 ? "" : "es") in PageLumen.")
    }
}

struct OpenPageLumenDocumentIntent: AppIntent {
    static var title: LocalizedStringResource = "Open PageLumen Document"
    static var description = IntentDescription("Open a document retained in PageLumen's local library.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Document")
    var document: PageLumenDocumentEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .pageLumenOpenLibraryDocumentRequest, object: nil, userInfo: ["id": document.id])
        return .result(dialog: "Opening \(document.title) in PageLumen.")
    }
}

struct ReadUnresolvedPageLumenFindingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Unresolved PageLumen Findings"
    static var description = IntentDescription("Report unresolved review findings in a local PageLumen document.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Document")
    var document: PageLumenDocumentEntity

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let repository = PageLumenIntentBridge.repository(), let loaded = try repository.document(id: document.id) else {
            return .result(value: "Document is unavailable.", dialog: "That document is no longer in the local library.")
        }
        let findings = DocumentEditing.reviewFindings(for: loaded).filter { !$0.isResolved }
        let text = findings.isEmpty ? "No unresolved findings." : findings.map { "Page \($0.pageNumber): \($0.title) — \($0.detail)" }.joined(separator: "\n")
        return .result(value: text, dialog: findings.isEmpty ? "No unresolved findings." : "There are \(findings.count) unresolved findings.")
    }
}

/// Exports a retained local document to a caller-provided URL. A URL parameter
/// keeps this intent non-interactive: Shortcuts or another caller chooses the
/// destination, and PageLumen never presents an NSSavePanel during execution.
struct ExportTaggedHTMLIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Tagged HTML from PageLumen"
    static var description = IntentDescription("Export a selected local PageLumen document as review-ready Tagged HTML.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Document")
    var document: PageLumenDocumentEntity

    @Parameter(title: "Destination file")
    var destination: URL

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let repository = PageLumenIntentBridge.repository(),
              let loaded = try repository.document(id: document.id) else {
            return .result(dialog: "That PageLumen document is no longer in the local library.")
        }

        do {
            try PageLumenIntentBridge.exportTaggedHTML(document: loaded, to: destination)
            return .result(dialog: "Exported Tagged HTML for \(document.title) to \(destination.lastPathComponent).")
        } catch let error as PageLumenIntentExportError {
            return .result(dialog: error.localizedDescription)
        } catch {
            return .result(dialog: "Tagged HTML export failed: \(error.localizedDescription)")
        }
    }
}

@available(macOS 14.0, *)
struct OpenDocumentIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Document in PageLumen"
    static var description = IntentDescription("Open a PDF or image file in PageLumen for extraction.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "File URL")
    var fileURL: URL

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(
            name: .pageLumenOpenDocumentRequest,
            object: nil,
            userInfo: ["url": fileURL]
        )
        return .result(dialog: "Opening \(fileURL.lastPathComponent) in PageLumen.")
    }
}

@available(macOS 14.0, *)
struct GetSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get PageLumen Document Summary"
    static var description = IntentDescription("Read the most recent document's summary aloud.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = await MainActor.run { PageLumenCoreSummaryBridge.currentSummary() }
        let trimmed = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return .result(
                value: "No summary available.",
                dialog: "PageLumen does not have a document loaded."
            )
        }
        return .result(
            value: trimmed,
            dialog: "Here is the current PageLumen summary."
        )
    }
}

@available(macOS 14.0, *)
struct PageLumenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenDocumentIntent(),
            phrases: [
                "Open in \(.applicationName)",
                "Send to \(.applicationName)"
            ],
            shortTitle: "Open Document",
            systemImageName: "doc.fill"
        )
        AppShortcut(
            intent: GetSummaryIntent(),
            phrases: [
                "Get summary from \(.applicationName)",
                "Read summary in \(.applicationName)"
            ],
            shortTitle: "Get Summary",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: SearchPageLumenLibraryIntent(),
            phrases: ["Search my \(.applicationName) library", "Find in my \(.applicationName) documents"],
            shortTitle: "Search Library",
            systemImageName: "magnifyingglass"
        ),
        AppShortcut(
            intent: ExportTaggedHTMLIntent(),
            phrases: ["Export Tagged HTML from \(.applicationName)"],
            shortTitle: "Export Tagged HTML",
            systemImageName: "doc.richtext"
        )
    }
}

extension Notification.Name {
    static let pageLumenOpenDocumentRequest = Notification.Name("PageLumenOpenDocumentRequest")
    static let pageLumenOpenLibraryDocumentRequest = Notification.Name("PageLumenOpenLibraryDocumentRequest")
    static let pageLumenShowOnboardingRequest = Notification.Name("PageLumenShowOnboardingRequest")
}

enum PageLumenCoreSummaryBridge {
    @MainActor
    static func currentSummary() -> String? {
        nil
    }
}

enum PageLumenIntentBridge {
    static func repository() -> LocalDocumentRepository? {
        if #available(macOS 14.0, *), let persisting = try? SwiftDataPersisting() {
            return LocalDocumentRepository(persisting: persisting)
        }
        return LocalDocumentRepository(persisting: FilePersisting())
    }

    static func exportTaggedHTML(document: ReaderDocument, to destination: URL, options: ExportOptions = .full) throws {
        let validation = ExportEngine().validate(document: document, format: .taggedHTML, options: options)
        guard validation.canExport else {
            throw PageLumenIntentExportError.validation(validation.findings.first ?? "Tagged HTML export requires review.")
        }
        let data = ExportEngine().data(for: document, format: .taggedHTML, options: options)
        try data.write(to: destination, options: .atomic)
    }
}

enum PageLumenIntentExportError: LocalizedError {
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let finding):
            return "Tagged HTML export is unavailable until review is complete: \(finding)"
        }
    }
}
#endif
