# PageLumen Privacy

This page summarises the privacy commitments that PageLumen makes to its users. It draws from the product PRD (`pagelumen_prd.md`, sections 11.3 and 16.3) and the security policy in `SECURITY.md`.

## Local Processing by Default

- OCR, layout analysis, summaries, and exports all run on-device using Apple platform frameworks (Vision, PDFKit, AVFoundation, NaturalLanguage).
- The macOS sandbox entitlements in `Config/PageLumen.entitlements` restrict the app to user-selected files and explicit screen-capture requests.
- No document content leaves the machine unless the user explicitly opts in to a future cloud feature that is not present in the current build.

## No Third-Party SDKs

- PageLumen links only first-party Apple frameworks and standard library code. There is no analytics SDK, no ad SDK, and no third-party document-processing dependency in the build graph.
- The SwiftPM `Package.swift` and XcodeGen `project.yml` are the only dependency manifests. Both are reviewed as part of the build.

## No Network Calls Without Explicit Consent

- The app does not make outbound network requests as part of the documented workflow.
- A "Privacy mode" toggle lives in **Settings → Privacy**. It is on by default. When on, every code path that would otherwise touch the network is disabled; the in-app privacy badge is shown next to the export action so the user can confirm the state before saving.
- A future cloud-assisted feature, if shipped, will require an explicit, labelled opt-in before any document is transmitted.

## Exported JSON and Source URLs

- The JSON export written by `ExportEngine` includes the source `ReaderDocument.sourceURL` by default, because that is often useful when piping output into downstream tooling.
- The new "Save export anonymously" toggle in the Summary & Export view flips on the `redactSourceURL` option of the new `ExportSanitizer`. With it on, `sourceURL` is stripped from the JSON payload and OCR-text snippets in the Accessibility Report are truncated. This is on top of any redaction the user may already do at the file system level.

## Clearing Local Cache and Recent Documents

- PageLumen keeps its derived thumbnails, sample documents, and temporary capture files under the app's container. You can clear them from **Settings → Library → Clear cache** and from **Settings → Library → Forget all recent documents**.
- Removing the app from `/Applications` deletes the sandbox container with it. Manual cache files written to `~/Library/Caches` are removed on uninstall via the standard macOS cleanup.

## Vulnerability Reporting

Please see [`SECURITY.md`](../SECURITY.md) for the private vulnerability reporting flow and for the list of privacy-sensitive areas the maintainers watch most closely.
