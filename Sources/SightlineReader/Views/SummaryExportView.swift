import SightlineCore
import SwiftUI

struct SummaryExportView: View {
    @EnvironmentObject private var store: DocumentStore
    @StateObject private var speech = SpeechEngine()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.largeTitle.bold())
                    Text("Generated from extracted text only. Review low-confidence pages before sharing.")
                        .foregroundStyle(.secondary)
                }

                HStack {
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
                }

                Text(store.document.summary)
                    .font(.title3)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Export")
                        .font(.title2.bold())

                    Toggle("Include headings", isOn: $store.exportOptions.includeHeadings)
                    Toggle("Include tables", isOn: $store.exportOptions.includeTables)
                    Toggle("Include chart and figure explanations", isOn: $store.exportOptions.includeFigures)
                    Toggle("Include page references", isOn: $store.exportOptions.includePageReferences)
                    Toggle("Include confidence notes", isOn: $store.exportOptions.includeConfidenceNotes)
                    Toggle("Include repeated headers and footers", isOn: $store.exportOptions.includeHeadersAndFooters)

                    HStack {
                        ForEach(ExportFormat.allCases) { format in
                            Button(format.rawValue) {
                                store.export(format: format)
                            }
                        }
                    }

                    Text("Accessible PDF export is a basic structured text export. CSV exports detected table cells, and JSON exports OCR blocks and metadata.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(32)
        }
    }
}
