import UniformTypeIdentifiers
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 1")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Add a document")
                    .font(.largeTitle.bold())
                Text("Choose a PDF, screenshot, scan, slide, or image. PageLumen will extract text locally, build a reading order, and send you to review.")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 18) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(.tint)
                Text("Drop a file here")
                    .font(.title2.weight(.semibold))
                Text("Works with PDF, PNG, JPEG, TIFF, and HEIC. You can also import multiple files at once.")
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        store.openDocumentPanel()
                    } label: {
                        Label("Open Files", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("o", modifiers: [.command])

                    Button {
                        store.pasteImageFromClipboard()
                    } label: {
                        Label("Paste Image", systemImage: "doc.on.clipboard")
                    }

                    Menu {
                        Button("Capture Selected Region") {
                            store.captureSelectedRegion()
                        }

                        Button("Capture Current Window") {
                            store.captureWindow()
                        }
                    } label: {
                        Label("Capture Screen", systemImage: "camera.viewfinder")
                    }

                    Button {
                        store.loadSample()
                    } label: {
                        Label("Try Demo", systemImage: "play.circle")
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .background(AccessibleStyle.panelBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isTargeted ? AccessibleStyle.selected : AccessibleStyle.border, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Document import drop zone")
            .accessibilityHint("Drop supported files here, or use the Open Files, Paste Image, Capture Screen, or Try Demo buttons.")
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                var urls: [URL] = []
                let group = DispatchGroup()

                for provider in providers {
                    group.enter()
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        defer { group.leave() }
                        guard let data,
                              let string = String(data: data, encoding: .utf8),
                              let url = URL(string: string) else {
                            return
                        }
                        urls.append(url)
                    }
                }

                group.notify(queue: .main) {
                    store.startImport(urls: urls)
                }

                return true
            }

            HStack(spacing: 16) {
                InfoTile(number: "1", title: "Add", value: "Open, paste, capture, or drop source files.")
                InfoTile(number: "2", title: "Process", value: "Watch page thumbnails and OCR progress.")
                InfoTile(number: "3", title: "Review", value: "Fix OCR text, check page order, and inspect notes.")
                InfoTile(number: "4", title: "Export", value: "Save Markdown, TXT, HTML, PDF, CSV, or JSON.")
            }

            Spacer()
        }
        .padding(32)
    }
}

private struct InfoTile: View {
    let number: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(number)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(AccessibleStyle.selected, in: Circle())
                Text(title)
                    .font(.headline)
            }
            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessiblePanel()
    }
}
