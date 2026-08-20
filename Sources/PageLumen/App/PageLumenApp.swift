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

    var body: some Scene {
        WindowGroup("PageLumen", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 1_120, minHeight: 720)
                .tint(AccessibleStyle.accent)
                .preferredColorScheme(appearancePreference == "light" ? .light : appearancePreference == "dark" ? .dark : nil)
                .sheet(isPresented: $isShowingOnboarding) {
                    OnboardingView(isPresented: $isShowingOnboarding)
                        .tint(AccessibleStyle.accent)
                }
                .onAppear {
                    if !hasSeenOnboarding && !isUITestingLaunch {
                        isShowingOnboarding = true
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
