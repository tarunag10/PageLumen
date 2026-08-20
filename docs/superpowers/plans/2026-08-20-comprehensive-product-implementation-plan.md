# PageLumen Comprehensive Product Implementation Plan

**Date:** 2026-08-20  
**Status:** In progress — baseline, export, accessibility, UI/UX, and selected processing safeguards shipped; remaining gates are tracked explicitly below
**Owner:** PageLumen product and engineering team  
**Supersedes:** The prioritization and completion claims in `2026-06-15-audit-implementation-plan.md` and `2026-06-15-phase-8-modern-macos-features-plan.md` where they conflict with the current source. The earlier plans remain useful historical context.

## 1. Purpose

Turn PageLumen from a promising local OCR and export utility into a trustworthy, accessibility-first document-understanding workspace for people who need to read, correct, explain, search, and export difficult PDFs, scans, screenshots, and slides.

The product must be judged by whether a user can make a document reliably more usable, not by the number of AI features it advertises. Source traceability, correction speed, privacy, and honest output claims are the defining product advantages.

This plan deliberately separates:

- **ship blockers** — incorrect or unsafe current behaviour;
- **core product work** — features that make the review/remediation workflow meaningfully better;
- **optional capability experiments** — local models and third-party packages that need measured evidence before adoption;
- **release proof** — evidence that the app actually works on supported macOS versions and assistive technologies.

## 2. Current-State Baseline

### What is already present

- A native SwiftUI macOS app, deployment target macOS 14, with a testable `PageLumenCore` framework and an app-shell `DocumentStore`.
- Local PDF embedded-text extraction, Vision OCR, structured document recognition on newer macOS releases, layout heuristics, review/editing, speech, and exports.
- SwiftData-backed recent documents, sandbox entitlements, App Intents, TipKit, a menu-bar capture surface, and unit coverage.
- Baseline verification on 2026-08-20: `swift test` passed **107 tests** and `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -configuration Debug -destination 'generic/platform=macOS' build` succeeded.

### Truths that require correction before a public release

1. Translation is availability-gated through the Apple Translation framework and must not be presented as available when the language model is missing.
2. SwiftData initialization can fail on a damaged or unavailable store; recents storage must not prevent document reading. The app now falls back to the recoverable local JSON library and surfaces degraded status.
3. Screen capture chooses the first eligible window and falls back after all modern-capture failures. It needs user-controlled selection and a clear permission/cancellation path.
4. The app forces Dark Mode. A reader and accessibility tool must respect system appearance by default.
5. The PDF export is readable/selectable text but is not a demonstrated PDF/UA implementation. Keep the product label and documentation precise.
6. Foundation Models failures are swallowed and the AI path needs citations, output schema validation, and a measured quality gate before it becomes a default experience.

## 3. Product Principles and Non-Negotiable Constraints

### Principles

1. **Original source remains visible.** Every derived statement must lead back to a page and, when feasible, a source region.
2. **Local by default.** OCR, indexing, and Apple-provided intelligence are local unless a person explicitly enables a separately explained provider.
3. **Review is first-class.** The app should accelerate correction, not mask uncertainty behind polished prose.
4. **Accessibility output is an evidence-backed claim.** Never call an output accessible, tagged, translated, or compliant without defining and verifying what that claim means.
5. **Progressive enhancement.** macOS 14 remains supported. Newer platform capabilities are isolated behind availability checks and have useful fallbacks.
6. **No compulsory backend.** Do not create a server, telemetry pipeline, or account requirement in this program.

### Non-goals for this plan

- A general cloud document-management system.
- Full enterprise administration, collaboration, or remote processing.
- Automatic universal PDF/UA conformance.
- Unbounded model downloads or silently enabled third-party inference.
- Replacing professional accessibility remediation tools for regulated compliance work.

## 4. Architecture Target

Retain the existing `PageLumenCore` / app-shell split and introduce explicit adapters at all nondeterministic or platform-specific boundaries.

```text
Import / Capture
       |
DocumentInputService ── security-scoped access, user-selected capture
       |
ProcessingPipeline ── bounded render -> Vision -> layout -> source provenance
       |
ReaderDocument + Provenance + ReviewFinding
       |                         |
LocalLibrary / SearchIndex      Review Workspace
       |                         |
ExportPipeline <──────────── AI Assistance (optional, cited, evaluable)
       |
HTML / Markdown / DOCX / Readable PDF / Accessibility Report
```

### New boundary types

- `DocumentInputService`: imports files and manages security-scoped URLs/capture permission.
- `OCRService` and `DocumentStructureService`: isolate Vision request selection and deterministic fallbacks.
- `ReviewFindingEngine`: produces a normalized, prioritised review queue rather than scattered warning logic.
- `ProvenanceRecord`: records page number, source bounds, extraction source, confidence, user edits, and AI contribution.
- `TranslationProviding`, `IntelligenceProviding`, and `SearchIndexing`: protocol-first adapters with production and test doubles.
- `ExportValidator`: produces format-specific evidence and prevents overclaiming.

No new globally mutable singleton should be introduced. Persisted migrations must be versioned and recoverable.

## 5. Work Sequencing and Release Gates

