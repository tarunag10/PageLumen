# Optional Stirling-PDF provider

PageLumen remains a native, local-first macOS reader. Stirling-PDF is an
optional provider for advanced PDF operations that are not yet implemented by
PageLumen itself. It is not a required runtime dependency and is never started,
downloaded, or contacted implicitly.

## Why it is in the roadmap

The official [Stirling-PDF repository](https://github.com/Stirling-Tools/Stirling-PDF)
provides a locally hosted PDF platform with merge, split, rearrange, rotate,
crop, compress, OCR, redaction, signing, conversion, pipelines, REST APIs, and
an MCP integration. Its API is exposed under `/api/v1/...` and accepts a
multipart `fileInput`; pipeline automation accepts a JSON workflow and can
chain operations.

PageLumen should borrow the workflow ideas—capability discovery, explicit
progress, repeatable pipelines, and preview-before-save—not embed Stirling's
Java/Spring/React/Tauri implementation.

## Integration boundary

1. Add a `PDFOperationsProvider` protocol owned by PageLumen.
2. Keep the existing PDFKit/Vision implementation as the default provider.
3. Add a separately compiled `StirlingPDFProvider` HTTP client only after a
   person enters and verifies a local base URL.
4. Store the URL and API key in Keychain; never put either in `UserDefaults`,
   logs, exports, crash reports, or source control.
5. Require an explicit per-operation confirmation that the selected PDF will
   be sent to the configured local service. Privacy mode disables this path.
6. Show the provider, endpoint, local/external status, operation, progress, and
   output destination in the UI before execution.
7. Write results to a caller-selected destination atomically and retain no
   server-side identifier in PageLumen's document provenance unless the user
   explicitly requests it.

## Staged implementation

### Stage A — capability probe

- `GET /api/v1/info/status` or the configured health endpoint, with a short
  timeout and cancellation support.
- Parse only version/capability metadata; never upload a document for probing.
- Treat unavailable, authentication failure, TLS failure, timeout, and invalid
  response as distinct user-facing states.
- Add URL validation that rejects non-local HTTP endpoints by default. Permit a
  remote HTTPS endpoint only after an explicit advanced setting and warning.

### Stage B — one safe operation

Implement `compress` using the documented `POST /api/v1/misc/compress-pdf`
multipart contract. Add request-size limits, cancellation, atomic output, and
tests with a fake URL protocol. Compare the returned PDF with PDFKit before
offering to replace the original.

### Stage C — multi-input and pipelines

Add merge/rearrange and then pipeline execution. Every pipeline must have a
typed, versioned schema, a visible step list, bounded step count, a cancellation
policy, and a dry-run/preview summary. Never accept arbitrary server-side
workflow JSON from an untrusted source without displaying it first.

### Stage D — system workflows

Expose approved operations through a Share extension, Quick Action, and App
Intent only after the in-app flow has passed the privacy and cancellation gates.
The intent must identify the configured provider and fail closed if the provider
is missing or disabled.

## Licensing and security gate

Stirling-PDF is currently described by its repository as open-core. Before any
redistributed code, binary, Docker image, or bundled server is shipped, record
the exact version, license text, notices, source-offer obligations, and which
modules are community versus proprietary. The first implementation should use
the documented API as an optional external service and should not copy source
code or bundle its server.

## Acceptance criteria

- Default PageLumen installs and runs with no Java, Docker, server, model, or
  network requirement.
- Privacy mode and offline mode cannot send a document to Stirling.
- No API key or source content appears in logs, analytics, crash reports, or
  provenance by default.
- Capability, authentication, timeout, cancellation, malformed-response, and
  output-validation tests pass with a fake server.
- Manual testing covers a local instance, a denied/invalid endpoint, a stopped
  instance, a large PDF, cancellation during upload, and recovery after a
  failed operation.
