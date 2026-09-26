import AppKit
import PageLumenCore
import SwiftUI
import TipKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingOpenURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let supportedURLs = queueOpenURLs(urls)
        guard !supportedURLs.isEmpty else { return }
        var userInfo: [AnyHashable: Any] = ["urls": supportedURLs]
        // Preserve the original single-file notification contract for older
        // receivers while the `urls` payload carries multi-file opens.
        if supportedURLs.count == 1, let url = supportedURLs.first {
            userInfo["url"] = url
        }
        NotificationCenter.default.post(
            name: .pageLumenOpenDocumentRequest,
            object: nil,
            userInfo: userInfo
        )
    }

    @discardableResult
    func queueOpenURLs(_ urls: [URL]) -> [URL] {
        let supportedURLs = urls.filter(PageLumenSystemWorkflowContract.supportsDocumentURL)
        pendingOpenURLs.append(contentsOf: supportedURLs)
        return supportedURLs
    }

    func consumePendingOpenURLs() -> [URL] {
        defer { pendingOpenURLs.removeAll() }
        return pendingOpenURLs
    }

    func restorePendingOpenURLs(_ urls: [URL]) {
        pendingOpenURLs.insert(contentsOf: urls, at: 0)
    }

    func markOpenURLDelivered(_ url: URL) {
        pendingOpenURLs.removeAll { $0 == url }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI creates WindowGroup windows after applicationDidFinishLaunching;
        // dispatching once lets the scene materialize before bringing it forward.
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.canBecomeKey }) else { return }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct PageLumenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DocumentStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appearancePreference") private var appearancePreference = "system"
    @State private var isShowingOnboarding = false

    /// UI tests use a clean, isolated launch mode so the first screen is
    /// deterministic. This does not alter normal launches or persisted user
    /// preferences.
    private var isUITestingLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    private var isUITestingFixtureLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-fixture")
    }

    /// Gives XCUITests a deterministic route to the native Settings scene
    /// without depending on the system Settings menu or persisted state.
    /// This argument is test-only and has no effect during normal launches.
    private var isUITestingSettingsLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-settings")
    }

    private var isUITestingReviewEmptyLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-review-empty")
    }

    private var isUITestingExportEmptyLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-export-empty")
    }

    /// Appearance overrides are test-only launch seams. They let the UI
    /// contract exercise all three supported appearance choices without
    /// changing the user's persisted preference or depending on the host
    /// Mac's current System Settings appearance.
    private var uiTestingAppearancePreference: String? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-appearance-light") { return "light" }
        if arguments.contains("-ui-testing-appearance-dark") { return "dark" }
        if arguments.contains("-ui-testing-appearance-system") { return "system" }
        return nil
    }

    private var effectiveAppearancePreference: String {
        uiTestingAppearancePreference ?? appearancePreference
    }

    /// Provides a bounded import/recovery route for XCUITest. It never runs
    /// during a normal launch and deliberately uses the in-memory demo rather
    /// than opening a system panel or changing Screen Recording permission.
    private var uiTestingImportMode: HomeUITestingMode? {
        guard isUITestingLaunch else { return nil }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-import-denied") {
            return .permissionDenied
        }
        return ProcessInfo.processInfo.arguments.contains("-ui-testing-import") ? .importFixture : nil
    }

    var body: some Scene {
        WindowGroup("PageLumen", id: "main") {
            Group {
                if isUITestingSettingsLaunch {
                    SettingsView(appearanceOverride: uiTestingAppearancePreference)
                } else {
                    ContentView(uiTestingImportMode: uiTestingImportMode)
                }
            }
                .environment(store)
                .frame(minWidth: 1_120, minHeight: 720)
                .tint(AccessibleStyle.accent)
                .preferredColorScheme(effectiveAppearancePreference == "light" ? .light : effectiveAppearancePreference == "dark" ? .dark : nil)
                .sheet(isPresented: $isShowingOnboarding) {
                    OnboardingView(isPresented: $isShowingOnboarding)
                        .tint(AccessibleStyle.accent)
                }
                .onAppear {
                    if !hasSeenOnboarding && !isUITestingLaunch {
                        isShowingOnboarding = true
                    }
                    if isUITestingFixtureLaunch {
                        store.loadSample()
                    }
                    if isUITestingReviewEmptyLaunch {
                        store.document = ReaderDocument(title: "Empty", sourceType: .sample, pages: [])
                        store.selectedDestination = .review
                    }
                    if isUITestingExportEmptyLaunch {
                        store.document = ReaderDocument(title: "Empty", sourceType: .sample, pages: [])
                        store.selectedDestination = .summaryExport
                    }
                    let pendingURLs = appDelegate.consumePendingOpenURLs()
                    if !pendingURLs.isEmpty, !store.startImport(urls: pendingURLs) {
                        appDelegate.restorePendingOpenURLs(pendingURLs)
                    }
                }
                .onChange(of: store.isProcessing) { _, isProcessing in
                    guard !isProcessing else { return }
                    let pendingURLs = appDelegate.consumePendingOpenURLs()
                    guard !pendingURLs.isEmpty else { return }
                    if !store.startImport(urls: pendingURLs) {
                        appDelegate.restorePendingOpenURLs(pendingURLs)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .pageLumenShowOnboardingRequest)) { _ in
                    isShowingOnboarding = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .pageLumenOpenLibraryDocumentRequest)) { notification in
                    guard let id = notification.userInfo?["id"] as? UUID else { return }
                    store.openRecentDocument(id: id)
                }
                .onReceive(NotificationCenter.default.publisher(for: .pageLumenOpenDocumentRequest)) { notification in
                    let urls = (notification.userInfo?["urls"] as? [URL])
                        ?? (notification.userInfo?["url"] as? URL).map { [$0] }
                    guard let urls, !urls.isEmpty else { return }
                    if store.isProcessing {
                        let noun = urls.count == 1 ? "file" : "files"
                        store.statusMessage = "Queued \(urls.count) \(noun); it will import after the current operation finishes."
                        return
                    }
                    guard store.startImport(urls: urls) else { return }
                    urls.forEach(appDelegate.markOpenURLDelivered)
                }
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Documents...") {
                    store.openDocumentPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(store.isProcessing)

                Button("Paste Image") {
                    store.pasteImageFromClipboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(store.isProcessing)

                Button("Review First Issue") {
                    store.jumpToFirstReviewIssue()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.reviewIssueCount == 0)

                Button("Next Review Issue") {
                    store.jumpToNextReviewIssue()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(store.reviewIssueCount == 0)

                Button("Previous Review Issue") {
                    store.jumpToPreviousReviewIssue()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(store.reviewIssueCount == 0)

                Button("Accept Current Review Finding") {
                    store.acceptCurrentReviewIssue()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(store.isProcessing || store.currentReviewIssue == nil)

                Button("Reject Current Review Finding") {
                    store.rejectCurrentReviewIssue()
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                .disabled(store.isProcessing || store.currentReviewIssue == nil)

                Button("Mark Page Reviewed") {
                    store.setSelectedPageReviewed(true)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(store.isProcessing || store.selectedPage == nil || store.selectedPage?.blocks.isEmpty == true)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .tint(AccessibleStyle.accent)
                .preferredColorScheme(effectiveAppearancePreference == "light" ? .light : effectiveAppearancePreference == "dark" ? .dark : nil)
        }

        MenuBarExtra("PageLumen", systemImage: "doc.text.magnifyingglass") {
            MenuBarActions()
                .environment(store)
        }
    }
}

private struct MenuBarActions: View {
    @Environment(DocumentStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Capture Selected Region") {
            store.captureSelectedRegion()
        }
        .disabled(store.isProcessing)
        .help(store.isProcessing ? "Finish or cancel the current import first" : "Capture a selected screen region")
        Button("Capture Window") {
            store.captureWindow()
        }
        .disabled(store.isProcessing)
        .help(store.isProcessing ? "Finish or cancel the current import first" : "Capture the current window")
        Divider()
        Button("Open PageLumen Window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
