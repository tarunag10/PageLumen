import PageLumenCore
import SwiftUI
import TipKit
import UniformTypeIdentifiers

struct ReviewView: View {
    @Environment(DocumentStore.self) private var store
    @State private var showReadingOrder = true
    @State private var readingPreferences = ReadingPreferences.load()

    var body: some View {
        VStack(spacing: 0) {
            ProcessingBanner()
            ReviewTrustBar()

            HSplitView {
                PreviewPane(page: store.selectedPage, showReadingOrder: showReadingOrder)
                    .frame(minWidth: 420)

                VStack(spacing: 0) {
                    ReviewHeader(showReadingOrder: $showReadingOrder, readingPreferences: $readingPreferences)
                    Divider()
                    StructuredOutputView(readingPreferences: $readingPreferences)
                }
                .frame(minWidth: 460)
            }
        }
        .background(AccessibleStyle.appBackground)
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
                    .foregroundStyle(store.isProcessing ? AccessibleStyle.secondaryText : AccessibleStyle.warning)
                Text(store.isProcessing ? "Processing locally..." : "Some OCR or reading-order confidence is low. Review before export.")
                    .font(.callout)
                    .foregroundStyle(store.isProcessing ? AccessibleStyle.secondaryText : AccessibleStyle.primaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .accessibleToolbarSurface()
        }
    }
}

private struct ReviewHeader: View {
    @Environment(DocumentStore.self) private var store
    @Binding var showReadingOrder: Bool
    @Binding var readingPreferences: ReadingPreferences
    @State private var showConfidenceChart = false
    @State private var showReviewQueue = false
    @State private var showEditHistory = false
    @State private var showDocumentChanges = false

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Step 3: Review text")
                        .font(.headline)
                        .foregroundStyle(AccessibleStyle.primaryText)
                    Text("Compare the preview with extracted blocks, then resolve anything marked for review.")
                        .font(.caption)
                        .foregroundStyle(AccessibleStyle.secondaryText)
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

                ReadingControls(preferences: $readingPreferences)

                Button {
                    store.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!store.canUndo)
                .help("Undo the last text, structure, or review change")

                Button {
                    store.redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!store.canRedo)
                .help("Redo the last undone change")

                Button {
                    showConfidenceChart = true
                } label: {
                    Label("Confidence", systemImage: "chart.bar.doc.horizontal")
                }
                .popover(isPresented: $showConfidenceChart) {
                    ConfidenceChartView(document: store.document)
                        .frame(minWidth: 400, minHeight: 300)
                }

                Button {
                    showReviewQueue = true
                } label: {
                    Label("Review Queue", systemImage: "list.bullet.clipboard")
                }
                .popover(isPresented: $showReviewQueue, arrowEdge: .top) {
                    ReviewQueuePopover()
                        .frame(width: 360, height: 420)
                }

                Button {
                    showEditHistory = true
                } label: {
                    Label("Edit History", systemImage: "clock.arrow.circlepath")
                }
                .popover(isPresented: $showEditHistory, arrowEdge: .top) {
                    EditHistoryPopover()
                        .frame(width: 360, height: 360)
                }

                Button {
                    showDocumentChanges = true
                } label: {
                    Label("Compare Edits", systemImage: "arrow.left.arrow.right")
                }
                .disabled(store.documentChanges.isEmpty)
                .help("Compare current text with retained original OCR")
                .popover(isPresented: $showDocumentChanges, arrowEdge: .top) {
                    DocumentChangesPopover()
                        .frame(width: 520, height: 440)
                }

                if let page = store.selectedPage {
                    Text(page.layoutType.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AccessibleStyle.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AccessibleStyle.elevatedBackground, in: Capsule())
                }

                Button {
                    store.selectedDestination = .summaryExport
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canNavigate(to: .summaryExport))
                .help(store.isProcessing ? "Finish processing before exporting" : "Open summary and export options")
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

                Button {
                    store.jumpToPreviousSearchMatch()
                } label: {
                    Label("Previous Match", systemImage: "arrow.up.doc")
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
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }
        }
        .padding(14)
    }

    private var searchSummary: String {
        let query = store.reviewSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let count = store.reviewSearchMatchCount
            if let position = store.reviewSearchMatchPosition {
                return "Match \(position) of \(count)"
            }
            return "\(count) match\(count == 1 ? "" : "es")"
        }
        return "\(store.filteredSelectedPageBlocks.count) block\(store.filteredSelectedPageBlocks.count == 1 ? "" : "s") shown"
    }
}

private struct ReadingControls: View {
    @Binding var preferences: ReadingPreferences

