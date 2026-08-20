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
5. Require an explicit per-operation authorization at the core upload boundary.
   Privacy mode disables this path, including loopback instances configured
   with an API key.
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

#### Current implementation

The Stage A boundary is implemented in
`Sources/PageLumenCore/StirlingPDFProvider.swift` as
`StirlingPDFCapabilityProbe`. It is an additive PageLumenCore capability and
does not add a server, Java runtime, Docker dependency, or package dependency.
The default `URLSessionStirlingPDFHTTPTransport` issues only a `GET` request;
the transport protocol is injectable so tests can exercise a fake server
without binding a port or sending document data.

`StirlingPDFEndpoint` accepts loopback HTTP (`localhost`, `127.0.0.1`, or
`::1`) and rejects remote HTTP by default. Remote HTTPS is also rejected until
the caller explicitly sets `allowRemoteHTTPS`. `capabilityState` exposes
loopback, blocked remote HTTP, and advanced remote HTTPS states, plus
privacy-safe warning text for Settings. URLs containing credentials, query
strings, or fragments are rejected. Stage A keeps an API key in memory only
and sends it as `X-API-KEY`; it does not persist, log, or export the key.
The app Settings surface now accepts a non-secret endpoint, shows the
privacy-safe capability state, keeps remote HTTPS opt-in explicit, and offers
an on-demand metadata-only connection check. API keys remain a separate
Keychain boundary and are never entered into or persisted by these settings.
Document operations still require an in-app confirmation at the upload
boundary.

The probe returns distinct states for availability, authentication failure,
timeout, cancellation, TLS failure, unavailable services, malformed status
responses, and invalid endpoints. A successful response is reduced to
version/status/operation metadata; unknown response fields are discarded and
no source content is accepted by this API. The focused fake-transport suite
is `StirlingPDFProviderTests`.

### Stage B — one safe operation

Implement `compress` using the documented `POST /api/v1/misc/compress-pdf`
multipart contract. Add request-size limits, cancellation, atomic output, and
tests with a fake URL protocol. Compare the returned PDF with PDFKit before
offering to replace the original.

#### Current implementation checkpoint

The Stage B boundary is implemented in
`Sources/PageLumenCore/StirlingPDFProvider.swift` as
`StirlingPDFCompressor`. It is opt-in and additive: no app runtime path
constructs it implicitly. Every call validates the configured endpoint before
building a request, enforces bounded input/output sizes, sends the source only
as the documented multipart `fileInput` field, and keeps the API key in the
request header without logging or embedding it in the URL. Cancellation is
mapped to a typed error, successful output is validated with PDFKit, and
`StirlingPDFAtomicOutput` uses an atomic write for a caller-selected
destination. The focused fake-transport coverage includes request shape and
secret non-leakage, success, authentication/HTTP failures, cancellation,
malformed output, endpoint rejection, and atomic output validation.

The shared provider seam is implemented in
`Sources/PageLumenCore/PDFOperationsProvider.swift`. `NativePDFOperationsProvider`
is the default, network-free provider and supports local PDFKit validation;
unsupported native transformations fail with a typed error. The opt-in
`StirlingPDFOperationsProvider` adapts the typed `compress` and `merge`
operations to the already validated Stirling boundaries. Constructing the
adapter does not probe or contact the server; an operation must be explicitly
executed with document bytes. `PDFOperationsProviderTests` covers native
validation, unsupported operations, adapter request mapping, and this
no-contact construction guarantee (4/4 passed).

### Stage C — multi-input and pipelines

The first Stage C boundary is `StirlingPDFMerger` in
`Sources/PageLumenCore/StirlingPDFProvider.swift`. It targets the documented
`POST /api/v1/general/merge-pdfs` endpoint and sends each source as a repeated
`fileInput` multipart field. It is still opt-in and does not construct a
provider in the default app runtime.

The operation requires at least two PDFs, caps the input count at 20 and the
combined input size at 200 MiB by default, supports cancellation, maps
authentication/HTTP/transport failures to typed errors, validates the returned
bytes with PDFKit, and can reuse `StirlingPDFAtomicOutput` for an atomic
caller-selected destination. Fake transport tests cover request shape,
filename sanitisation, API-key non-leakage, count/size limits, cancellation,
authentication, and malformed output.

Next, add rearrange and pipeline execution. Every pipeline must have a typed,
versioned schema, a visible step list, bounded step count, a cancellation
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
