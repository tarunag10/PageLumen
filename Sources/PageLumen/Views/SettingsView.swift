import PageLumenCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DocumentStore
    @AppStorage("privacyMode") private var privacyMode = true
    @AppStorage("ocrProfile") private var ocrProfile = "General"
    @AppStorage("languageHint") private var languageHint = "Automatic"
    @AppStorage("boostContrast") private var boostContrast = false
    @State private var isShowingForgetConfirmation = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("PageLumen Preferences", systemImage: "slider.horizontal.3")
                        .font(.title2.weight(.semibold))
                    Text("Tune recognition, export defaults, and release-readiness checks for the current native workflow.")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section("Privacy") {
                Toggle("Privacy mode", isOn: $privacyMode)
                Text("Privacy mode keeps the MVP workflow local and disables future network-assisted processing by default.")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

            Section("Library") {
                Button(role: .destructive) {
                    isShowingForgetConfirmation = true
                } label: {
                    Label("Forget all recent documents", systemImage: "trash")
                }
                .disabled(store.recentDocuments.isEmpty)
                .confirmationDialog(
                    "Forget all recent documents? This cannot be undone.",
                    isPresented: $isShowingForgetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Forget all", role: .destructive) {
                        store.forgetAllRecentDocuments()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("PageLumen will clear \(store.recentDocuments.count) document\(store.recentDocuments.count == 1 ? "" : "s") from this Mac's local library. Imported files on disk are not deleted.")
                }
                Text("Recent documents are stored only in this Mac's memory. Use Forget all to clear them when sharing the device.")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

            Section("Display") {
                Toggle("Boost contrast", isOn: $boostContrast)
                    .onChange(of: boostContrast) { _, newValue in
                        AccessibleStyle.boostContrast = newValue
                    }
                Text("Boosts border and panel contrast for low-vision users.")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

            Section("Recognition") {
                Picker("OCR profile", selection: $ocrProfile) {
                    ForEach(OCRProfile.allCases) { profile in
                        Text(profile.rawValue).tag(profile.rawValue)
                    }
                }
                .onChange(of: ocrProfile) { _, newValue in
                    store.statusMessage = "Recognition profile set to \(newValue)"
                }

                Picker("Language hint", selection: $languageHint) {
                    Text("Automatic").tag("Automatic")
                    Text("English").tag("English")
                    Text("Hindi").tag("Hindi")
                    Text("Spanish").tag("Spanish")
                    Text("French").tag("French")
                }
                .onChange(of: languageHint) { _, _ in
                    store.applyLanguagePreference()
                    store.statusMessage = languageHint == "Automatic" ? "Language detection set to automatic" : "Language hint set to \(languageHint)"
                }
            }

            Section("Export Defaults") {
                Toggle("Include headings", isOn: exportBinding(\.includeHeadings))
                Toggle("Include tables", isOn: exportBinding(\.includeTables))
                Toggle("Include chart and figure explanations", isOn: exportBinding(\.includeFigures))
                Toggle("Include page references", isOn: exportBinding(\.includePageReferences))
                Toggle("Include confidence notes", isOn: exportBinding(\.includeConfidenceNotes))
                Toggle("Include repeated headers and footers", isOn: exportBinding(\.includeHeadersAndFooters))

                Text("These defaults are used by the export screen and saved for future sessions.")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }

            Section("Review Status") {
                HStack {
                    Label(store.extractionReadinessLabel, systemImage: store.reviewIssueCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    Spacer()
                    Text("\(store.document.pageCount) page\(store.document.pageCount == 1 ? "" : "s")")
                        .foregroundStyle(.primary)
                }

                if store.reviewIssueCount > 0 {
                    Button {
                        store.jumpToFirstReviewIssue()
                    } label: {
                        Label("Jump to first review item", systemImage: "scope")
                    }
                }
            }

            Section("PRD Coverage") {
                Text("Implemented locally: PDF/image import, paste image, batch import, screenshot capture, OCR, reading order, outline, editing, header/footer filtering, summaries, speech playback, Markdown/TXT/HTML/PDF/CSV/JSON exports, and privacy/profile settings.")
                    .font(.callout)
                    .foregroundStyle(.primary)

                Text("Longer-term roadmap: scanner/browser imports, trained layout models, full PDF/UA validation, advanced chart data extraction, audio-file export, EPUB/LMS/integration exports, and enterprise administration.")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
        .padding(24)
        .frame(width: 580)
    }

    private func exportBinding(_ keyPath: WritableKeyPath<ExportOptions, Bool>) -> Binding<Bool> {
        Binding {
            store.exportOptions[keyPath: keyPath]
        } set: { newValue in
            store.exportOptions[keyPath: keyPath] = newValue
            store.persistExportDefaults()
        }
    }
}
