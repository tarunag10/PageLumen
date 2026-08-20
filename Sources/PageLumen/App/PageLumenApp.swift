import AppKit
import PageLumenCore
import SwiftUI
import TipKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct PageLumenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DocumentStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appearancePreference") private var appearancePreference = "system"
    @State private var isShowingOnboarding = false

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
                    if !hasSeenOnboarding {
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