| Milestone | Outcome | Depends on | Release gate |
|---|---|---|---|
| M0 | Correct product claims and crash/permission blockers | none | Existing workflows still pass on macOS 14 and current macOS |
| M1 | Durable, benchmarked import and review core | M0 | Corpus accuracy, memory, accessibility and regression gates |
| M2 | Trustworthy outputs and library/search workflow | M1 | Export validation and migration/retention tests |
| M3 | Apple Intelligence and macOS integration | M1, M2 | Opt-in, citations, evaluation threshold, supported-device fallback |
| M4 | Optional OSS model extensions | M3 | License, download, quality, storage, and offline removal gates |
| M5 | Public-release readiness | M0–M3 | Archive, privacy, assistive-tech, notarization/App Store checks |

Each milestone should ship in independently revertible pull requests. A feature flag or user setting is required for any new generative AI or downloaded model feature.

---

## Phase 0 — Product Truth, Safety, and Baseline Hardening (M0)

**Goal:** Remove incorrect user-facing behaviour and make failures recoverable.

### 0.1 Repair or remove translation

**Files:** `Sources/PageLumen/Support/TranslationService.swift`, `DocumentStore.swift`, `SettingsView.swift`, `SummaryExportView.swift`, `TranslationServiceTests.swift`

- [x] Replace the old identity/stub path with a `TranslationSession`-backed adapter on supported systems; older/unsupported systems return a typed unavailable error.
- [x] Before displaying a target language, use the provider availability boundary and distinguish: installed, downloadable with explicit approval required, unsupported, and failed.
- [x] Translate blocks while preserving block IDs/bounds and record `translatedFrom`, `translationTargetLanguage`, and `translationEngine` metadata.
- [x] Never create a translated export if translation was unavailable or if the returned text is unchanged for a source/target pair that should differ. Surface a recoverable error instead.
- [x] Rename the export action to `Translate and Export Markdown` until additional output formats are intentionally supported.
- [x] On macOS 14, hide or disable the action with an explanatory label; do not create an incorrectly labelled source-language export. `canExport` gates the action through the typed Translation availability boundary and the availability message explains the macOS requirement.
- [x] Add deterministic fake translation-provider tests for successful mapping, availability states, cancellation, partial failure, and unchanged-output detection. Do not make CI depend on downloaded language models.

**Acceptance:** A Spanish fixture produces a verified English fixture through a developer-run physical-Mac test; unsupported systems cannot falsely label an output as translated.

### 0.2 Make recents persistence nonfatal

**Files:** `Sources/PageLumenCore/SwiftDataPersisting.swift`, `FilePersisting.swift`, `DocumentStore.swift`, persistence tests

- [x] Change the convenience initializer to `throws`; remove `fatalError`.
- [x] Introduce `PersistenceStatus` (`available`, `degraded(reason)`) surfaced in Settings, not as a launch blocker. An explicit `unavailable` case remains unnecessary while the in-memory fallback is always retained.
- [x] If SwiftData cannot initialize, use `FilePersisting` in a safe app-support subdirectory and retain the active in-memory document while surfacing degraded status. Read-only/no-space fallback tests remain open.
- [ ] Version the SwiftData schema before adding new fields; the required migration/recovery contract is documented in `docs/persistence-migrations.md`, but the first concrete `VersionedSchema` migration and physical macOS fixture run remain open.
- [ ] Add corruption, read-only-directory, no-space, migration, and fallback tests using temporary directories/configurations.
- [x] Add JSON-store corruption recovery: preserve the damaged file under a
  recovery name, surface a degraded persistence status, and continue with an
  in-memory document. Read-only, no-space, and migration cases remain open.
- [x] Version the JSON fallback store with a `schemaVersion` envelope. Legacy
  unversioned arrays remain readable and are upgraded on the next write;
  future versions fail without moving or deleting the store so a newer binary
  can recover it. SwiftData schema migration remains a separate release gate.
- [x] Add `lastClearedAt` and a clear statement of what “Forget all” deletes; Settings persists/displays the timestamp and explicitly says original user-selected source files are not deleted.
- [x] Persist and display `lastClearedAt`; the Settings copy explicitly describes retained local copies and source files remain untouched.

**Acceptance:** A deliberately invalid SwiftData location launches, imports, reviews, and exports a document; Settings reports degraded recents storage.

### 0.3 Make screen capture consentful and predictable

**Files:** `ScreenshotCaptureService.swift`, `HomeView.swift`, `OnboardingView.swift`, `project.yml`, capture tests

- [x] Add `NSScreenCaptureUsageDescription` to the app Info configuration with a plain-language purpose statement.
- [ ] Replace first-window selection with `SCContentSharingPicker` where available. Do not inspect/capture a window until the person selects it.
- [x] Treat picker dismissal, denied permission, and API failure as distinct errors. Do not silently fall back to a shell capture after denial or dismissal.
- [x] Retain a narrowly scoped legacy region picker only if a supported native alternative cannot serve macOS 14; document why and make it visible in the UI.
- [x] Provide a pre-permission explanatory screen, a System Settings deep-link/help path after denial, cancellation, and stale temporary-file cleanup on app launch. Manual permission-denial recovery remains a participant gate.
- [x] Ensure temporary captures are removed after successful processing unless the person explicitly saves them, and clean stale PageLumen capture files from the temporary directory at service startup. The cleanup is prefix-scoped, age-bounded, and regression-tested without touching unrelated files.
- [ ] Add tests for error mapping, no selected window, cancellation, temp cleanup, and command argument construction. Manually test macOS 14 and the current macOS release.

**Acceptance:** Capture never selects a random window. Permission denial or dismissal leaves no imported document and gives a clear next action.

