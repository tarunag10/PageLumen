import PageLumenCore
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

            if !store.batchQueue.items.isEmpty {
                Section("Batch") {
                    ForEach(store.batchQueue.items) { item in
                        Button {
                            store.selectBatchItem(item)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: iconName(for: item.status))
                                    .foregroundStyle(color(for: item.status))
                                    .frame(width: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.fileName)
                                        .lineLimit(1)

                                    Text(detail(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                Section("Recent") {
                    ForEach(store.recentDocuments) { document in
                        Button {
                            store.selectRecentDocument(document)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(document.title)
                                        .lineLimit(1)

                                    Text("\(document.pageCount) page\(document.pageCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    private func iconName(for status: BatchImportItemStatus) -> String {
        switch status {
        case .pending:
            return "circle"
        case .processing:
            return "hourglass"
        case .complete:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private func color(for status: BatchImportItemStatus) -> Color {
        switch status {
        case .pending:
            return .secondary
        case .processing:
            return .accentColor
        case .complete:
            return .green
        case .failed:
            return .orange
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
