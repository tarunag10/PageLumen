#if canImport(AppIntents)
import AppIntents
import AppKit
import Foundation
import PageLumenCore

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
    }
}

extension Notification.Name {
    static let pageLumenOpenDocumentRequest = Notification.Name("PageLumenOpenDocumentRequest")
    static let pageLumenShowOnboardingRequest = Notification.Name("PageLumenShowOnboardingRequest")
}

enum PageLumenCoreSummaryBridge {
    @MainActor
    static func currentSummary() -> String? {
        nil
    }
}
#endif