### 0.4 Respect system appearance and accessibility preferences

**Files:** `PageLumenApp.swift`, `AccessibleStyle.swift`, view snapshots/tests

- [x] Remove all forced `.preferredColorScheme(.dark)` calls; the app now defaults to system appearance and offers explicit system/light/dark selection in Settings.
- [x] Add an optional Appearance setting (`System`, `Light`, `Dark`) that defaults to System and leaves contrast/transparency controls independent.
- [ ] Verify system Increase Contrast, Reduce Transparency, Reduce Motion, VoiceOver focus, keyboard-only navigation, large text, and light/dark appearance.
- [x] Ensure colours have semantic names/tokens and all status indicators retain a text and symbol equivalent. Shared `AccessibleStyle` tokens now cover accent foregrounds, surfaces, text, borders, and status colors; system contrast/VoiceOver participant verification remains a separate release gate.

**Acceptance:** The app follows system appearance by default and no core workflow loses usable contrast in either appearance.

### 0.5 Correct product terminology

- [x] Rename `Accessible PDF` to `Readable PDF` in UI, source, tests, documentation, and marketing until validation supports a stronger claim.
- [x] Keep `Tagged HTML` as the recommended remediation export and explain its verification scope.
- [ ] Standardise the app name as **PageLumen**; archive or explicitly mark the older “Sightline Reader” PRD naming as historical.
- [ ] Reconcile `README.md`, `docs/accessibility.md`, Settings copy, and `pagelumen_prd.md` against implemented behaviour.

**Exit gate for Phase 0:** `swift test`, app-target build, lint/release scripts, manual import/capture/translate smoke test, and a copy audit all pass. No user-facing feature claims remain knowingly false.

---

## Phase 1 — Bounded, Provenanced Document Processing (M1)

**Goal:** Make import fast, memory-safe, inspectable, and comparable across real documents.

### 1.1 Stream PDF rendering and OCR

**Files:** `DocumentProcessor.swift`, fixtures, performance tests

- [x] Replace all-page pre-rendering with a bounded producer/consumer pipeline. PDF processing now renders and recognizes one page at a time in deterministic order.
- [ ] Render only scanned/no-embedded-text pages, downsample to a documented OCR target DPI, and release each bitmap immediately after recognition. The PDF OCR path now targets roughly 144 DPI and standalone images are bounded to 16M pixels/4096px per side before Vision; a source-DPI-aware image target remains open.
- [x] Cap in-flight renders/OCR tasks using device capacity and a user-visible “processing pages x of y” state; permit cancellation at page boundaries. The current implementation intentionally caps concurrency at one page to preserve memory and cancellation determinism.
- [ ] Apply both pixel and estimated-memory budgets. Provide a user choice to reduce quality or import a page range rather than only rejecting a large document.
- [x] Replace the remaining `lockFocus` thumbnail path with ImageIO thumbnail generation. `NSImage.pngData(maxPixelSize:)` now uses `CGImageSourceCreateThumbnailAtIndex` and `CGImageDestination`, with a bounded-thumbnail regression test.
- [x] Add deterministic 10-page and 50-page embedded-text wall-time baselines plus oversized/damaged PDF coverage; record thresholds and observed results in `docs/performance-baseline-2026-08-20.md`. Peak resident-memory measurement and scanned-image OCR baselines remain physical-device gates.

**Initial quality targets:** no unbounded bitmap retention; cancellation latency under two seconds between pages; reference 50-page scan completes within a documented device-dependent budget without exceeding an agreed memory ceiling.

### 1.2 Improve document structure and reading order

- [x] Preserve the fast embedded-text path and augment it with PDF semantics available through PDFKit: page labels, links, nested bookmarks, document metadata, annotations, form fields, and bounded character text positions. All are retained through the model with legacy Codable defaults; unsupported producer-specific semantics remain outside the contract.
- [ ] Use Vision structured document recognition for image/scanned pages, retaining raw observations and normalized bounds before heuristic post-processing.
- [ ] Explicitly model lists, captions, headers, footers, footnotes, sidebars, tables, and figures. Do not force unknown content into prose.
- [ ] Add a reading-order confidence score and provenance for every ordering decision.
- [ ] Create deterministic fixtures for: two/three-column papers, legal filings, forms, receipts, slides, multi-page tables, charts, rotated pages, multilingual text, low-quality scans, handwriting, equations, and documents with deliberate OCR traps.
- [ ] Add corpus metrics: character error rate, word error rate, reading-order accuracy, table-cell accuracy, false heading rate, and processing time.

**Acceptance:** Corpus metrics are captured in version-controlled JSON/Markdown. A regression cannot be merged without an explicit approved baseline update.

### 1.3 Add provenance and review findings

- [x] Add `ProvenanceRecord` or typed fields rather than expanding unstructured metadata dictionaries. `BlockProvenance` is now Codable, backward-compatible, and carried by OCR/embedded-text blocks and explicit text/type edits.
- [ ] Record source (`embeddedPDF`, Vision, user edit, Apple intelligence), page, bounds, confidence, timestamp, and parent source when a block is altered. Embedded/PDF/Vision, text/type edits, and table/figure description edits are wired; AI-generated summaries now retain privacy-safe engine/timestamp/citation metadata, while AI block-level lineage remains open.
- [x] Replace scattered warning generation with a `ReviewFinding` model: `id`, severity, category, page/block/table/figure reference, explanation, resolved state, and typed provenance. `ReviewFindingProvenance` records source, page, bounds, parent block, and timestamp without copying source text; recommended-action and full export persistence remain open.
- [ ] Prioritise findings: unreadable page, missing structure, low confidence, conflicting extraction sources, unresolved table headers, missing image description, and unreviewed AI contribution.
- [ ] Persist resolution state and include it in exports/audit reports without exposing source text when anonymisation is selected.