    var body: some View {
        Menu {
            Toggle("Focus selected block", isOn: $preferences.focusMode)
            Picker("Typography", selection: $preferences.typography) {
                ForEach(ReadingPreferences.Typography.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            Picker("Line spacing", selection: lineSpacingBinding) {
                Text("Compact").tag(0.0)
                Text("Comfortable").tag(4.0)
                Text("Spacious").tag(10.0)
                Text("Extra spacious").tag(16.0)
            }
            Picker("Speech speed", selection: speechRateBinding) {
                Text("0.75×").tag(0.75)
                Text("1×").tag(1.0)
                Text("1.25×").tag(1.25)
                Text("1.5×").tag(1.5)
            }
        } label: {
            Label("Reading", systemImage: "textformat.size")
        }
        .help("Adjust focus, typography, spacing, and speech speed")
        .onChange(of: preferences) { _, newValue in
            let normalized = newValue.normalized
            if normalized != newValue { preferences = normalized }
            normalized.persist()
        }
    }

    private var lineSpacingBinding: Binding<Double> {
        Binding(get: { preferences.lineSpacing }, set: { preferences.lineSpacing = $0 })
    }

    private var speechRateBinding: Binding<Double> {
        Binding(get: { preferences.speechRate }, set: { preferences.speechRate = $0 })
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
                tint: AccessibleStyle.accentBright
            )

            TrustMetric(
                title: "Reviewed",
                value: "\(Int(store.reviewProgress.fractionComplete * 100))%",
                systemImage: "checklist.checked",
                tint: store.reviewProgress.fractionComplete >= 1 ? AccessibleStyle.success : AccessibleStyle.accentBright
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

            Toggle(isOn: Binding(
                get: { store.isSelectedPageReviewed },
                set: { store.setSelectedPageReviewed($0) }
            )) {
                Label("Page Reviewed", systemImage: "checkmark.circle")
            }
            .toggleStyle(.checkbox)
            .help(store.isSelectedPageReviewed ? "Mark this page for review again" : "Mark every block on this page as reviewed")
            .accessibilityHint(store.isSelectedPageReviewed ? "Uncheck to mark this page for review again." : "Check to mark every block on this page as reviewed.")
            .disabled(store.selectedPage == nil || store.selectedPage?.blocks.isEmpty == true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .accessibleToolbarSurface()
    }
}

private struct TrustMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.16))
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AccessibleStyle.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessiblePanel(paddedShadow: false)
        .accessibilityElement(children: .combine)
    }
}

private struct ReviewQueuePopover: View {
    @Environment(DocumentStore.self) private var store
    @State private var filter: QueueFilter = .all

