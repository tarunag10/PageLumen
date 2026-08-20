import PDFKit
import QuickLookUI

/// Bounded, read-only Quick Look preview provider. Only the first three PDF
/// pages are exposed to the preview host; no OCR, persistence, or cache writes
/// occur in the extension.
@available(macOS 12.0, *)
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest, completionHandler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let url = request.fileURL
        guard url.pathExtension.lowercased() == "pdf",
              let source = PDFDocument(url: url),
              source.pageCount > 0,
              let firstPage = source.page(at: 0) else {
            completionHandler(nil, NSError(domain: "PageLumenQuickLookPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "PageLumen preview supports readable PDF files only."]))
            return
        }

        let pageSize = firstPage.bounds(for: .mediaBox).size
        let reply = QLPreviewReply(forPDFWithPageSize: pageSize) { _ in
            let bounded = PDFDocument()
            let pageCount = min(source.pageCount, 3)
            for index in 0..<pageCount {
                guard let page = source.page(at: index) else { continue }
                bounded.insert(page, at: bounded.pageCount)
            }
            guard bounded.pageCount > 0 else {
                throw NSError(domain: "PageLumenQuickLookPreview", code: 2, userInfo: [NSLocalizedDescriptionKey: "The PDF contains no renderable pages."])
            }
            return bounded
        }
        completionHandler(reply, nil)
    }
}