**Acceptance:** Every correction and AI suggestion can be traced to a source region or clearly marked as inference.

### 1.4 Create the review workspace

- [ ] Add a filterable Review Queue with keyboard shortcuts for next/previous finding, accept/reject suggestion, mark reviewed, and open original source region. The queue popover now lists all unresolved findings, filters All/Blockers/Warnings, opens each source region, and resolves/reopens block-backed findings without changing source text; page-warning correction and richer accept/reject suggestion states remain open.
- [ ] Synchronise preview, extracted text, and issue list selection; support page-level deep links.
- [ ] Support table-grid editing with explicit column-header and row-header assignment.
- [x] Add reusable review presets for General, Legal, Academic, Receipts, Slides, and Accessibility Remediation. Settings exposes the preset and the core review engine applies only threshold/warning changes; source data remains untouched.
- [ ] Add undo/redo for edits and an edit history view. Core bounded undo/redo for text, structure, table/figure descriptions, ordering, and review state is now shipped; the visible edit-history view and raw-OCR diff remain open. Do not overwrite raw OCR.

**Exit gate for Phase 1:** Representative-corpus thresholds pass, the review queue is keyboard usable, memory/cancellation tests pass, and manual VoiceOver testing confirms source-to-finding navigation.

---

## Phase 2 — Trustworthy Outputs and Export Validation (M2)

**Goal:** Make every format deliberate, testable, and accurately named.

### 2.1 Establish an export contract

- [x] Define a format capability matrix in `docs/accessibility.md`: semantics retained, source citations, table support, figure descriptions, metadata, anonymisation, and validation status.
- [x] Add `ExportValidationResult` with machine-readable warnings and a human-readable report.
- [x] Block or require confirmation when exporting unresolved blocker-level review findings.
- [x] Add an additive JSON provenance/review summary backed by `GroundedSummary` and `SummaryCitation`; the export envelope labels inclusion and the existing privacy options exclude summary/citation prose without dropping stable page/block locations. Extending the same contract to every output remains future work.
- [x] Update Save Panels, file extensions, preview copy, and user documentation to use the same terminology.

### 2.2 Tagged HTML and Markdown

- [x] Make tagged HTML the recommended remediation export.
- [ ] Verify heading hierarchy, landmarks, document language, table headers/scopes, figure alt text, link preservation, and escaped content.
- [x] Add page/block anchors so exported citations can return to the original PageLumen review workspace.
- [x] Add a robust Markdown AST validation/normalisation layer (see `swift-markdown` decision below) before supporting Markdown import or advanced editing. `MarkdownExportContract` is a production boundary backed by `swift-markdown`; it validates the title/heading hierarchy, table headers and column consistency, block-parseability, newline normalization, and optional deterministic page markers. The writer escapes table pipes and normalizes embedded line breaks. Focused `MarkdownContractTests` cover the demo AST, hostile table content, stable page markers, and malformed structure; Markdown import/editor remains out of scope.
- [ ] Snapshot-test HTML/Markdown across all fixture classes.

### 2.3 DOCX, CSV, JSON, and audio

- [x] Replace hand-rolled ZIP concerns in DOCX generation with ZIPFoundation, validate generated DOCX parts, and preserve headings/tables/alt text where OOXML permits. `DOCXPackageValidator` checks required parts, XML well-formedness, content types, relationships, and the main document contract; `DOCXWriterTests` covers generated, missing-part, and malformed-package cases. Independent desktop-consumer/manual QA remains open.
- [x] Retain CSV formula neutralisation; add locale/newline/quote and malformed-table tests.
- [x] Version the JSON schema, make source URL/text-snippet redaction explicit, and provide a schema document.
- [x] Make audio export use the selected speech voice/language rather than hard-coded `en-US`; include cancellation/progress and verify generated media metadata. `AudioExportService` accepts the selected voice identifier and document language, reports deterministic lifecycle progress (`preparing`/`synthesizing`/`completed`/`cancelled`), removes partial files on failure/cancellation, and validates non-empty AAC output metadata (frame length, sample rate, and channel count). `AudioExportServiceTests` covers the public progress/error contract; actual system speech synthesis remains a manual macOS media/voice gate because AVSpeechSynthesizer output and installed voices are host-dependent.

### 2.4 Readable PDF and PDF/UA direction

- [x] Keep the current output labelled `Readable PDF`.
- [ ] Research whether the required PDF structure tree, marked content, language, title, alt text, table semantics, and reading-order information can be created and validated reliably with the supported Apple APIs.
- [ ] Build a small prototype using a fixture corpus before exposing a “PDF/UA-oriented” option.
- [ ] Integrate an external validator only when its license, redistribution model, automation environment, and known limitations are approved.
- [ ] If validation cannot be automated/reliable, retain tagged HTML as the accessibility export and document the limitation plainly.

**Exit gate for Phase 2:** Every format has fixture-based output tests and a capability matrix. “Ready” statuses have a defined validator/review prerequisite.

