import AppKit
import Combine
import Foundation
import SightlineCore

@MainActor
final class DocumentStore: ObservableObject {
    enum Destination: Hashable {
        case home
        case review
        case summaryExport
    }

    @Published var document: ReaderDocument = SampleDataFactory.makeDemoDocument()
    @Published var selectedDestination: Destination? = .home
    @Published var selectedPageNumber: Int = 1
    @Published var isProcessing = false
    @Published var statusMessage = "Ready"
    @Published var exportOptions = ExportOptions.full
    @Published var summaryLength: SummaryLength = .short

    private let processor = DocumentProcessor()
    private let exportEngine = ExportEngine()
    private let explanationEngine = ExplanationEngine()

    var selectedPage: ReaderPage? {
        document.pages.first(where: { $0.pageNumber == selectedPageNumber }) ?? document.pages.first
    }

    func loadSample() {
        document = SampleDataFactory.makeDemoDocument()
        selectedPageNumber = 1
        selectedDestination = .review
        statusMessage = "Loaded demo document"
    }

    func openDocumentPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a PDF, screenshot, scan, or image to make readable."
        if panel.runModal() == .OK, let url = panel.url {
            Task { await importURL(url) }
        }
    }

    func importURL(_ url: URL) async {
        isProcessing = true
        statusMessage = "Processing \(url.lastPathComponent)..."
        selectedDestination = .review
        defer { isProcessing = false }

        do {
            let processed = try await processor.process(url: url)
            document = processed
            selectedPageNumber = processed.pages.first?.pageNumber ?? 1
            statusMessage = "Extracted \(processed.pageCount) page\(processed.pageCount == 1 ? "" : "s") locally"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func pasteImageFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            statusMessage = "Clipboard does not contain an image."
            return
        }

        Task {
            isProcessing = true
            selectedDestination = .review
            defer { isProcessing = false }
            do {
                document = try await processor.processClipboardImage(image)
                selectedPageNumber = 1
                statusMessage = "Extracted clipboard image locally"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func regenerateSummary() {
        document.summary = explanationEngine.summary(for: document, length: summaryLength)
    }

    func updateBlock(_ block: TextBlock, text: String) {
        guard let pageIndex = document.pages.firstIndex(where: { $0.pageNumber == block.pageNumber }),
              let blockIndex = document.pages[pageIndex].blocks.firstIndex(where: { $0.id == block.id }) else {
            return
        }
        document.pages[pageIndex].blocks[blockIndex].text = text
        document.summary = explanationEngine.summary(for: document, length: summaryLength)
    }

    func export(format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = []
        panel.nameFieldStringValue = "\(document.title).\(format.fileExtension)"
        panel.message = "Export a cleaner, more accessible version of the extracted content."

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = exportEngine.data(for: document, format: format, options: exportOptions)
                try data.write(to: url, options: .atomic)
                statusMessage = "Exported \(format.rawValue) to \(url.lastPathComponent)"
            } catch {
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}
