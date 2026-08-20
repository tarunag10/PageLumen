import Foundation

/// The document kinds that PageLumen can receive through Finder, the open-file
/// delegate, drag and drop, or an App Intent URL parameter.
///
/// This contract intentionally uses extensions instead of inspecting file
/// contents. The importer remains the authority for validating the bytes, but
/// system entry points should reject obviously unsupported files before they
/// reach the import queue.
public enum PageLumenSystemWorkflowContract {
    public static let supportedFileExtensions: Set<String> = [
        "pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic", "heif"
    ]

    public static func supportsDocumentURL(_ url: URL) -> Bool {
        supportedFileExtensions.contains(url.pathExtension.lowercased())
    }

    /// The maximum number of files a future Finder Quick Action or Share
    /// extension may forward in one invocation.  The app's normal importer
    /// remains the authority for byte-level validation; this is an early,
    /// deterministic host-workload bound.
    public static let maximumExtensionInputCount = 20

    /// Returns the supported files in host-provided order, capped before any
    /// security-scoped URL is opened.  Keeping this pure makes it safe to use
    /// from an extension and easy to exercise without a Finder host.
    public static func acceptedExtensionURLs(_ urls: [URL]) -> [URL] {
        urls.filter(supportsDocumentURL).prefix(maximumExtensionInputCount).map { $0 }
    }

    /// Rendering policy shared by a future Quick Look thumbnail/preview
    /// provider.  It intentionally contains no PDFKit or AppKit types so the
    /// extension can validate work before acquiring a security-scoped URL.
    public enum QuickLookMode: String, CaseIterable, Sendable {
        case thumbnail
        case preview
    }

    public struct QuickLookRenderPolicy: Equatable, Sendable {
        public let mode: QuickLookMode
        public let maximumPixelDimension: Int
        public let maximumPageCount: Int
        public let maximumOutputBytes: Int

        public init(
            mode: QuickLookMode,
            maximumPixelDimension: Int = 2_048,
            maximumPageCount: Int = 3,
            maximumOutputBytes: Int = 8 * 1_024 * 1_024
        ) {
            self.mode = mode
            self.maximumPixelDimension = max(1, maximumPixelDimension)
            self.maximumPageCount = max(1, maximumPageCount)
            self.maximumOutputBytes = max(1, maximumOutputBytes)
        }

        public static let thumbnail = QuickLookRenderPolicy(
            mode: .thumbnail,
            maximumPixelDimension: 512,
            maximumPageCount: 1,
            maximumOutputBytes: 2 * 1_024 * 1_024
        )

        public static let preview = QuickLookRenderPolicy(mode: .preview)

        public func boundedPageCount(for sourcePageCount: Int) -> Int {
            min(max(0, sourcePageCount), maximumPageCount)
        }

        /// Scales a source size down without enlarging it.  The result is
        /// integral and never contains a non-finite or zero dimension.
        public func boundedPixelSize(width: Double, height: Double) -> (width: Int, height: Int)? {
            guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
            let scale = min(1, Double(maximumPixelDimension) / max(width, height))
            let boundedWidth = max(1, Int((width * scale).rounded(.down)))
            let boundedHeight = max(1, Int((height * scale).rounded(.down)))
            return (boundedWidth, boundedHeight)
        }
    }

    /// Validates the cheap properties available before a Quick Look provider
    /// opens a security-scoped URL.  This is deliberately not a substitute for
    /// the provider's file-access, PDF, image, timeout, or memory checks.
    public static func quickLookPolicy(
        for url: URL,
        mode: QuickLookMode
    ) -> QuickLookRenderPolicy? {
        guard supportsDocumentURL(url) else { return nil }
        return mode == .thumbnail ? .thumbnail : .preview
    }

    /// These are deliberately separate from the app's supported input list:
    /// they describe capabilities that require additional app-extension
    /// packaging and host-system validation.
    public enum PackagedCapability: String, CaseIterable, Sendable {
        case finderOpenFile
        case finderQuickAction
        case shareExtension
        case quickLookPreview
        case quickLookThumbnail

        public var isPackagedInCurrentTarget: Bool {
            switch self {
            case .finderOpenFile, .shareExtension, .quickLookThumbnail:
                return true
            case .finderQuickAction, .quickLookPreview:
                return false
            }
        }
    }
}