---

## Phase 3 — Local Library, Search, and Retention (M2)

**Goal:** Evolve recents into a privacy-preserving local library without turning PageLumen into a server-backed document-management system.

### 3.1 Choose the persistence/search implementation

Perform a one-sprint spike comparing the current SwiftData implementation and GRDB-backed SQLite:

- Dataset sizes: 50, 500, and 5,000 document metadata entries; realistic OCR text bodies excluded/included.
- Queries: title/full-text, recent, by source type, unresolved findings, date, and saved review preset.
- Constraints: migrations, background writes, cancellation, FTS quality, encrypted-at-rest option, app sandbox, SwiftUI observation, backup/retention, and binary size.

**Decision rule:** keep SwiftData for small metadata-only recents. Adopt GRDB only when local full-text indexing, migrations, or performance evidence makes it materially better. Do not maintain two production stores indefinitely.

### 3.2 Implement the selected library

- [x] Create a `DocumentRepository` protocol that returns document metadata and source-derived data separately.
- [x] Store document text in a local index only when the person enables “Keep searchable local copies.” Default retention must be an explicit product decision documented in onboarding.
- [x] Support delete-one, delete-all, remove-index-only, and reveal storage size. Delete-one/delete-all and storage-size reporting are shipped; disabling searchable copies now clears the active search index/results while retaining recent documents and source files. Regression tests cover both boundaries.
- [x] Reveal the local library store's measured on-disk size in Settings; source files are excluded.
- [x] Add a local-library search UI with result snippets, page/block location,
  keyboard-accessible result buttons, explicit searchable-copy gating, and
  deep-link navigation into Review.
- [ ] Build migration and rollback tests before release. If a migration fails, preserve the old store, create a backup, and offer recovery rather than silently deleting data.

### 3.3 Finder and system workflows

- [ ] Implement Finder Quick Action / Share support for selected PDFs and images. App Intents and the AppKit open-file delegate now bridge Finder/open-file and Shortcut requests into the normal security-scoped import path; Finder extension/share-sheet packaging and participant validation remain open.
- [ ] Add Quick Look thumbnails/previews only after verifying sandbox and performance behaviour.
- [ ] Add watch-folder support only with explicit folder selection, a visible enable/disable toggle, security-scoped bookmark handling, and per-file confirmation/error reporting. Bounded scanning, bookmark security, polling monitoring, Settings enable/disable, and explicit Import/Ignore confirmation are now implemented; richer per-file failure detail remains open.
- [x] Add a small set of App Intents: open a selected document, import, search local library, read unresolved findings, get the latest retained summary, and export tagged HTML. The implementation is bounded to retained local documents, caller-provided export URLs, and notification-based open actions; `AppIntentExportTests` covers metadata-only entities, summary empty/populated behavior, the searchable-copy retention boundary, unresolved-finding filtering, open-action payloads, and typed Tagged HTML validation failures.

**Exit gate for Phase 3:** Search uses local-only data, retention is understandable and reversible, and App Intent/Quick Action flows have no permission or data-loss surprises.

---

## Phase 4 — Apple Intelligence and Current macOS Capabilities (M3)

**Goal:** Add genuinely useful on-device assistance without weakening trust or local-first privacy.

### 4.1 Intelligence policy and UX

- [x] Add an `IntelligenceMode` setting: `Off`, `Apple Foundation Models`, and future `Downloaded local model`. It defaults to Off, migrates the legacy opt-in boolean, and supports a locally retained per-document opt-out.
- [ ] Show availability, expected privacy boundary, device requirement, input scope, and failure state before execution.
- [ ] Never make a generative result appear indistinguishable from extracted source text.
- [x] Provide “Copy with citations,” “Insert as draft,” “Replace selected description after review,” and “Discard” actions; no unattended edits. The Summary workspace now holds a cited review draft separately from extracted source and requires an explicit action for insert, selected-block replacement, or discard.
- [ ] Offer a per-document “do not use intelligence” control for sensitive material.

### 4.2 Foundation Models adapter

**Files:** evolve `IntelligentExplainer.swift`, `ExplanationEngine.swift`, `DocumentStore.swift`, Settings, tests

- [x] Replace empty-string error swallowing with `IntelligentExplainerResult` and visible unavailable/model-not-ready states; legacy string methods remain compatible while the typed path preserves failure reasons.
- [ ] Use structured generable output for summaries and descriptions: body, cited page/block IDs, uncertainty notes, unsupported claims, and suggested review actions.
- [x] Add a privacy-safe `GroundedIntelligenceResult` envelope for summaries. Generated results carry deterministic page/block citations plus uncertainty notes; unavailable/failed results carry no source excerpts. The adapter uses bounded source blocks and explicitly reports omitted-block scope. Foundation Models `@Generable` wiring and suggested review actions remain open.
- [ ] Pass only bounded, selected, source-labelled context. The current prefix-bounded adapter reports omitted blocks; selection-aware prompting and omitted page/section labels remain open.
- [ ] Support a deliberate “summarise selection,” “explain table,” “describe figure,” “study notes,” and “compare passages” set before adding an open-ended chat interface.
- [ ] Preserve session/model/provider metadata in provenance but do not persist full prompts unless the person opts in.
- [ ] Provide a deterministic fallback `ExplanationEngine` result for unsupported Macs and model failures.

### 4.3 Evaluation harness

