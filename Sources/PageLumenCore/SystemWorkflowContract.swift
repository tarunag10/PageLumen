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
            self == .finderOpenFile
        }
    }
}
