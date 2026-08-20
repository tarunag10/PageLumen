import AppKit
import Foundation
import UniformTypeIdentifiers

/// Finder/Share entry point for a bounded set of PDF and image files. The
/// extension does not OCR, persist, or cache source content; it validates the
/// host-provided URLs and hands them to the normal PageLumen open-file path.
final class ShareViewController: NSViewController {
    private var didHandleRequest = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard let context = extensionContext else { return }
        beginRequest(with: context)
    }

    override func beginRequest(with context: NSExtensionContext) {
        guard !didHandleRequest else { return }
        didHandleRequest = true

        let providers = (context.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let value = item as? URL {
                    url = value
                } else if let value = item as? NSURL {
                    url = value as URL
                } else {
                    url = nil
                }
                guard let url else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self, weak context] in
            guard let self, let context else { return }
            lock.lock()
            let accepted = Self.acceptedURLs(urls)
            lock.unlock()
            guard !accepted.isEmpty else {
                context.cancelRequest(withError: NSError(domain: "PageLumenShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: "PageLumen accepts PDF and image files only."]))
                return
            }

            // Opening through the extension context keeps the normal app
            // delegate/import notification as the single source of truth.
            var remaining = accepted.count
            for url in accepted {
                context.open(url) { _ in
                    remaining -= 1
                    if remaining == 0 {
                        context.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                }
            }
        }
    }

    private static func acceptedURLs(_ urls: [URL]) -> [URL] {
        let supported = Set(["pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic", "heif"])
        return urls.filter { supported.contains($0.pathExtension.lowercased()) }.prefix(20).map { $0 }
    }
}