- [ ] Create a consented evaluation corpus separated from product documents.
- [ ] Define task-specific measures: citation precision/recall, unsupported-claim rate, user-correction rate, description usefulness, latency, availability failure rate, and energy/memory cost.
- [ ] Include adversarial documents: incorrect OCR, misleading captions, multiple conflicting values, hidden text, charts without values, multilingual content, and sensitive legal/medical-like samples.
- [ ] Add a human-review rubric with accessibility advisors. A feature cannot graduate from experimental mode based solely on automatic metrics.
- [ ] Set launch thresholds before implementation begins; record every model/Xcode/macOS version used for an evaluation run.

### 4.4 App Intents and on-screen awareness

- [ ] Promote user-recognisable document and finding concepts to `AppEntity` types, with privacy-safe display representations.
- [ ] Use intents for bounded actions only; never make all local document text generally discoverable by default.
- [ ] Evaluate newer entity schemas/view annotations only after confirming they expose no unwanted private context.
- [ ] Test intents with empty library, revoked permissions, unsupported macOS, and a disabled-intelligence preference. Deterministic empty-library/entity and retention-gate coverage is now present in `AppIntentExportTests`; revoked-permission, unsupported-macOS, and disabled-intelligence participant/system gates remain release work.

**Exit gate for Phase 4:** Every AI result has citations or an explicit inability-to-cite warning, AI is opt-in, evaluations meet predeclared thresholds, and disabled/unsupported paths are fully functional.

---

## Phase 5 — Open-Source Integration Program (M2–M4)

Third-party code must be adopted only through a small, auditable decision record. Every integration needs: pinned version, license notice, software bill of materials entry, update owner, security advisory process, test scope, binary-size impact, removal strategy, and privacy statement.

### 5.1 Adopt now: ZIPFoundation

**Repository:** `weichsel/ZIPFoundation` — MIT  
**Use:** DOCX package creation/inspection, safer archive handling, validation, progress, and cancellation.

- [ ] Add as an SPM dependency to the app/core target that owns DOCX output; pin a reviewed release rather than a branch.
- [x] Replace low-level archive assembly incrementally behind a `DOCXArchiveWriting` protocol.
- [x] Add generated-document tests that inspect required OOXML parts.
- [ ] Open the generated output with an independent consumer in manual QA.
- [ ] Update third-party notices and validate no unnecessary archive paths/data are retained.

Current checkpoint: ZIPFoundation is already resolved for the shipping app target;
`DOCXArchiveWriting` now isolates archive framing, validates package paths, and
`DOCXPackageValidator` performs deterministic XML, content-type, relationship,
and required-part checks in the core target. The focused DOCX suite covers
archive output, OOXML parts, malformed/missing package failures, escaping, and
delegation (10/10). Independent Word/LibreOffice consumer review remains an
explicit manual gate and is not claimed here.

**Why now:** It is a contained replacement for a reliability-sensitive custom implementation.

### 5.2 Adopt now: swift-snapshot-testing (test target only)

**Repository:** `pointfreeco/swift-snapshot-testing` — MIT  
**Use:** Visual and textual golden tests for review UI, light/dark appearance, large text, and export output.

- [ ] Add only to test targets; do not link it into the shipping app.
- [ ] Establish stable macOS CI renderer constraints and an explicit snapshot-recording procedure.
- [ ] Start with export JSON/HTML/Markdown snapshots and a small number of view snapshots; do not use screenshots as a substitute for accessibility testing.
- [ ] Require reviewer approval for snapshot updates accompanied by a rendered diff.

### 5.3 Evaluate: GRDB.swift

**Repository:** `groue/GRDB.swift` — MIT  
**Use:** SQLite migrations, FTS5 full-text local search, observation, and optional SQLCipher-compatible path.

- [ ] Run the Phase 3 spike before dependency adoption.
- [ ] If selected, use GRDB as the sole repository implementation; do not duplicate production truth in SwiftData and GRDB.
- [ ] Enable FTS only for user-approved local searchable copies. Design deletion/index rebuild behaviour first.
- [ ] Evaluate encryption-key storage in Keychain and recovery implications before claiming encryption at rest.

**Why not now:** Current recents do not prove a full-text SQLite dependency is necessary.

### 5.4 Evaluate: swift-markdown

**Repository:** `swiftlang/swift-markdown` — Apache-2.0  
**Use:** parse, inspect, normalise, and safely edit Markdown; groundwork for Markdown import and high-fidelity export validation.

- [x] Introduce only if implementing Markdown import/editor or AST-level export validation. AST-level export validation is now implemented in `Sources/PageLumenCore/MarkdownExportContract.swift`.
- [x] Keep the deterministic string writer behind the validation boundary; the AST-backed output tests prove the current writer's structural correctness without introducing destructive AST rewrites.
- [ ] Define dialect support and preserve unsupported syntax without destructive rewrites.

### 5.5 Experimental only: MLX Swift and swift-transformers

**Repositories:** `ml-explore/mlx-swift-lm` / `mlx-swift`, MIT; `huggingface/swift-transformers`, Apache-2.0  
**Potential use:** optional local vision-language or specialist language models for chart/figure descriptions and domain-specific assistance on Apple silicon.

