import PageLumenCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 280)

            Divider()

            Group {
                switch store.selectedDestination ?? .home {
                case .home:
                    HomeView()
                case .review:
                    ReviewView()
                case .summaryExport:
                    SummaryExportView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
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
