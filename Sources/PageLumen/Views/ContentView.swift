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
                .frame(width: 264)

            VStack(spacing: 0) {
                WorkflowHeader()

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
        .background(AccessibleStyle.appBackground)
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
                        .tint(AccessibleStyle.accentBright)
                }
            }
        }
    }
}

private struct WorkflowHeader: View {
    @Environment(DocumentStore.self) private var store
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        HStack(spacing: 10) {
            StepPill(number: 1, title: "Add", destination: .home)
            StepConnector()
            StepPill(number: 2, title: "Process", destination: .processing)
            StepConnector()
            StepPill(number: 3, title: "Review", destination: .review)
            StepConnector()
            StepPill(number: 4, title: "Export", destination: .summaryExport)

            Spacer()

            if store.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .tint(AccessibleStyle.accentBright)
                Text("Processing locally")
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
            } else {
                Text(nextStepText)
                    .font(.callout)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
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

private struct StepConnector: View {
    var body: some View {
        Rectangle()
            .fill(AccessibleStyle.border)
            .frame(width: 18, height: 1)
    }
}

private struct StepPill: View {
    @Environment(DocumentStore.self) private var store
    let number: Int
    let title: String
    let destination: DocumentStore.Destination
    @AppStorage("boostContrast") private var boostContrast = false
    // ScaledMetric keeps the step indicator circle readable when the user
    // increases text size. The base 24 pt is the default at standard sizes.
    @ScaledMetric(relativeTo: .body) private var stepCircleSize: CGFloat = 24

    private var isSelected: Bool {
        (store.selectedDestination ?? .home) == destination
    }

    var body: some View {
        Button {
            store.selectedDestination = destination
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AccessibleStyle.accentGradient)
                        Circle()
                            .fill(AccessibleStyle.accentBright.opacity(0.35))
                            .blur(radius: 6)
                            .scaleEffect(1.25)
                    } else {
                        Circle()
                            .fill(AccessibleStyle.elevatedBackground)
                    }

                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? .white : AccessibleStyle.secondaryText)
                }
                .frame(width: stepCircleSize, height: stepCircleSize)
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.clear : AccessibleStyle.border)
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? AccessibleStyle.primaryText : AccessibleStyle.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(number), \(title)")
    }
}
