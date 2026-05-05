import PageLumenCore
import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var showReadingOrder = true

    var body: some View {
        VStack(spacing: 0) {
            ProcessingBanner()

            HSplitView {
                PreviewPane(page: store.selectedPage, showReadingOrder: showReadingOrder)
                    .frame(minWidth: 420)

                VStack(spacing: 0) {
                    ReviewHeader(showReadingOrder: $showReadingOrder)
                    Divider()
                    StructuredOutputView()
                }
                .frame(minWidth: 460)
            }
        }
    }
}

private struct ProcessingBanner: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        if store.isProcessing || store.document.pages.contains(where: { $0.warning != nil }) {
            HStack(spacing: 10) {
                Image(systemName: store.isProcessing ? "hourglass" : "exclamationmark.triangle")
                    .foregroundStyle(store.isProcessing ? Color.secondary : Color.orange)
                Text(store.isProcessing ? "Processing locally..." : "Some OCR or reading-order confidence is low. Review before export.")
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

private struct ReviewHeader: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var showReadingOrder: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Step 2: Review text")
                    .font(.headline)
                Text("Compare the preview with the extracted blocks. Edit anything that looks wrong.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Page", selection: $store.selectedPageNumber) {
                ForEach(store.document.pages) { page in
                    Text("Page \(page.pageNumber)").tag(page.pageNumber)
                }
            }
            .frame(width: 150)

            Toggle("Show order", isOn: $showReadingOrder)
                .toggleStyle(.switch)

            if let page = store.selectedPage {
                Text(page.layoutType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.selectedDestination = .summaryExport
            } label: {
                Label("Continue", systemImage: "arrow.right")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }
}

private struct StructuredOutputView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let page = store.selectedPage {
                    ForEach(page.blocks) { block in
                        EditableBlockRow(block: block)
                    }

                    ForEach(page.tables) { table in
                        GeneratedNote(title: "Table explanation", text: table.explanation, systemImage: "tablecells")
                    }

                    ForEach(page.figures) { figure in
                        GeneratedNote(title: "Figure explanation", text: figure.description, systemImage: "chart.bar")
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct EditableBlockRow: View {
    @EnvironmentObject private var store: DocumentStore
    let block: TextBlock
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(block.type.rawValue.capitalized, systemImage: iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    store.moveBlock(block, direction: .up)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Move earlier in reading order")

                Button {
                    store.moveBlock(block, direction: .down)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .help("Move later in reading order")

                Spacer()
                Text("\(Int(block.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(block.confidence < 0.7 ? .orange : .secondary)
            }

            TextEditor(text: $draft)
                .font(block.type == .heading ? .title3.weight(.semibold) : .body)
                .frame(minHeight: block.type == .paragraph ? 74 : 44)
                .onAppear { draft = block.text }
                .onChange(of: draft) { _, newValue in
                    store.updateBlock(block, text: newValue)
                }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.type.rawValue), confidence \(Int(block.confidence * 100)) percent")
    }

    private var iconName: String {
        switch block.type {
        case .heading: return "textformat.size"
        case .table: return "tablecells"
        case .figure: return "chart.bar"
        case .header: return "rectangle.topthird.inset.filled"
        case .footer: return "rectangle.bottomthird.inset.filled"
        default: return "text.alignleft"
        }
    }
}

private struct GeneratedNote: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(text)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
