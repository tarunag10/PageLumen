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

The capability enum keeps this packaging boundary explicit until those gates
are available; it is not a substitute for a future extension target.
