import PageLumenCore
import SwiftUI

struct SummaryExportView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var speech = SpeechEngine()

    private var accessibilityAudit: AccessibilityAudit {
        AccessibilityAuditor().audit(document: store.document, options: store.exportOptions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step 4")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Listen and export")
                        .font(.largeTitle.bold())
                    Text("Use the summary for a quick pass, read the full extraction aloud, then save the format you need.")
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 12) {
                    Picker("Length", selection: $store.summaryLength) {
                        ForEach(SummaryLength.allCases) { length in
                            Text(length.rawValue).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.summaryLength) { _, _ in
                        store.regenerateSummary()
                    }

                    Button {
                        speech.isSpeaking ? speech.stop() : speech.speak(store.document.summary)
                    } label: {
                        Label(speech.isSpeaking ? "Stop" : "Play", systemImage: speech.isSpeaking ? "stop.fill" : "play.fill")
                    }

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
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessiblePanel()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(
                            accessibilityAudit.isReadyForTaggedExport ? "Accessibility check ready" : "Accessibility check needs review",
                            systemImage: accessibilityAudit.isReadyForTaggedExport ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.title2.bold())

                        Spacer()

                        Text(accessibilityAudit.summary)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }

                    if accessibilityAudit.findings.isEmpty {
                        Text("No automated accessibility issues were found for the current export options.")
                            .foregroundStyle(.primary)
                    } else {
                        ForEach(accessibilityAudit.findings.prefix(5)) { finding in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(findingTitle(finding))
                                    .font(.headline)
                                Text(finding.recommendation)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessiblePanel()
                        }

                        if accessibilityAudit.findings.count > 5 {
                            Text("\(accessibilityAudit.findings.count - 5) more items are included in the Accessibility Report export.")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding()
                .accessiblePanel()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose what to include")
                        .font(.title2.bold())

                    Toggle("Include headings", isOn: $store.exportOptions.includeHeadings)
                    Toggle("Include tables", isOn: $store.exportOptions.includeTables)
                    Toggle("Include chart and figure explanations", isOn: $store.exportOptions.includeFigures)
                    Toggle("Include page references", isOn: $store.exportOptions.includePageReferences)
                    Toggle("Include confidence notes", isOn: $store.exportOptions.includeConfidenceNotes)
                    Toggle("Include repeated headers and footers", isOn: $store.exportOptions.includeHeadersAndFooters)

                    Divider()

                    Text("Save as")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(ExportFormat.allCases) { format in
                            Button {
                                store.export(format: format)
                            } label: {
                                Text(format.rawValue)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    Text("Tagged HTML and Accessibility Report are the review-ready accessibility outputs. Accessible PDF is readable/selectable text, not full PDF/UA validation yet.")
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
                .padding()
                .accessiblePanel()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Export preview", systemImage: "doc.text.magnifyingglass")
                            .font(.title2.bold())

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
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(minHeight: 220, maxHeight: 320)
                    .accessiblePanel()

                    Text("Preview is capped for speed. The saved export includes the full selected document.")
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
                .padding()
                .accessiblePanel()
            }
            .padding(32)
        }
    }

    private func findingTitle(_ finding: AccessibilityFinding) -> String {
        let page = finding.pageNumber.map { "Page \($0): " } ?? ""
        return "\(finding.severity.rawValue) - \(page)\(finding.message)"
    }
}
