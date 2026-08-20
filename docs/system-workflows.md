# Finder and Quick Look system workflows

PageLumen currently supports the safest part of the macOS system workflow:

- `CFBundleDocumentTypes` declares PDF, PNG, JPEG, TIFF, and HEIC input in the
  application Info.plist generated from `project.yml`.
- `AppDelegate.application(_:open:)` accepts only those extensions and forwards
  them to the same import notification used by the in-app open panel and App
  Intents. Unsupported Finder-open files are ignored before entering the import
  queue.
- `PageLumenSystemWorkflowContract` is the shared, deterministic list used by
  the delegate and unit tests.

Finder Quick Action, Share extension, Quick Look preview, and Quick Look
thumbnail support are intentionally not claimed as shipped. Each requires a
separate app-extension target, extension-specific Info.plist and sandbox
configuration, security-scoped URL handling, and validation on a real Finder
host. A future implementation must verify:

1. The extension can access a user-selected file without retaining a stale
   security-scoped bookmark.
2. PDF and image rendering is bounded for very large pages and cannot block the
   extension host or exhaust memory.
3. The extension never writes OCR text or source content to shared caches.
4. The generated archive contains the extension, correct `NSExtensionPoint`
   identifiers, and matching entitlements.
5. Finder, Share, Quick Look, and revoked-permission participant tests pass on
   the minimum supported macOS release.

The core target now contains the host-independent part of that future work:
`acceptedExtensionURLs(_:)` filters unsupported URLs and caps one extension
invocation at 20 inputs before any security-scoped access is attempted.
`QuickLookRenderPolicy` provides separate thumbnail and preview bounds (512 px
and one page for thumbnails; 2,048 px and three pages for previews), along with
finite, non-enlarging pixel-size calculations and output-byte limits. These
values are safety contracts for a provider; they do not claim that a Quick Look
extension has been packaged or that memory/latency behaviour has passed on a
physical Mac. The eventual provider must enforce the policy while rendering,
release security scopes on every path, and surface a bounded failure to the
host when the source cannot be opened.

The capability enum keeps this packaging boundary explicit until those gates
are available; it is not a substitute for a future extension target.
