import AppKit
import PageLumenCore
import SwiftUI
import TipKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard PageLumenSystemWorkflowContract.supportsDocumentURL(url) else { continue }
            NotificationCenter.default.post(
                name: .pageLumenOpenDocumentRequest,
                object: nil,
                userInfo: ["url": url]
            )
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
                }
                .onReceive(NotificationCenter.default.publisher(for: .pageLumenShowOnboardingRequest)) { _ in
                    isShowingOnboarding = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .pageLumenOpenLibraryDocumentRequest)) { notification in
                    guard let id = notification.userInfo?["id"] as? UUID else { return }
                    store.openRecentDocument(id: id)
                }
                .onReceive(NotificationCenter.default.publisher(for: .pageLumenOpenDocumentRequest)) { notification in
                    guard let url = notification.userInfo?["url"] as? URL else { return }
                    store.startImport(urls: [url])
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

                Button("Paste Image") {
                    store.pasteImageFromClipboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Review First Issue") {
                    store.jumpToFirstReviewIssue()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Next Review Issue") {
                    store.jumpToNextReviewIssue()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Review Issue") {
                    store.jumpToPreviousReviewIssue()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Accept Current Review Finding") {
                    store.acceptCurrentReviewIssue()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(store.currentReviewIssue == nil)

                Button("Reject Current Review Finding") {
                    store.rejectCurrentReviewIssue()
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                .disabled(store.currentReviewIssue == nil)

                Button("Mark Page Reviewed") {
                    store.setSelectedPageReviewed(true)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .tint(AccessibleStyle.accent)
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
        Button("Capture Window") {
            store.captureWindow()
        }
        Divider()
        Button("Open PageLumen Window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
