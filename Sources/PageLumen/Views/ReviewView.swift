import PageLumenCore
import SwiftUI
import TipKit
import UniformTypeIdentifiers

struct ReviewView: View {
    @Environment(DocumentStore.self) private var store
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
    @Environment(DocumentStore.self) private var store
    // Re-render when the high-contrast toggle changes so AccessibleStyle tokens
    // (border, warning, panelBackground) pick up the new value.
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        if store.isProcessing || store.document.pages.contains(where: { $0.warning != nil }) {
            HStack(spacing: 10) {
                Image(systemName: store.isProcessing ? "hourglass" : "exclamationmark.triangle")
                    .foregroundStyle(store.isProcessing ? Color.primary : AccessibleStyle.warning)
                Text(store.isProcessing ? "Processing locally..." : "Some OCR or reading-order confidence is low. Review before export.")
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibleToolbarSurface()
        }
    }
}

private struct ReviewHeader: View {
    @Environment(DocumentStore.self) private var store
    @Binding var showReadingOrder: Bool
    @State private var showConfidenceChart = false

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step 3: Review text")
                        .font(.headline)
                    Text("Compare the preview with extracted blocks, then resolve anything marked for review.")
                        .font(.caption)
                        .foregroundStyle(.primary)
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

                Button {
                    showConfidenceChart = true
                } label: {
                    Label("Confidence", systemImage: "chart.bar.doc.horizontal")
                }
                .popover(isPresented: $showConfidenceChart) {
                    ConfidenceChartView(document: store.document)
                        .frame(minWidth: 400, minHeight: 300)
                }