- [ ] Do not add these to the default product pipeline.
- [ ] Build a separate prototype target or internal feature branch first.
- [ ] Require model cards, model-license review, download size estimate, source/repository disclosure, explicit download consent, storage location, progress/cancellation, offline removal, and device capability checks.
- [ ] Compare against Apple Foundation Models on the same evaluation corpus. Prefer the option with lower unsupported-claim rate and lower operational cost, not merely more fluent prose.
- [ ] Keep Intel Macs and unsupported Apple-silicon configurations on deterministic non-AI fallbacks.

### 5.6 Optional external provider: Stirling-PDF

**Repository:** `Stirling-Tools/Stirling-PDF` — open-core; verify the exact
release license and community/proprietary module boundaries before shipping.

**Use:** Optional local REST/MCP-backed advanced PDF operations such as
compression, merge, split, rearrange, redaction, signing, conversion, and
repeatable pipelines. See [`docs/stirling-pdf-integration.md`](../../stirling-pdf-integration.md).

- [x] Stage A capability probe: injectable HTTP transport, metadata-only GET,
  distinct availability/authentication/timeout/cancellation/TLS/malformed
  response states, and loopback-first endpoint validation. No document upload
  or mandatory dependency is introduced. Focused fake-transport tests pass.
- [ ] Do not embed Stirling's Java/Spring/React/Tauri application or require a
  server for the default PageLumen install.
- [x] Add a `PDFOperationsProvider` protocol with a network-free native PDFKit
  validation provider as the default and a separately enabled Stirling
  compress/merge adapter. Focused `PDFOperationsProviderTests` pass (4/4);
  Vision-backed extraction remains in the existing native processing path.
- [ ] Require an explicit local base URL, Keychain-held API key, capability
  probe, privacy-mode check, and per-operation confirmation before upload.
- [x] Start with a cancellable compress operation; validate the returned PDF
  before offering replacement, and write output atomically. Stage B is covered
  by `StirlingPDFCompressor`, `StirlingPDFAtomicOutput`, and the focused
  `StirlingPDFProviderTests` suite (10/10 passed).
- [x] Add the first bounded merge operation after Stage B: repeated
  `fileInput` multipart inputs, strict count/total-size limits, cancellation,
  typed errors, PDFKit validation, and focused fake-transport tests (13/13
  Stirling provider tests pass). Rearrange and typed pipelines remain separate
  follow-up work.
- [ ] Keep remote endpoints disabled by default; require HTTPS and an explicit
  advanced warning for non-local hosts.
- [ ] Complete license, security, endpoint, source-content retention, and
  redistribution review for the exact Stirling version before distribution.

**Why optional:** Stirling expands PDF coverage substantially, but a bundled
server would add Java/Docker lifecycle, network, install-size, licensing, and
privacy complexity to a native macOS reader.

### 5.7 Defer: Argmax OSS Swift / WhisperKit

**Repository:** `argmaxinc/argmax-oss-swift` — MIT  
**Potential use:** local transcription/audio intake or higher-quality downloadable speech models.

- [ ] Do not adopt for the present document-to-speech workflow; AVFoundation already handles the core need without model download management.
- [ ] Revisit only when PageLumen adds audio/lecture import, spoken-note capture, or a demonstrated need for higher-quality local speech.

### 5.8 Dependency governance

- [x] Add `THIRD_PARTY_NOTICES.md`, a dependency inventory, and an SPM lock/review policy. The current inventory is maintained in the repository root; `Package.swift` pins the Markdown dependency exactly and records lower bounds for the two other packages, with resolved versions reviewed before release.
- [ ] Add Dependabot or an equivalent update-review workflow after confirming it does not alter release branches automatically.
- [x] Add a license/security review checklist to `CONTRIBUTING.md`.
- [ ] Verify new packages work in sandboxed, offline runtime conditions after initial resolution.

**Exit gate for Phase 5:** Every adopted package has a documented user outcome, license, owner, pinned version, tests, and removal plan. No model-downloading package is enabled without explicit user action.

---

## Phase 6 — Accessibility Depth and User Workflows (M3)

The current code-backed interaction audit is recorded in
[`docs/ui-ux-audit-2026-08-20.md`](../../ui-ux-audit-2026-08-20.md); its manual
participant and physical-device gates remain open.

**Goal:** Validate with the people PageLumen is intended to help and reduce remediation time.

- [ ] Conduct structured usability sessions with VoiceOver users, low-vision users, dyslexic readers, students, researchers, educators, and legal professionals. Obtain consent; do not retain user documents beyond the agreed research process.
- [ ] Add reading modes: focus/line highlighting, spacing controls, typography choices, speech word/paragraph highlighting, speed controls, and saved reading preferences.
- [ ] Add an assistive-technology regression checklist: VoiceOver rotor/headings, full keyboard workflow, Switch Control where relevant, large text, contrast/transparency/motion, and pointer/zoom behaviour.
- [ ] Add per-export remediation checklist, unresolved-risk summary, and a clear “manual review still required” explanation.
- [ ] Add quote capture with page/block citations and a “copy accessible excerpt” command.
- [ ] Add document comparison for source vs OCR and user-selected document revisions; never use AI comparison without provenance/citation output.

**Exit gate for Phase 6:** Participant evidence identifies improved time-to-correct and successful task completion; critical accessibility issues are triaged before release.

---

## Phase 7 — Release Engineering, Privacy, and Quality Gates (M5)

### 7.1 Test strategy

