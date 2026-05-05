import AppKit
import SightlineCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SightlineReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup("Sightline Reader", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1_120, minHeight: 720)
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
            }
        }

        Settings {
            SettingsView()
        }
    }
}
