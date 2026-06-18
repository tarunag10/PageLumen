import PageLumenCore
import SwiftUI
import TipKit

struct SummaryExportView: View {
    @Environment(DocumentStore.self) private var store
    @StateObject private var speech = SpeechEngine()
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

                HStack(spacing: 12) {
                    Picker("Length", selection: $store.summaryLength) {
                        ForEach(SummaryLength.allCases) { length in
                            Text(length.rawValue).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        speech.isSpeaking ? speech.stop() : speech.speak(store.document.summary)
                    } label: {
                        Label(speech.isSpeaking ? "Stop" : "Play", systemImage: speech.isSpeaking ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        speech.isSpeaking ? speech.stop() : speech.speak(store.fullExtractedText())
                    } label: {
                        Label("Read Full Text", systemImage: "text.bubble")
                    }

                    Spacer()

                    Button {
                        store.selectedDestination = .review
                    } label: {
                        Label("Back to Review", systemImage: "arrow.left")
                    }
                }

                Text(store.document.summary)
                    .font(.title3)
                    .foregroundStyle(AccessibleStyle.primaryText)
                    .lineSpacing(4)
                    .textSelection(.enabled)
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
                        }
                    }
                    .tint(AccessibleStyle.accent)

                    Text("Tagged HTML and Accessibility Report are the review-ready accessibility outputs. Accessible PDF is readable/selectable text, not full PDF/UA validation yet.")
                        .font(.callout)
                        .foregroundStyle(AccessibleStyle.secondaryText)
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
    }

    private func findingTitle(_ finding: AccessibilityFinding) -> String {
        let page = finding.pageNumber.map { "Page \($0): " } ?? ""
        return "\(finding.severity.rawValue) - \(page)\(finding.message)"
    }
}
