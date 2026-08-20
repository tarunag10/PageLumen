# User-facing claim audit — 2026-08-20

This is a source-level audit of claims visible in PageLumen’s settings,
import, review, export, and privacy documentation. It does not replace
VoiceOver/participant review or App Review.

| Claim | Implementation/evidence | Boundary wording |
| --- | --- | --- |
| Documents are processed locally by default | `DocumentProcessor`, `docs/privacy.md`, and the default privacy mode | Translation and explicitly opted-in remote Stirling operations are separate, consented paths. |
| Translation is availability-gated | `TranslationService` uses macOS availability and typed unavailable/downloadable states; `TranslationServiceTests` covers fallback states | No translated output is labelled available when the provider is unsupported or unavailable. |
| Apple Intelligence is optional and draft-only | `IntelligenceMode`, `IntelligentExplainerAvailabilityInfo`, `ExplanationEngine`, and grounded-summary tests | Generated text is labelled as non-source text and retains local citations; deterministic fallback is explicit. |
| Screen capture is user-selected and permissioned | `ScreenshotCaptureService`, `NSScreenCaptureUsageDescription`, and `docs/screen-capture.md` | Permission denial, cancellation, and no-shareable-content are surfaced; participant picker validation remains open. |
| Searchable copies are opt-in | `DocumentStore`/`LocalLibrary`, Settings toggle, and `search-and-encryption-decision.md` | Turning the setting off does not claim encryption-at-rest or erase source files. |
| Tagged HTML is review-ready, not full PDF/UA | `HTMLExportContract`, `PDFUADirection`, export copy, and `docs/pdf-ua-direction.md` | Full PDF/UA conformance and independent consumer rendering remain release/manual gates. |
| Stirling PDF is optional | `StirlingPDFProvider`, endpoint/security validation, credential boundary, and `docs/stirling-pdf-integration.md` | Remote transfer requires explicit HTTPS endpoint and consent; the provider is not enabled by default. |
| Local archive is not a live release | `docs/release-checklist.md` and dated release evidence | Notarization, upload, review, and live-store states are reported separately. |

Re-run this audit when a new provider, model, export format, capture path, or
retention behavior is added.
