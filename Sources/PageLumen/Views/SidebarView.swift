import PageLumenCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        List(selection: $store.selectedDestination) {
            Section("Steps") {
                Label("1. Add Document", systemImage: "tray.and.arrow.down")
                    .tag(DocumentStore.Destination.home)
                Label("2. Process", systemImage: "text.viewfinder")
                    .tag(DocumentStore.Destination.processing)
                Label("3. Review Text", systemImage: "rectangle.split.2x1")
                    .tag(DocumentStore.Destination.review)
                Label("4. Listen & Export", systemImage: "square.and.arrow.up")
                    .tag(DocumentStore.Destination.summaryExport)
            }

            if !store.batchQueue.items.isEmpty {
                Section("Batch") {
                    ForEach(store.batchQueue.items) { item in
                        Button {
                            store.selectBatchItem(item)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.status.statusDescriptor.systemImage)
                                    .foregroundStyle(item.status.statusDescriptor.tint)
                                    .frame(width: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.fileName)
                                        .lineLimit(1)

                                    Text(detail(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(item.document == nil)
                    }
                }
            }

            if !store.recentDocuments.isEmpty {
                Section("Library") {
                    ForEach(store.recentDocuments) { document in
                        Button {
                            store.selectRecentDocument(document)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: document.processingStatus == .complete ? "checkmark.circle" : "doc.text.magnifyingglass")
                                    .foregroundStyle(.primary)
                                    .frame(width: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(document.title)
                                        .lineLimit(1)

                                    Text("\(document.pageCount) page\(document.pageCount == 1 ? "" : "s") • \(document.processingStatus.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Outline") {
                if store.document.outline.isEmpty {
                    Text("Headings appear here after import")
                        .foregroundStyle(.primary)
                } else {
                    ForEach(store.document.outline) { item in
                        Button {
                            store.selectedPageNumber = item.pageNumber
                            store.selectedDestination = .review
                        } label: {
                            HStack {
                                Image(systemName: "textformat.size")
                                    .foregroundStyle(.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .lineLimit(1)
                                    Text("Page \(item.pageNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.primary)
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
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibleToolbarSurface()
        }
    }

    private func detail(for item: BatchImportItem) -> String {
        switch item.status {
        case .failed(let message):
            return message
        default:
            return item.status.label
        }
    }
}
