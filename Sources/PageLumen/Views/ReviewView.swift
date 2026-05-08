import PageLumenCore
import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var showReadingOrder = true

    var body: some View {
        VStack(spacing: 0) {
            ProcessingBanner()
            ReviewTrustBar()

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step 3: Review text")
                        .font(.headline)
                    Text("Compare the preview with extracted blocks, then resolve anything marked for review.")
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

            HStack(spacing: 10) {
                TextField("Search extracted text", text: $store.reviewSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
                    .onSubmit {
                        store.jumpToNextSearchMatch()
                    }

                Button {
                    store.jumpToNextSearchMatch()
                } label: {
                    Label("Next Match", systemImage: "arrow.down.doc")
                }
                .disabled(store.reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Picker("Filter", selection: $store.reviewFilter) {
                    ForEach(DocumentStore.ReviewFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 420)

                Spacer()

                Text(searchSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var searchSummary: String {
        let query = store.reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return "\(store.reviewSearchMatchCount) match\(store.reviewSearchMatchCount == 1 ? "" : "es")"
        }
        return "\(store.filteredSelectedPageBlocks.count) block\(store.filteredSelectedPageBlocks.count == 1 ? "" : "s") shown"
    }
}

private struct ReviewTrustBar: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        HStack(spacing: 12) {
            TrustMetric(
                title: "Extraction",
                value: store.extractionReadinessLabel,
                systemImage: store.reviewIssueCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tint: store.reviewIssueCount == 0 ? .green : .orange
            )

            TrustMetric(
                title: "Pages",
                value: "\(store.document.pageCount)",
                systemImage: "doc.richtext",
                tint: .accentColor
            )

            TrustMetric(
                title: "Low confidence",
                value: "\(store.lowConfidenceBlocks.count)",
                systemImage: "text.badge.exclamationmark",
                tint: store.lowConfidenceBlocks.isEmpty ? .secondary : .orange
            )

            Spacer()

            Button {
                store.jumpToFirstReviewIssue()
            } label: {
                Label("Review Issues", systemImage: "scope")
            }
            .disabled(store.reviewIssueCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}

private struct TrustMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private struct StructuredOutputView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let page = store.selectedPage {
                    if store.filteredSelectedPageBlocks.isEmpty {
                        ContentUnavailableView {
                            Label("No Blocks Match", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text("Clear search or switch filters to see more extracted text.")
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    }

                    ForEach(store.filteredSelectedPageBlocks) { block in
                        EditableBlockRow(block: block)
                    }

                    if store.reviewFilter == .all || store.reviewFilter == .tablesFigures {
                        ForEach(page.tables) { table in
                            GeneratedNote(title: "Table explanation", text: table.explanation, systemImage: "tablecells")
                        }

                        ForEach(page.figures) { figure in
                            GeneratedNote(title: "Figure explanation", text: figure.description, systemImage: "chart.bar")
                        }
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
                .onChange(of: block.id) { _, _ in
                    draft = block.text
                }
                .onChange(of: draft) { _, newValue in
                    store.updateBlock(block, text: newValue)
                }
        }
        .padding(12)
        .background(block.confidence < 0.7 ? Color.orange.opacity(0.08) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(block.confidence < 0.7 ? Color.orange.opacity(0.42) : Color.secondary.opacity(0.12))
        }
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
