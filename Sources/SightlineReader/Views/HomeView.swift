import UniformTypeIdentifiers
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sightline Reader")
                    .font(.largeTitle.bold())
                Text("Make PDFs, screenshots, scans, and slides readable, listenable, and exportable with local-first processing.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 16) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.tint)
                Text("Drop a PDF or image")
                    .font(.title2.weight(.semibold))
                Text("PDF, PNG, JPEG, TIFF, and HEIC are supported. Originals are preserved.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Open Document") {
                        store.openDocumentPanel()
                    }
                    .keyboardShortcut("o", modifiers: [.command])

                    Button("Paste Image") {
                        store.pasteImageFromClipboard()
                    }

                    Button("Load Demo") {
                        store.loadSample()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data,
                          let string = String(data: data, encoding: .utf8),
                          let url = URL(string: string) else {
                        return
                    }
                    Task { @MainActor in
                        await store.importURL(url)
                    }
                }
                return true
            }

            HStack(spacing: 16) {
                InfoTile(title: "Trust", value: "Extracted text and generated notes stay visually separated.")
                InfoTile(title: "Privacy", value: "OCR uses Apple Vision locally for baseline processing.")
                InfoTile(title: "Exports", value: "Markdown, TXT, HTML, and basic accessible PDF.")
            }

            Spacer()
        }
        .padding(32)
    }
}

private struct InfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
