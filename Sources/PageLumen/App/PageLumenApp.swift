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
    @State private var isShowingOnboarding = false

    var body: some Scene {
        WindowGroup("PageLumen", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 1_120, minHeight: 720)
                .sheet(isPresented: $isShowingOnboarding) {
                    OnboardingView(isPresented: $isShowingOnboarding)
                }
                .onAppear {
                    if !hasSeenOnboarding {
                        isShowingOnboarding = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .pageLumenShowOnboardingRequest)) { _ in
                    isShowingOnboarding = true
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

                Button("Mark Page Reviewed") {
                    store.setSelectedPageReviewed(true)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(store)
        }

        MenuBarExtra("PageLumen", systemImage: "doc.text.magnifyingglass") {
            Button("Capture Selected Region") {
                store.captureSelectedRegion()
            }
            Button("Capture Window") {
                store.captureWindow()
            }
            Divider()
            Button("Open PageLumen Window") {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
