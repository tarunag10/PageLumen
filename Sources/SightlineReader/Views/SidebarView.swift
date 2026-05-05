import SightlineCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        List(selection: $store.selectedDestination) {
            Section("Workflow") {
                Label("Home", systemImage: "tray.and.arrow.down")
                    .tag(DocumentStore.Destination.home)
                Label("Review", systemImage: "rectangle.split.2x1")
                    .tag(DocumentStore.Destination.review)
                Label("Summary & Export", systemImage: "waveform.and.arrow.up")
                    .tag(DocumentStore.Destination.summaryExport)
            }

            Section("Outline") {
                if store.document.outline.isEmpty {
                    Text("No headings detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.document.outline) { item in
                        Button {
                            store.selectedPageNumber = item.pageNumber
                            store.selectedDestination = .review
                        } label: {
                            HStack {
                                Image(systemName: "textformat.size")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .lineLimit(1)
                                    Text("Page \(item.pageNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.document.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(store.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }
}
