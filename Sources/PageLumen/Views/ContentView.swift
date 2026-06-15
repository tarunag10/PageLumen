import PageLumenCore
import SwiftUI

struct ContentView: View {
    @Environment(DocumentStore.self) private var store
    // Re-render when the high-contrast toggle changes so AccessibleStyle tokens
    // (border, selected, elevatedBackground, appBackground) pick up the new
    // value.
    @AppStorage("boostContrast") private var boostContrast = false

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
                    case .processing:
                        ProcessingView()
                    case .review:
                        ReviewView()
                    case .summaryExport:
                        SummaryExportView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AccessibleStyle.appBackground)
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
    @Environment(DocumentStore.self) private var store
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        HStack(spacing: 12) {
            StepPill(number: 1, title: "Add", destination: .home)
            Divider()
                .frame(height: 18)
            StepPill(number: 2, title: "Process", destination: .processing)
            Divider()
                .frame(height: 18)
            StepPill(number: 3, title: "Review", destination: .review)
            Divider()
                .frame(height: 18)
            StepPill(number: 4, title: "Export", destination: .summaryExport)

            Spacer()

            if store.isProcessing {
                ProgressView()
                    .controlSize(.small)
                Text("Processing locally")
                    .font(.callout)
                    .foregroundStyle(.primary)
            } else {
                Text(nextStepText)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibleToolbarSurface()
    }

    private var nextStepText: String {
        switch store.selectedDestination ?? .home {
        case .home:
            return "Start by opening, dropping, pasting, or capturing a document."
        case .processing:
            return store.isProcessing ? "Extracting text and building the readable document." : store.statusMessage
        case .review:
            return "Check the extracted text, reading order, tables, and figures."
        case .summaryExport:
            return "Listen, choose export options, then save the output."
        }
    }
}

private struct StepPill: View {
    @Environment(DocumentStore.self) private var store
    let number: Int
    let title: String
    let destination: DocumentStore.Destination
    @AppStorage("boostContrast") private var boostContrast = false
    // ScaledMetric keeps the step indicator circle readable when the user
    // increases text size. The base 22 pt is the default at standard sizes.
    @ScaledMetric(relativeTo: .body) private var stepCircleSize: CGFloat = 22

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
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: stepCircleSize, height: stepCircleSize)
                    .background(isSelected ? AccessibleStyle.selected : AccessibleStyle.elevatedBackground, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(AccessibleStyle.border)
                    }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(number), \(title)")
    }
}