    private enum QueueFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case blockers = "Blockers"
        case warnings = "Warnings"
        var id: String { rawValue }
    }

    private var findings: [ReviewFinding] {
        switch filter {
        case .all: return store.reviewFindings
        case .blockers: return store.reviewFindings.filter { $0.severity == .blocker }
        case .warnings: return store.reviewFindings.filter { $0.severity == .warning }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review queue")
                        .font(.headline)
                    Text("Select an issue to open its source block.")
                        .font(.caption)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                }
                Spacer()
                Text("\(store.reviewIssueCount)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AccessibleStyle.accentBright)
            }

            Picker("Queue filter", selection: $filter) {
                ForEach(QueueFilter.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)

            if findings.isEmpty {
                ContentUnavailableView("Queue is clear", systemImage: "checkmark.circle", description: Text("All current extraction issues are resolved."))
            } else {
                List(findings) { finding in
                    HStack(alignment: .top, spacing: 8) {
                        Button {
                            if let issue = store.reviewIssues.first(where: { $0.id == finding.id }) {
                                store.jumpToIssue(issue)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(finding.title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(AccessibleStyle.primaryText)
                                Text("Page \(finding.pageNumber) · \(finding.severity.rawValue.capitalized) · \(finding.detail)")
                                    .font(.caption)
                                    .foregroundStyle(AccessibleStyle.secondaryText)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Page \(finding.pageNumber), \(finding.title), \(finding.severity.rawValue)")
                        .accessibilityHint("Open this issue in the review editor")

                        if let issue = store.reviewIssues.first(where: { $0.id == finding.id }) {
                            Button {
                                store.markReviewIssueReviewed(issue)
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .help(issue.blockID == nil ? "Correct this page warning after checking the original page" : "Mark finding reviewed")
                            .accessibilityLabel(issue.blockID == nil ? "Correct page warning on page \(issue.pageNumber)" : "Resolve \(finding.title)")
                            if issue.blockID != nil {
                                Button {
                                    store.rejectReviewIssue(issue)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Reject suggestion without changing source text")
                                .accessibilityLabel("Reject \(finding.title)")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .background(AccessibleStyle.appBackground)
    }
}

private struct EditHistoryPopover: View {
    @Environment(DocumentStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit history")
                .font(.headline)
                .foregroundStyle(AccessibleStyle.primaryText)
            Text("The bounded history records reversible review actions. Source text is not duplicated here.")
                .font(.caption)
                .foregroundStyle(AccessibleStyle.secondaryText)

            if store.editHistory.isEmpty {
                ContentUnavailableView("No edits yet", systemImage: "clock", description: Text("Changes will appear here as you review the document."))
            } else {
                List(store.editHistory.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.label)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AccessibleStyle.primaryText)
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(AccessibleStyle.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.label), \(entry.timestamp.formatted(date: .abbreviated, time: .shortened))")
                }
            }
        }
        .padding(16)
        .background(AccessibleStyle.appBackground)
    }
}

private struct DocumentChangesPopover: View {
    @Environment(DocumentStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare edits")
                .font(.headline)
                .foregroundStyle(AccessibleStyle.primaryText)
            Text("Deterministic comparison of current text against retained original OCR. No AI or network processing is used.")
                .font(.caption)
                .foregroundStyle(AccessibleStyle.secondaryText)

            if store.documentChanges.isEmpty {
                ContentUnavailableView("No text changes", systemImage: "checkmark.circle", description: Text("Edited blocks will appear here after a text correction."))
            } else {
                List(store.documentChanges) { change in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(change.kind.label, systemImage: change.kind.systemImage)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(AccessibleStyle.primaryText)
                            Spacer()
                            Text("Page \(change.pageNumber)")
                                .font(.caption)
                                .foregroundStyle(AccessibleStyle.secondaryText)
                        }

                        Text("Original")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AccessibleStyle.secondaryText)
                        Text(change.originalText ?? "(block was added)")
                            .textSelection(.enabled)
                            .foregroundStyle(AccessibleStyle.primaryText)
                        Text("Current")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AccessibleStyle.secondaryText)
                        Text(change.currentText ?? "(block was removed)")
                            .textSelection(.enabled)
                            .foregroundStyle(AccessibleStyle.primaryText)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(change.kind.label), page \(change.pageNumber)")
                    .accessibilityHint("Shows the original and current text for this changed source block.")
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .background(AccessibleStyle.appBackground)
    }
}

private extension DocumentChangeKind {
    var label: String {
        switch self {
        case .added: return "Added block"
        case .removed: return "Removed block"
        case .modified: return "Edited block"
        }
    }

    var systemImage: String {
        switch self {
        case .added: return "plus.circle"
        case .removed: return "minus.circle"
        case .modified: return "pencil.circle"
        }
    }
}

private struct StructuredOutputView: View {
    @Environment(DocumentStore.self) private var store
    @Binding var readingPreferences: ReadingPreferences
    @AppStorage("boostContrast") private var boostContrast = false

    var body: some View {
        ScrollViewReader { reader in
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
                            EditableBlockRow(block: block, readingPreferences: readingPreferences)
                                .id(block.id)
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
                                TableHeaderAssignmentEditor(table: table) { rows, columns in
                                    store.updateTableHeaderAssignments(table, columnHeaderRows: rows, rowHeaderColumns: columns)
                                }
                                TableGridEditor(table: table) { row, column, value in
                                    store.updateTableCell(table, row: row, column: column, text: value)
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
                .padding(22)
            }
            .onChange(of: store.selectedBlockID) { _, blockID in
                guard let blockID else { return }
                reader.scrollTo(blockID, anchor: .center)
            }
        }
        .background(AccessibleStyle.appBackground)
    }
}

private struct EditableBlockRow: View {
    @Environment(DocumentStore.self) private var store
    let block: TextBlock
    let readingPreferences: ReadingPreferences
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

                Button {
                    store.copyAccessibleExcerpt(block)
                } label: {
                    Label("Copy accessible excerpt", systemImage: "quote.closing")
                }
                .buttonStyle(.borderless)
                .help("Copy this block with its page and reading-order citation")
                .accessibilityHint("Copies the block text and a page and block citation to the clipboard.")

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
                    .foregroundStyle(AccessibleStyle.secondaryText)
            }

            TextEditor(text: $draft)
                .font(readingPreferences.typography.font(for: block.type))
                .lineSpacing(CGFloat(readingPreferences.lineSpacing))
                .foregroundStyle(AccessibleStyle.primaryText)
                .frame(minHeight: block.type == .paragraph ? 74 : 44)
                .accessibilityValue(block.text)
                .onAppear { draft = block.text }
                .onChange(of: block.id) { _, _ in
                    draft = block.text
                }
                .onChange(of: draft) { _, newValue in
                    scheduleCommit(newValue)
                }

            if let originalText = block.originalText, block.hasTextEdit {
                DisclosureGroup("Original OCR text") {
                    Text(originalText)
                        .font(.callout)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityHint("Shows the original extracted text without replacing your edited text.")
            }
        }
        .padding(focusHighlightPadding)
        .background(focusHighlightColor, in: RoundedRectangle(cornerRadius: 8))
                        .onTapGesture { _ = store.selectReviewSource(pageNumber: block.pageNumber, blockID: block.id) }
        .padding(14)
        .accessiblePanel(borderColor: block.confidence < 0.7 ? AccessibleStyle.warning : AccessibleStyle.border)
        .overlay {
            if store.selectedBlockID == block.id {
                RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius)
                    .stroke(AccessibleStyle.focusBorder, lineWidth: 2)
            }
        }
        .background {
            if store.selectedBlockID == block.id {
                RoundedRectangle(cornerRadius: AccessibleStyle.cornerRadius)
                    .fill(AccessibleStyle.focusBorder.opacity(0.08))
                    .padding(1)
            }
        }
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

    private var isFocused: Bool {
        readingPreferences.focusMode && store.selectedBlockID == block.id
    }

    private var focusHighlightPadding: CGFloat { isFocused ? 8 : 0 }

    private var focusHighlightColor: Color { isFocused ? AccessibleStyle.accentTint : .clear }

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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(AccessibleStyle.accent.opacity(0.16))
                    Image(systemName: systemImage)
                        .foregroundStyle(AccessibleStyle.accentBright)
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(width: 24, height: 24)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AccessibleStyle.primaryText)
            }
            TextEditor(text: $draft)
                .font(.body)
                .foregroundStyle(AccessibleStyle.primaryText)
                .frame(minHeight: 72)
                .onAppear { draft = text }
                .onChange(of: text) { _, newValue in
                    draft = newValue
                }
                .onChange(of: draft) { _, newValue in
                    onChange(newValue)
                }
        }
        .padding(14)
        .accessiblePanel(borderColor: AccessibleStyle.accent.opacity(0.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint("Edit the generated description before export.")
    }
}

private struct TableHeaderAssignmentEditor: View {
    let table: TableRegion
    let onApply: ([Int], [Int]) -> Void
    @State private var columnRows = ""
    @State private var rowColumns = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Table semantics", systemImage: "tablecells.badge.ellipsis")
                .font(.headline)
                .foregroundStyle(AccessibleStyle.primaryText)
            Text("Assign zero-based row and column indexes so accessible exports can distinguish headers from data.")
                .font(.caption)
                .foregroundStyle(AccessibleStyle.secondaryText)
            HStack {
                TextField("Column header rows (e.g. 0)", text: $columnRows)
                TextField("Row header columns (e.g. 0)", text: $rowColumns)
            }
            .textFieldStyle(.roundedBorder)
            Button("Apply header assignments") {
                onApply(parse(columnRows), parse(rowColumns))
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Applies the selected table header row and column indexes.")
        }
        .padding(14)
        .accessiblePanel(borderColor: AccessibleStyle.accent.opacity(0.35))
        .onAppear { syncFromTable() }
        .onChange(of: table) { _, _ in syncFromTable() }
    }

    private func syncFromTable() {
        columnRows = table.columnHeaderRows.map(String.init).joined(separator: ", ")
        rowColumns = table.rowHeaderColumns.map(String.init).joined(separator: ", ")
    }

    private func parse(_ value: String) -> [Int] {
        value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}

private struct TableGridEditor: View {
    let table: TableRegion
    let onCellChange: (Int, Int, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Table cells", systemImage: "square.grid.3x3")
                .font(.headline)
                .foregroundStyle(AccessibleStyle.primaryText)
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(table.rows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            Text("(rowIndex)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AccessibleStyle.secondaryText)
                                .frame(width: 24)
                            ForEach(table.rows[rowIndex].indices, id: \.self) { columnIndex in
                                TextField(
                                    "r\(rowIndex)c\(columnIndex)",
                                    text: Binding(
                                        get: { table.rows[rowIndex][columnIndex] },
                                        set: { onCellChange(rowIndex, columnIndex, $0) }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 120)
                                .accessibilityLabel("Row \(rowIndex), column \(columnIndex)")
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .accessiblePanel(borderColor: AccessibleStyle.accent.opacity(0.35))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editable table grid")
        .accessibilityHint("Edit individual table cells. Header semantics are assigned separately above.")
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
