# Stirling-PDF security and licensing decision record

Status: **external-service integration only; not approved for redistribution**  
Record owner: PageLumen maintainers / PDF operations owner  
Review date: 2026-08-20  
Next review: before every Stirling version change and before any PageLumen
distribution that bundles or redistributes Stirling material

This record covers the optional adapter in PageLumen. It is a product and
engineering decision record, not legal advice. A release that bundles or
redistributes Stirling-PDF requires a separate legal review of the exact
release, all transitive components, and the intended distribution model.

## What PageLumen is using

PageLumen uses a small, typed HTTP boundary to call a user-managed Stirling
instance for bounded PDF operations. It does **not** copy Stirling source
code, launch a Stirling process, download a server, or ship Java, Spring,
React, Tauri, Docker images, or Stirling model/tool binaries.

The current implementation is an external-service adapter, not a bundled
third-party dependency:

- capability probing is a metadata-only `GET` and never uploads a document;
- compression and merge are opt-in operations with bounded request and
  response sizes, cancellation, local PDF validation, and atomic output;
- loopback HTTP is the default allowed endpoint; remote HTTP is rejected;
  remote HTTPS requires an explicit advanced opt-in and warning. The core
  endpoint capability state exposes this distinction without contacting the
  service;
- every compression or merge upload requires a per-operation authorization.
  Privacy mode fails closed, and an API-key or any remote endpoint cannot
  upload without both privacy mode disabled and affirmative confirmation;
- API keys are secrets, stored through the macOS Keychain boundary when the
  app shell persists them, and are never part of a URL, document provenance,
  export, log, fixture, or error message;
- the native PDFKit provider remains the default and works without a network,
  server, Java runtime, Docker, or Stirling installation.

The adapter source and tests are PageLumen code. Stirling remains an optional
service selected by the person using the app.

## License and notice review

The upstream repository is open-core and its license scope is path-sensitive.
As reviewed on 2026-08-20:

1. The repository root [`LICENSE`](https://github.com/Stirling-Tools/Stirling-PDF/blob/main/LICENSE)
   describes MIT coverage for material outside explicitly excluded paths.
2. The repository's [`engine/LICENSE`](https://github.com/Stirling-Tools/Stirling-PDF/blob/main/engine/LICENSE)
   contains a separate Stirling PDF User License. Other directories may carry
   their own license files or third-party notices.
3. Therefore “Stirling-PDF is MIT” is not an acceptable PageLumen release
   claim. The exact tag or commit, selected modules, transitive binaries, and
   notices must be recorded before redistribution.

No Stirling code, binary, container, or server is currently included in the
PageLumen application or its Swift package graph. Consequently, the current
PageLumen binary does not distribute Stirling material and does not require a
Stirling copyright notice in the shipped application bundle. The repository
reference and this decision record are retained for auditability; if the
boundary changes, `THIRD_PARTY_NOTICES.md` must be expanded with the exact
source revision, license texts, notices, and source-offer obligations before
that change can be released.

The upstream repository and its release artifacts are mutable from the point
of view of this project. Do not depend on `main`, a floating Docker tag, or an
unverified download in a release process. Pin an immutable release tag and
commit digest, record checksums, and archive the applicable notices if a
future deployment requires one.

## Data flow, endpoint, and retention decision

The following is the approved boundary for the current adapter:

| Event | Data sent to Stirling | PageLumen guarantee |
| --- | --- | --- |
| Capability probe | Endpoint metadata only | No document bytes are sent; failures are typed and visible to the caller. |
| Compress or merge | The selected PDF bytes and generated multipart filename | Only an explicit operation may upload; size limits, cancellation, and returned-PDF validation apply. |
| Result handling | Returned PDF bytes | The result is written only to a caller-selected destination through an atomic write; no server identifier is retained by default. |

PageLumen cannot control the configured Stirling server's temporary files,
logs, caches, backups, access logs, authentication provider, or retention
period. It must never promise “zero retention” merely because an endpoint is
local. Before using a non-ephemeral instance, the person or organisation
operating that instance must review its deployment configuration, storage,
backups, access control, TLS, and deletion policy. The app UI must show this
limitation before the first document upload and must provide a per-operation
confirmation naming the endpoint and operation.

The default product remains local-first: privacy mode and offline mode must
fail closed and must not call this provider. A remote HTTPS endpoint is an
advanced, separately consented configuration, not a normal network path.

## Credential and configuration boundary

- Store only the API key in a Keychain item using
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Keep the endpoint URL as non-secret configuration; reject embedded URL
  credentials, query strings, and fragments. Do not put the API key in the
  endpoint URL.
- Never persist document content or API keys in `UserDefaults`, SwiftData,
  exports, provenance, analytics, crash payloads, or diagnostic logs.
- Redact request headers and multipart bodies in any future diagnostic
  facility. Test transports may use deterministic fake secrets only.
- Removing or changing a configured provider must delete its Keychain item and
  invalidate any cached capability result.

The current core package provides the typed `StirlingPDFCredentialStore` and
`KeychainStirlingPDFCredentialStore` boundary. Compression and merge require
`StirlingPDFOperationAuthorization`; this value is deliberately small and
contains no source content or secret. The app shell must create it only after
showing the endpoint, operation, server-retention limitation, and confirmation
control. A user-facing settings flow still needs to connect the Keychain
boundary to capability probing and recovery messaging before this integration
is presented as a finished product feature.

## Security owner and response process

The PDF operations owner reviews:

- upstream Stirling releases, security advisories, and API contract changes;
- endpoint validation, TLS policy, request-size limits, cancellation, output
  validation, and secret redaction;
- server retention and deployment guidance shown to users; and
- the focused Stirling tests plus the full PageLumen regression suite.

Security-sensitive reports follow [`SECURITY.md`](../SECURITY.md), not public
issues containing documents, credentials, or exploit details. A suspected
upstream Stirling vulnerability is first disabled at the adapter/configuration
boundary when practical, then tracked with the affected PageLumen version,
upstream advisory, endpoint exposure, and a user-facing mitigation.

## Removal and rollback plan

The integration is deliberately removable:

1. Disable the provider setting and stop constructing
   `StirlingPDFOperationsProvider`; the native provider and all local import,
   review, and export paths remain available.
2. Remove the Stirling provider/credential source files, adapters, focused
   tests, and documentation references in one versioned change.
3. Delete the associated Keychain service/account items and any cached
   capability metadata. No document provenance migration is required because
   the adapter does not persist server identifiers by default.
4. Remove any future extension, intent, or UI entry points before removing the
   core seam, and rerun the full package test and Xcode build gates.
5. If a future bundled server is ever adopted, keep it behind a separately
   versioned feature boundary so a license or security finding can disable and
   remove it without affecting the default native installation.

## Release gate

This record is complete for the current external-service-only milestone. It is
**not** approval to bundle or redistribute Stirling. That future milestone is
blocked until all of the following are attached to the release review:

- immutable Stirling version/commit and artifact checksums;
- path-by-path license and third-party notice inventory;
- legal approval for the intended app, server, and commercial distribution;
- security review of the server deployment and retention configuration;
- user-facing consent, endpoint, privacy, and failure UI;
- tests for offline/privacy-mode fail-closed behaviour and credential removal;
- a documented update owner, advisory response SLA, and removal commit path.
