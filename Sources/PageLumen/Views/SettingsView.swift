import SwiftUI

struct SettingsView: View {
    @AppStorage("privacyMode") private var privacyMode = true
    @AppStorage("ocrProfile") private var ocrProfile = "General"
    @AppStorage("languageHint") private var languageHint = "Automatic"

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Privacy mode", isOn: $privacyMode)
                Text("Privacy mode keeps the MVP workflow local and disables future network-assisted processing by default.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Recognition") {
                Picker("OCR profile", selection: $ocrProfile) {
                    Text("General").tag("General")
                    Text("Legal").tag("Legal")
                    Text("Academic").tag("Academic")
                    Text("Receipts").tag("Receipts")
                    Text("Slides").tag("Slides")
                }

                Picker("Language hint", selection: $languageHint) {
                    Text("Automatic").tag("Automatic")
                    Text("English").tag("English")
                    Text("Hindi").tag("Hindi")
                    Text("Spanish").tag("Spanish")
                    Text("French").tag("French")
                }
            }

            Section("PRD Coverage") {
                Text("Implemented locally: PDF/image import, paste image, batch import, screenshot capture, OCR, reading order, outline, editing, header/footer filtering, summaries, speech playback, Markdown/TXT/HTML/PDF/CSV/JSON exports, and privacy/profile settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Longer-term roadmap: scanner/browser imports, trained layout models, full PDF/UA validation, advanced chart data extraction, audio-file export, EPUB/LMS/integration exports, and enterprise administration.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