- [ ] Keep existing unit tests and add protocol-fake tests for every external/platform boundary.
- [ ] Add XCUITest coverage for import, review queue, export confirmation, settings, dark/light appearance, and denied permission recovery.
- [ ] Add fixture-corpus regression tests and performance baselines separate from fast unit tests.
- [ ] Add snapshot tests only where they are stable and actionable.
- [ ] Run tests on the minimum supported macOS and current macOS/Xcode; manually test Apple Intelligence on eligible and ineligible Macs.

### 7.2 Privacy and security

- [x] Add and audit `PrivacyInfo.xcprivacy`: the manifest declares only UserDefaults reason `CA92.1`; the source/dependency audit found no other current required-reason API categories, tracking, analytics, or model-download SDKs. The audit is documented in `docs/privacy.md` and must be rerun for future platform/dependency additions.
- [ ] Reconcile App Store privacy nutrition labels with actual network/data behaviour before submission.
- [x] Update `docs/privacy.md` for library retention, model downloads, Apple Intelligence, App Intents, capture, Stirling opt-in operations, required-reason API audit, and export anonymisation.
- [ ] Provide a real contact channel in `SECURITY.md` and a vulnerability-handling policy.
- [x] Add deterministic malformed PDF/image robustness tests. Import failures expose only a safe last-path-component PDF label (or a generic image message), never the local path or payload; property-based fuzzing remains a future hardening option.

### 7.3 Distribution evidence

- [ ] Add CI jobs for package tests, Xcode build, lint, fixture corpus, and release-manifest validation. Existing CI runs package tests and Xcode build; the local `make quality`/`script/quality_gates.sh` boundary now validates whitespace, the privacy manifest, and required baseline/plan artifacts. Workflow integration is prepared but cannot be published with the current GitHub OAuth token because it lacks `workflow` scope; fixture-corpus and signed release-manifest validation remain open.
- [ ] Before release, create a signed archive, validate entitlements and sandbox behaviour, export the distribution artifact, notarize if distributing outside the Mac App Store, and separately validate the submitted App Store build if applicable.
- [ ] Do not call a local archive, notarized DMG, upload, TestFlight processing, or App Review submission a live-store release; report each state separately.
- [ ] Run a final physical-Mac smoke test: PDF, image, clipboard, selected capture, window capture, translation, review queue, each export, deletion/retention controls, VoiceOver, light/dark appearance, and offline behaviour.

**Exit gate for Phase 7:** A versioned release checklist includes command output/artifact identifiers, privacy answers, manual accessibility results, rollback plan, and accurate external-state wording.

---

## 6. Proposed Pull-Request Breakdown

1. **PR 1 — Truthful feature claims and system appearance**: translation gating, readable-PDF naming, system appearance, documentation correction.
2. **PR 2 — Recoverable persistence**: remove `fatalError`, status UX, fallback/migration tests.
3. **PR 3 — Consentful capture**: picker, Info.plist purpose string, cancellation/errors, temp cleanup.
4. **PR 4 — Streaming import engine**: memory-bounded rendering/OCR and benchmark corpus harness.
5. **PR 5 — Provenance and review findings**: typed model, migration, queue, keyboard navigation.
6. **PR 6 — Export contract**: capability matrix, validator, tagged HTML and DOCX strengthening, ZIPFoundation.
7. **PR 7 — Library/search spike and decision record**: SwiftData vs GRDB benchmark; implementation only after approval.
8. **PR 8 — Apple Intelligence experimental feature**: opt-in adapter, cited structured results, evaluation harness.
9. **PR 9 — System workflows**: App Intents, Quick Action, optional Quick Look/watch folders.
10. **PR 10 — Release-quality program**: UI tests, privacy manifest, CI/release gates, manual validation documentation.

Each PR must list affected privacy boundaries, data migrations, test evidence, feature-flag state, and rollback path.

## 7. Decision Log Template

Use this template for every material product or dependency decision:

```markdown
## Decision: <name>
Date:
Owner:
Status: proposed | accepted | rejected | superseded

### Problem

### Options considered

### Evidence

### Decision and rationale

### Privacy, licensing, and operational impact

### Rollout / rollback

### Verification
```

Initial decisions required before work begins:

1. Is translation mandatory for the next release, or should it be temporarily removed until fully implemented?
2. What local-retention default is acceptable for extracted document text?
3. What quality thresholds must Apple Intelligence meet before leaving experimental mode?
4. Does user research justify GRDB/FTS, or should SwiftData remain the only store?
5. Is full PDF/UA a product commitment requiring specialist validation, or should PageLumen focus on strong HTML/DOCX remediation exports?

## 8. Global Definition of Done

A milestone is complete only when all applicable conditions below hold:

- [ ] Code has unit/integration/UI coverage appropriate to risk and passes on supported OS paths.
- [ ] New platform APIs are availability-gated and tested with deterministic fallbacks.
- [ ] User-facing claims, documentation, and export labels match actual implementation.
- [ ] Privacy/retention/download/capture behaviour is explicit, consentful, and documented.
- [ ] Accessibility review covers keyboard, VoiceOver, appearance, contrast, text size, motion, and transparency.
- [ ] New dependencies have a decision record, license notice, pinned version, and removal plan.
- [ ] Performance and corpus baselines show no unapproved regression.
- [ ] A release gate records actual archive/upload/review state without conflating local and external proof.

## 9. Immediate Next Action

Start with **PR 1** and **PR 2** only. They remove false translation output, prevent a persistence-related app crash, make visual accessibility more native, and align product claims before investing in additional intelligence or dependencies.
