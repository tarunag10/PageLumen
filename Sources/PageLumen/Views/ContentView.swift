import PageLumenCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 280)

            Divider()

            VStack(spacing: 0) {
                WorkflowHeader()

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct WorkflowHeader: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        HStack(spacing: 12) {
            StepPill(number: 1, title: "Add", destination: .home)
            Divider()
                .frame(height: 18)
            StepPill(number: 2, title: "Review", destination: .review)
            Divider()
                .frame(height: 18)
            StepPill(number: 3, title: "Export", destination: .summaryExport)

            Spacer()

            if store.isProcessing {
                ProgressView()
                    .controlSize(.small)
                Text("Processing locally")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(nextStepText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var nextStepText: String {
        switch store.selectedDestination ?? .home {
        case .home:
            return "Start by opening, dropping, pasting, or capturing a document."
        case .review:
            return "Check the extracted text, reading order, tables, and figures."
        case .summaryExport:
            return "Listen, choose export options, then save the output."
        }
    }
}

private struct StepPill: View {
    @EnvironmentObject private var store: DocumentStore
    let number: Int
    let title: String
    let destination: DocumentStore.Destination

    private var isSelected: Bool {
        (store.selectedDestination ?? .home) == destination
    }

    var body: some View {
        Button {
            store.selectedDestination = destination
        } label: {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 22, height: 22)
                    .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), in: Circle())

                Text(title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(number), \(title)")
    }
}
