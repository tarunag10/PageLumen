# PageLumen Privacy

This page summarises the privacy commitments that PageLumen makes to its users. It draws from the product PRD (`pagelumen_prd.md`, sections 11.3 and 16.3) and the security policy in `SECURITY.md`.

## Local Processing by Default

- OCR, layout analysis, summaries, and exports all run on-device using Apple platform frameworks (Vision, PDFKit, AVFoundation, NaturalLanguage).
- The macOS sandbox entitlements in `Config/PageLumen.entitlements` restrict the app to user-selected files and explicit screen-capture requests.
- No document content leaves the machine unless the user explicitly opts in to a future cloud feature that is not present in the current build.

## Small, Audited Open-Source Surface

- PageLumen has no analytics SDK, ad SDK, or cloud-processing dependency. It uses the audited open-source packages ZIPFoundation (DOCX archive writing) and swift-snapshot-testing (test-only regression coverage); versions are pinned in `Package.resolved` and licenses are recorded in `THIRD_PARTY_NOTICES.md`.
- The SwiftPM `Package.swift` and XcodeGen `project.yml` are reviewed together. No package downloads models or sends document content over the network.

## No Network Calls Without Explicit Consent

- The app does not make outbound network requests as part of the documented workflow.
- A "Privacy mode" toggle lives in **Settings → Privacy**. It is on by default. When on, translated export is disabled because that capability may use a network-assisted translation provider. The export screen surfaces the resulting status message, so the user can confirm why that format is unavailable before saving. All other documented workflows remain local in the current build.
- A future cloud-assisted feature, if shipped, will require an explicit, labelled opt-in before any document is transmitted.

## Local searchable copies

- Retained recent-document metadata remains available for the local library.
- **Keep searchable local copies** is off by default. When it is off, library
  search returns no OCR-text matches; turning it on is an explicit opt-in for
  future local searches.
- Turning the setting off is reversible and does not delete recent metadata,
  source files, or existing user data. Use the separate library deletion
  controls when deletion is intended.
- Use the recent-document context menu to forget one retained PageLumen copy,
  or **Settings → Library → Forget all recent documents** to clear the whole
  library. These actions never delete the original source file.

## Exported JSON and Source URLs

- The JSON export written by `ExportEngine` includes the source `ReaderDocument.sourceURL` by default, because that is often useful when piping output into downstream tooling.
- The Summary & Export view includes an "Include provenance and review details" toggle. Turn it off when sharing a JSON export without PageLumen's document identifier, source metadata, or review-count envelope. The existing `redactSourceURL` and `redactTextSnippets` options remain available to callers that need finer-grained redaction.

## Clearing Local Cache and Recent Documents

- PageLumen keeps its derived thumbnails, sample documents, and temporary capture files under the app's container. You can clear them from **Settings → Library → Clear cache** and from **Settings → Library → Forget all recent documents**.
- Removing the app from `/Applications` deletes the sandbox container with it. Manual cache files written to `~/Library/Caches` are removed on uninstall via the standard macOS cleanup.

## Vulnerability Reporting

Please see [`SECURITY.md`](../SECURITY.md) for the private vulnerability reporting flow and for the list of privacy-sensitive areas the maintainers watch most closely.
