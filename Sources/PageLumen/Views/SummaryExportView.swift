import PageLumenCore
import SwiftUI
import TipKit

struct SummaryExportView: View {
    @Environment(DocumentStore.self) private var store
    @StateObject private var speech = SpeechEngine()
    @State private var isShowingStirlingConfirmation = false
    @State private var isShowingStirlingMergeConfirmation = false
    // Re-render when the high-contrast toggle changes so AccessibleStyle tokens
    // (border, elevatedBackground) pick up the new value.
    @AppStorage("boostContrast") private var boostContrast = false

    private var accessibilityAudit: AccessibilityAudit {
        AccessibilityAuditor().audit(document: store.document, options: store.exportOptions)
    }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("STEP 4")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AccessibleStyle.accentBright)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AccessibleStyle.accentTint, in: Capsule())

                    Text("Listen and export")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AccessibleStyle.primaryText)

                    Text("Use the summary for a quick pass, read the full extraction aloud, then save the format you need.")
                        .font(.title3)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Picker("Length", selection: $store.summaryLength) {
                        ForEach(SummaryLength.allCases) { length in
                            Text(length.rawValue).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.summaryLength) { _, _ in
                        speech.stop()
                        store.regenerateSummary()
                    }

                    Button {
                        speech.isSpeaking ? speech.stop() : speech.speak(store.document.summary)
                    } label: {
                        Label(speech.isSpeaking ? "Stop" : "Play", systemImage: speech.isSpeaking ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("export.playSummary")

                    Button {
                        speech.isSpeaking ? speech.stop() : speech.speak(store.fullExtractedText())
                    } label: {
                        Label(
                            speech.isSpeaking ? "Stop" : "Read Full Text",
                            systemImage: speech.isSpeaking ? "stop.fill" : "text.bubble"
                        )
                    }
                    .accessibilityIdentifier("export.readFullText")
                    .help(speech.isSpeaking ? "Stop reading aloud" : "Read the full extracted text aloud")

                    Button {
                        store.copySummaryWithCitations()
                    } label: {
                        Label("Copy with Citations", systemImage: "quote.opening")
                    }
                    .accessibilityIdentifier("export.copyCitations")
                    .help("Copy a generated draft labelled with page and block citations")

                    Button {
                        store.prepareReviewDraft()
                    } label: {
                        Label("Prepare Draft", systemImage: "wand.and.stars")
                    }
                    .accessibilityIdentifier("export.prepareDraft")
                    .help("Prepare a cited draft for explicit review before applying it")

                    Spacer()

                    Button {
                        store.selectedDestination = .review
                    } label: {
                        Label("Back to Review", systemImage: "arrow.left")
                    }
                    .accessibilityIdentifier("export.backToReview")
                }
                .padding(.vertical, 2)
                }

                if !store.statusMessage.isEmpty, store.statusMessage != "Ready" {
                    Label(store.statusMessage, systemImage: statusSymbol)
                        .font(.callout)
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(statusTint.opacity(0.12), in: RoundedRectangle(cornerRadius: AccessibleStyle.innerCornerRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: AccessibleStyle.innerCornerRadius)
                                .stroke(statusTint.opacity(0.45))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("export.status")
                }

                if store.isStirlingOperationInFlight {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Stirling-PDF is processing the separate output copy.")
                            .font(.callout)
                            .foregroundStyle(AccessibleStyle.secondaryText)
                        Spacer()
                        Button("Cancel") {
                            store.cancelStirlingOperation()
                        }
                        .accessibilityIdentifier("export.stirlingCancel")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .accessiblePanel(paddedShadow: false)
                    .accessibilityElement(children: .contain)
                }

                if let draft = store.reviewDraft {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Review draft — source unchanged", systemImage: "checkmark.shield")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AccessibleStyle.primaryText)
                        Text(draft.text)
                            .foregroundStyle(AccessibleStyle.primaryText)
                            .textSelection(.enabled)
                        if let warning = draft.groundingWarning {
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(AccessibleStyle.warning)
                        }
                        HStack {
                            Button("Insert as Summary") { store.insertReviewDraftAsSummary() }
                            Button("Replace Selected Description") { store.replaceSelectedDescriptionAfterReview() }
                                .disabled(store.selectedBlockID == nil)
                            Button("Discard", role: .destructive) { store.discardReviewDraft() }
                        }
                    }
                    .padding(20)
                    .accessiblePanel()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        store.document.metadata["intelligenceSource"] == nil
                            ? "Summary — not source text"
                            : "Generated summary — not source text",
                        systemImage: "sparkles"
                    )
                    .font(.headline)
                    .foregroundStyle(AccessibleStyle.secondaryText)
                    .accessibilityHint("This is a derived summary. The extracted document text remains the source of record.")

                    Text(store.document.summary)
                        .font(.title3)
                        .foregroundStyle(AccessibleStyle.primaryText)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessiblePanel()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(
                            accessibilityAudit.isReadyForTaggedExport ? "Accessibility check ready" : "Accessibility check needs review",
                            systemImage: accessibilityAudit.isReadyForTaggedExport ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AccessibleStyle.primaryText)

                        Spacer()

                        Text(accessibilityAudit.summary)
                            .font(.callout)
                            .foregroundStyle(AccessibleStyle.secondaryText)
                    }

                    Text(accessibilityAudit.unresolvedRiskSummary)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(accessibilityAudit.blockerCount > 0 ? AccessibleStyle.warning : AccessibleStyle.secondaryText)

                    if accessibilityAudit.findings.isEmpty {
                        Text("No automated accessibility issues were found for the current export options.")
                            .font(.callout)
                            .foregroundStyle(AccessibleStyle.secondaryText)
                    } else {
                        ForEach(accessibilityAudit.findings.prefix(5)) { finding in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(findingTitle(finding))
                                    .font(.headline)
                                    .foregroundStyle(AccessibleStyle.primaryText)
                                Text(finding.recommendation)
                                    .font(.callout)
                                    .foregroundStyle(AccessibleStyle.secondaryText)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessiblePanel(paddedShadow: false)
                        }

                        if accessibilityAudit.findings.count > 5 {
                            Text("\(accessibilityAudit.findings.count - 5) more items are included in the Accessibility Report export.")
                                .font(.callout)
                                .foregroundStyle(AccessibleStyle.secondaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Remediation checklist")
                            .font(.headline)
                        ForEach(Array(accessibilityAudit.remediationChecklist.enumerated()), id: \.offset) { _, action in
                            Label(action, systemImage: "circle")
                                .font(.callout)
                                .foregroundStyle(AccessibleStyle.secondaryText)
                        }
                    }
                    .accessibilityElement(children: .contain)

                    Text(accessibilityAudit.manualReviewNotice)
                        .font(.footnote)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .accessiblePanel()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose what to include")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AccessibleStyle.primaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include headings", isOn: $store.exportOptions.includeHeadings)
                        Toggle("Include tables", isOn: $store.exportOptions.includeTables)
                        Toggle("Include chart and figure explanations", isOn: $store.exportOptions.includeFigures)
                        Toggle("Include page references", isOn: $store.exportOptions.includePageReferences)
                        Toggle("Include confidence notes", isOn: $store.exportOptions.includeConfidenceNotes)
                        Toggle("Include repeated headers and footers", isOn: $store.exportOptions.includeHeadersAndFooters)
                        Toggle("Include provenance and review details", isOn: $store.exportOptions.includeProvenance)
                    }
                    .tint(AccessibleStyle.accent)

                    Divider().overlay(AccessibleStyle.border)

                    Text("Save as")
                        .font(.headline)
                        .foregroundStyle(AccessibleStyle.primaryText)

                    TipView(ExportAccessibilityTip())

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(ExportFormat.allCases) { format in
                            Button {
                                store.export(format: format)
                            } label: {
                                Text(format.rawValue)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(AccessibleStyle.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!store.canExport(format))
                            .accessibilityIdentifier("export.\(format.rawValue)")
                            .help(store.exportAvailabilityMessage(for: format))
                        }
                    }
                    .tint(AccessibleStyle.accent)

                    Text("Tagged HTML and Accessibility Report are the review-ready accessibility outputs. Readable PDF is selectable text, not full PDF/UA validation yet.")
                        .font(.callout)
                        .foregroundStyle(AccessibleStyle.secondaryText)

                    if store.canUseStirlingCompression {
                        Button {
                            isShowingStirlingConfirmation = true
                        } label: {
                            Label("Compress a PDF copy with Stirling-PDF", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("export.stirlingCompress")
                        .help(store.stirlingCompressionAvailabilityMessage)
                        .confirmationDialog(
                            "Send a generated PDF copy to Stirling-PDF?",
                            isPresented: $isShowingStirlingConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Compress and Save Copy") {
                                store.compressReadablePDFWithStirling(confirmed: true)
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("The configured Stirling-PDF service will receive the generated PDF. PageLumen will save a separate compressed copy and will not replace the original.")
                        }

                        Button {
                            isShowingStirlingMergeConfirmation = true
                        } label: {
                            Label("Merge PDFs with Stirling-PDF", systemImage: "square.stack.3d.up")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("export.stirlingMerge")
                        .help("Choose PDFs to append after the current document, then save a separate merged copy")
                        .confirmationDialog(
                            "Merge PDFs through Stirling-PDF?",
                            isPresented: $isShowingStirlingMergeConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Choose PDFs and Merge") {
                                store.mergeReadablePDFWithStirling(confirmed: true)
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("The current generated PDF and the PDFs you choose will be sent to the configured Stirling-PDF service. PageLumen will save a separate merged copy and will not replace any source file.")
                        }
                    } else {
                        Text(store.stirlingCompressionAvailabilityMessage)
                            .font(.caption)
                            .foregroundStyle(AccessibleStyle.secondaryText)
                            .accessibilityIdentifier("export.stirlingAvailability")
                    }
                }
                .padding(20)
                .accessiblePanel()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Export preview", systemImage: "doc.text.magnifyingglass")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AccessibleStyle.primaryText)

                        Spacer()

                        Picker("Preview format", selection: $store.exportPreviewFormat) {
                            ForEach(ExportFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .frame(width: 220)
                    }

                    ScrollView {
                        Text(store.exportPreviewText())
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(AccessibleStyle.primaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .frame(minHeight: 220, maxHeight: 320)
                    .background(AccessibleStyle.elevatedBackground, in: RoundedRectangle(cornerRadius: AccessibleStyle.innerCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: AccessibleStyle.innerCornerRadius)
                            .stroke(AccessibleStyle.border)
                    }

                    Text("Preview is capped for speed. The saved export includes the full selected document.")
                        .font(.callout)
                        .foregroundStyle(AccessibleStyle.secondaryText)
                }
                .padding(20)
                .accessiblePanel()
            }
            .padding(36)
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity)
        }
        .background(AccessibleStyle.appBackground)
        .onDisappear {
            speech.stop()
        }
    }

    private func findingTitle(_ finding: AccessibilityFinding) -> String {
        let page = finding.pageNumber.map { "Page \($0): " } ?? ""
        return "\(finding.severity.rawValue) - \(page)\(finding.message)"
    }

    private var statusSymbol: String {
        store.statusMessage.localizedCaseInsensitiveContains("failed") || store.statusMessage.localizedCaseInsensitiveContains("error")
            ? "exclamationmark.triangle.fill"
            : "checkmark.circle.fill"
    }

    private var statusTint: Color {
        statusSymbol == "exclamationmark.triangle.fill" ? AccessibleStyle.warning : AccessibleStyle.success
    }
}
