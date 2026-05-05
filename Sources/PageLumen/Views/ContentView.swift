import PageLumenCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            switch store.selectedDestination ?? .home {
            case .home:
                HomeView()
            case .review:
                ReviewView()
            case .summaryExport:
                SummaryExportView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.openDocumentPanel()
                } label: {
                    Label("Open Files", systemImage: "doc.badge.plus")
                }

                Button {
                    store.pasteImageFromClipboard()
                } label: {
                    Label("Paste Image", systemImage: "doc.on.clipboard")
                }

                if store.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }
}