                if let page = store.selectedPage {
                    Text(page.layoutType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.primary)
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
                    .foregroundStyle(.primary)
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
    @Environment(DocumentStore.self) private var store
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        HStack(spacing: 12) {
            TrustMetric(
                title: "Extraction",
                value: store.extractionReadinessLabel,
                systemImage: store.reviewIssueCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tint: store.reviewIssueCount == 0 ? AccessibleStyle.success : AccessibleStyle.warning
            )

            TrustMetric(
                title: "Pages",
                value: "\(store.document.pageCount)",
                systemImage: "doc.richtext",
                tint: AccessibleStyle.selected
            )

            TrustMetric(
                title: "Reviewed",
                value: "\(Int(store.reviewProgress.fractionComplete * 100))%",
                systemImage: "checklist.checked",
                tint: store.reviewProgress.fractionComplete >= 1 ? AccessibleStyle.success : AccessibleStyle.selected
            )

            Spacer()

            Menu {
                if store.reviewIssues.isEmpty {
                    Text("No review issues")
                } else {
                    ForEach(store.reviewIssues.prefix(12)) { issue in
                        Button {
                            store.jumpToIssue(issue)
                        } label: {
                            Text("Page \(issue.pageNumber): \(issue.title)")
                        }
                    }
                }
            } label: {
                Label("Issue Navigator", systemImage: "list.bullet.rectangle")
            }

            Button {
                store.jumpToFirstReviewIssue()
            } label: {
                Label("Review Issues", systemImage: "scope")
            }
            .popoverTip(ReviewIssueTip(), arrowEdge: .top)
            .disabled(store.reviewIssueCount == 0)

            Button {
                store.setSelectedPageReviewed(true)
            } label: {
                Label("Mark Page Reviewed", systemImage: "checkmark.circle")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibleToolbarSurface()
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
                    .foregroundStyle(.primary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .accessiblePanel()
        .accessibilityElement(children: .combine)
    }
}

private struct StructuredOutputView: View {
    @Environment(DocumentStore.self) private var store
    @AppStorage("boostContrast") private var boostContrast = false

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
                            EditableGeneratedNote(
                                title: "Table explanation",
                                text: table.explanation,
                                systemImage: "tablecells"
                            ) { newValue in
                                store.updateTableExplanation(table, text: newValue)
                            }
                        }

                        ForEach(page.figures) { figure in
                            EditableGeneratedNote(
                                title: "Figure explanation",
                                text: figure.description,
                                systemImage: "chart.bar"
                            ) { newValue in
                                store.updateFigureDescription(figure, text: newValue)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct EditableBlockRow: View {
    @Environment(DocumentStore.self) private var store
    let block: TextBlock
    @State private var draft: String = ""
    @State private var commitTask: Task<Void, Never>?
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Block type", selection: blockTypeBinding) {
                    ForEach(editableBlockTypes, id: \.self) { type in
                        Label(type.rawValue.capitalized, systemImage: iconName(for: type))
                            .tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

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
                if block.confidence < 0.7 {
                    Label("Needs review", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AccessibleStyle.warning)
                }
                Toggle("Reviewed", isOn: reviewedBinding)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Text("\(Int(block.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }

            TextEditor(text: $draft)
                .font(block.type == .heading ? .title3.weight(.semibold) : .body)
                .frame(minHeight: block.type == .paragraph ? 74 : 44)
                .accessibilityValue(block.text)
                .onAppear { draft = block.text }
                .onChange(of: block.id) { _, _ in
                    draft = block.text
                }
                .onChange(of: draft) { _, newValue in
                    scheduleCommit(newValue)
                }
        }
        .padding(12)
        .accessiblePanel(borderColor: block.confidence < 0.7 ? AccessibleStyle.warning : AccessibleStyle.border)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.type.rawValue.capitalized) block, confidence \(Int(block.confidence * 100)) percent")
        .accessibilityHint("Edit text, change type, drag to reorder, or use the arrow buttons as a keyboard fallback.")
        .onDrag {
            NSItemProvider(object: block.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: BlockReorderDropDelegate(targetBlock: block, store: store))
        .onDisappear {
            flushPendingCommit()
        }
    }

    // Debounce: writing on every keystroke re-derives the page filter and re-runs the summary
    // on the main actor, which is wasteful for fast typists. Wait 250 ms after the last edit.
    private func scheduleCommit(_ newValue: String) {
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            if Task.isCancelled { return }
            store.updateBlock(block, text: newValue)
        }
    }

    private func flushPendingCommit() {
        commitTask?.cancel()
        commitTask = nil
        if draft != block.text {
            store.updateBlock(block, text: draft)
        }
    }

    private var blockTypeBinding: Binding<BlockType> {
        Binding {
            block.type
        } set: { newValue in
            store.changeBlockType(block, to: newValue)
        }
    }

    private var reviewedBinding: Binding<Bool> {
        Binding {
            DocumentEditing.isReviewed(block)
        } set: { newValue in
            store.setBlockReviewed(block, isReviewed: newValue)
        }
    }

    private var editableBlockTypes: [BlockType] {
        [.heading, .paragraph, .list, .table, .figure, .caption, .header, .footer, .unknown]
    }

    private func iconName(for type: BlockType) -> String {
        switch type {
        case .heading: return "textformat.size"
        case .table: return "tablecells"
        case .figure: return "chart.bar"
        case .header: return "rectangle.topthird.inset.filled"
        case .footer: return "rectangle.bottomthird.inset.filled"
        default: return "text.alignleft"
        }
    }
}

private struct EditableGeneratedNote: View {
    let title: String
    let text: String
    let systemImage: String
    let onChange: (String) -> Void
    @State private var draft = ""
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            TextEditor(text: $draft)
                .font(.body)
                .frame(minHeight: 72)
                .onAppear { draft = text }
                .onChange(of: text) { _, newValue in
                    draft = newValue
                }
                .onChange(of: draft) { _, newValue in
                    onChange(newValue)
                }
        }
        .padding(12)
        .accessiblePanel(borderColor: AccessibleStyle.selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint("Edit the generated description before export.")
    }
}

private struct BlockReorderDropDelegate: DropDelegate {
    let targetBlock: TextBlock
    let store: DocumentStore

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else {
            return false
        }
        let targetID = targetBlock.id
        let pageNumber = targetBlock.pageNumber
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let raw = item as? String,
                  let droppedID = UUID(uuidString: raw),
                  droppedID != targetID else {
                return
            }
            Task { @MainActor in
                guard let page = store.document.pages.first(where: { $0.pageNumber == pageNumber }),
                      let destinationIndex = page.blocks.firstIndex(where: { $0.id == targetID }) else {
                    return
                }
                store.reorderBlock(id: droppedID, to: destinationIndex)
            }
        }
        return true
    }
}
