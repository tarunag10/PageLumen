# PageLumen UI/UX Revamp Audit — 2026-08-31

## Scope

This audit covers the native macOS workflow from launch through Add, Process,
Review, and Listen & Export, with emphasis on Apple Human Interface
Guidelines, accessibility, responsive layout, truthful status, and recovery
behavior.

The authoritative checkout was `main` at `cdbbd83` before this work. Existing
UI audit evidence was reviewed first; this document records the additional
revamp slice rather than claiming that manual acceptance has been completed.

## Implemented in this slice

- Replaced the fixed sidebar `HStack` shell with a native resizable
  `HSplitView`; the sidebar now has minimum, ideal, and maximum widths.
- Made the workflow header horizontally adaptive so step navigation does not
  clip at constrained widths, with visible scroll indicators when the steps
  exceed the available width.
- Added a document-aware navigation title instead of presenting the app name
  as the content title.
- Moved export-format controls into a prominent “Save your document” section
  immediately after export status.
- Made export availability reasons part of each format control’s accessible
  value, so disabled exports explain the prerequisite to keyboard and
  VoiceOver users.
- Corrected export status banners so blocked, failed, cancelled, unavailable,
  and required states use warning treatment instead of a misleading success
  checkmark.
- Centralized navigation availability reasons so Review and Export explain
  whether import is missing or processing must finish; review keyboard commands
  now disable consistently when there is no actionable issue.
- Kept the existing export identifiers and save behavior stable.
- Limited review-block selection to the block header, avoiding competition
  between card selection, editing, toggles, and reorder controls.
- Added a VoiceOver accessibility action for selecting a review block.
- Added an explicit keyboard-focusable “Select this block” control to each
  review block header, with a selected accessibility trait and focus handoff
  when issue or preview navigation selects a block.
- Kept overflow indicators visible for review and export command rows so
  horizontal scrolling is discoverable.
- Exposed all review issues in the issue navigator instead of truncating to
  twelve without explanation.
- Added validation for table header row/column indexes, including bounds and
  inline accessible error feedback.
- Corrected the table grid’s literal `(rowIndex)` display bug.
- Prevented processing page cards from bypassing the store’s navigation policy
  while processing is active.
- Corrected onboarding’s misleading “Show this on launch” action to “Maybe
  later”.
- Derived the sidebar status dot from failure, warning, cancellation, and
  success text instead of always showing success.
- Made the persistent sidebar status a combined accessible element and label
  empty documents as “No document loaded” instead of presenting the placeholder
  title as a real document.
- Added a native empty Review state with a direct Open Files recovery action,
  preventing deep links or restored state from landing on a blank editor.
- Corrected the translation availability message to match the macOS 26 gate.
- Replaced the technical PRD Coverage Settings section with concise, user-
  facing About PageLumen content.
- Made shared panel/material behavior honor macOS Increase Contrast in addition
  to the app preference, while retaining Reduce Transparency fallbacks.
- Added native `ContentUnavailableView` recovery states for empty Review and
  empty Export, each with a direct Open Files action and a deterministic UI-test
  launch seam.
- Made the Review page preview responsive within the split view: its canvas
  scales between compact and expanded pane widths while preserving the source
  aspect ratio and keeping reading-order overlays aligned.
- Made the Processing header's progress indicator flexible instead of fixed
  width, exposed its page/file progress as an accessibility value, and allowed
  longer status messages to wrap instead of silently truncating.
- Replaced harmful one-line truncation in the workflow, Review, and Processing
  descriptive headers with bounded two-line wrapping for compact windows and
  larger text sizes.
- Separated Review page selection from the title/description/Continue row so
  the primary action and document context remain readable at compact widths
  and larger text sizes.
- Centralized the processing gate in `DocumentStore.canNavigate`: Review is
  unavailable until processing finishes, including partial-document snapshots,
  and all disabled navigation surfaces now explain that prerequisite.
- Closed non-button Review entry points at the same store boundary: validated
  Review deep links, search navigation, and accept/reject/reopen actions now
  refuse to operate on a partial document while processing is active.
- Added the same prerequisite guard to the central export dispatcher, so
  programmatic or future command routes cannot open DOCX, audio, translation,
  or other export handlers for an empty or actively processing document.
- Prevented recent-library and completed-batch selection from replacing the
  active document while another import is running; the current processing
  workflow now remains the single source of truth until it finishes or is
  cancelled.
- Improved disabled export explanations: imported documents blocked by HTML,
  tagged-HTML, or readable-PDF validation now name the first remediation
  finding instead of incorrectly saying that import or processing is missing.
- Prevented Open Files, Paste Image, and screen-capture entry points from
  silently cancelling or replacing an active import; the user must finish or
  explicitly cancel the current operation first.
- Made library-selection APIs report success, and stopped search-result
  navigation from announcing “Opened” when active-processing protection rejects
  the switch.
- Reduced export-format button emphasis to peer-level bordered controls so the
  format grid does not compete with the page-level Continue and save actions.
- Allowed key document and batch filenames to wrap to two lines in the sidebar,
  and allowed the Review step heading to wrap at compact widths and larger text
  sizes instead of losing document context.
- Marked Home error/recovery, Processing status/recovery, and Export status
  surfaces as frequently updating accessibility elements so VoiceOver users
  receive state changes through the same workflow surfaces as sighted users.
- Aligned Review command-menu enablement with the processing gate and added the
  same protection to block- and page-review mutations, preventing keyboard or
  programmatic actions from editing a partial document.
- Aligned batch, recent-document, library-search, and outline sidebar actions
  with the same processing gate; outline navigation now uses validated Review
  selection instead of directly mutating destination state.
- Closed remaining document-editing bypasses at the store boundary: demo
  loading, text/table/figure edits, block ordering, undo/redo, and reviewed
  draft insertion now refuse to mutate a document during active processing.
- Added matching guards to Review/Export transitions and disabled Home import
  actions while an import is active, keeping the visible workflow state and
  mutation policy consistent.
- Added a shared review-editing guard for text, table, figure, ordering,
  undo/redo, and reviewed-draft mutations; this prevents partial OCR snapshots
  from being edited through keyboard, drag, or programmatic paths.
- Added defensive disabled states to the mounted Review and Export editing
  surfaces, covering restored or deep-linked states where processing starts
  after those views are already visible.
- Made Add/Home unavailable while processing so users cannot leave the only
  screen that exposes cancellation and recovery; Processing remains reachable.
- Protected watch-folder candidate and failure recovery items from being
  removed when an active import rejects a new start, and prevented draft
  generation from using a partial document.
- Disabled Recognition and Intelligence settings during OCR and guarded
  Intelligence mode, document opt-out, and summary regeneration against
  partial-document mutation.
- Disabled watch-folder configuration while OCR is active and guarded monitor
  changes at the store boundary so pending candidates and failures cannot be
  cleared accidentally during processing.
- Disabled menu-bar capture actions during OCR while keeping the command to
  reopen the main PageLumen window available.
- Disabled Settings actions that can clear library state or jump into Review
  while OCR is active, keeping visible action availability consistent with the
  shared processing policy.
- Protected destructive Forget Recent and Forget All library actions from
  mutating persistence while an import is active; the UI now requires the
  current operation to finish or be explicitly cancelled first.
- Reflected the same rule in native toolbar, command-menu, and recent-document
  affordances by disabling controls that cannot safely interrupt active OCR.
- Strengthened the document revision fingerprint used by export-preview caching
  and asynchronous on-device summary generation. Same-document text, structure,
  confidence, and summary edits now invalidate stale work before it can be
  displayed or applied.
- Added an inline Home status banner for actionable import, clipboard, capture,
  unsupported-file, and cancellation messages so recovery feedback is visible
  in the active workspace, not only in the sidebar footer.
- Changed batch completion routing so an all-failed batch remains on Processing
  with its failure context; Review is entered only when at least one document
  completed successfully.
- Extended navigation and export readiness checks to reject partial snapshots
  from an all-failed batch, with explicit “Resolve the failed import” guidance.
- Added a Processing recovery panel with direct Open Files and Back to Add
  actions, and made failed page cards visibly unavailable with truthful
  accessibility hints.
- Added a direct regression that renders a preview, edits same-document source
  text, and verifies the updated text is returned rather than cached output.
- Made normal launch and Dock re-open behavior explicitly activate and bring a
  key SwiftUI window forward, including the deferred WindowGroup materialization
  path used by macOS UI-test launches.

## Verification evidence

- `xcodebuild -project PageLumen.xcodeproj -scheme PageLumen -destination
  'platform=macOS' -derivedDataPath /tmp/PageLumenDerivedData
  build-for-testing`: passed after the final code changes.
- `git diff --check`: passed.
- A fresh build-for-testing after the empty Export recovery change passed with
  Xcode when external SwiftPM/module-cache access was allowed.
- A fresh build-for-testing after the responsive preview change also passed;
  `git diff --check` remains clean.
- A fresh build-for-testing after the Processing header correction passed.
- A fresh build-for-testing after the dynamic-text correction passed, and
  `git diff --check` remains clean.
- A fresh build-for-testing after the Review header hierarchy correction
  passed.
- The focused `DocumentStoreTests.testNavigationAvailabilityExplainsMissingImportAndActiveProcessing`
  regression test passed after the shared processing gate correction.
- That focused regression test now also covers deep-link rejection during
  processing; it passed after the store-boundary hardening.
- Focused export-dispatch and navigation regression tests passed after the
  export prerequisite guard was added.
- Focused export and document-lifecycle regression tests passed after the
  active-processing switch guard was added.
- Focused export-readiness regression tests passed for validation-specific
  messaging and empty/in-progress dispatch rejection.
- Focused import-lifecycle regression tests passed for active-operation
  protection and document-switch protection.
- Focused library-selection and search-result regressions passed, including
  the existing successful-library-open path and the protected active-import
  path.
- Focused persistence/lifecycle regressions passed for active-import
  protection of Forget actions.
- Complete non-UI `PageLumenCoreTests` and `PageLumenTests` targets passed in
  a fresh Xcode run; this includes the current store, export, persistence, and
  document-lifecycle regression coverage. The optional LibreOffice consumer
  remains environment-aware as noted above.
- Fresh Xcode `build-for-testing` after the visible-affordance correction
  passed; `git diff --check` remains clean.
- Focused summary/export regression tests passed after the content-sensitive
  revision check; a fresh Xcode build-for-testing also passed.
- The direct same-document preview invalidation regression passed in Xcode.
- A fresh Xcode build-for-testing after the Home recovery-banner change passed;
  `git diff --check` remains clean.
- Injected-failure regression `testAllFailedBatchStaysOnProcessingForRecovery`
  passed, and a fresh Xcode build-for-testing passed after the routing change.
- The all-failed regression now also verifies Review/Export remain unavailable
  and expose the correct recovery message; it passed with a fresh Xcode build.
- Final rebuilt combined non-UI run passed: `xcodebuild ... test-without-building
  -only-testing:PageLumenCoreTests -only-testing:PageLumenTests -quiet` exited 0
  after rebuilding the test products. The cache test expectation was corrected
  to assert content-sensitive invalidation rather than stale same-document text.
- The post-launch-activation `build-for-testing` passed. A representative UI
  test reached the UI runner but failed before product assertions because the
  host reported `Authentication canceled. System authentication is running.`;
  this remains a host/runtime gate, not an application assertion failure.
- The final current-checkout combined `PageLumenCoreTests` and `PageLumenTests`
  run after the launch-window change also exited 0.
- A fresh `build-for-testing` after the export hierarchy, responsive title, and
  live accessibility-status changes exited 0; `git diff --check` remains clean.
- A fresh `build-for-testing` after the sidebar navigation-policy correction
  exited 0.
- A fresh `build-for-testing` after the mounted Review/Export disabled-state
  correction exited 0.
- The focused navigation regression and final complete Core/app test run passed
  after making Add/Home unavailable during active processing.
- The focused watch-folder recovery regression passed, and a fresh Xcode
  build-for-testing exited 0 after the recovery-ordering correction.
- The focused `testIntelligenceSettingsDoNotRegeneratePartialDocuments`
  regression passed after the settings boundary was added.
- The focused watch-folder preservation regression passed after guarding the
  monitor-setting transition; a fresh Xcode build-for-testing also exited 0.
- A fresh Xcode build-for-testing after the menu-bar capture affordance
  correction exited 0; `git diff --check` remains clean.
- Final current-checkout `PageLumenCoreTests` and `PageLumenTests` suites passed
  after the Settings action-state correction; the latest Xcode build-for-testing
  also exited 0.
- The complete current-checkout `PageLumenCoreTests` and `PageLumenTests`
  suites passed after the final navigation and mutation-boundary corrections.
- The focused processing-mutation regression and a final complete
  `PageLumenCoreTests` plus `PageLumenTests` run passed after closing the
  remaining editing and navigation bypasses.
- The focused `testReviewDecisionsDoNotMutateDocumentDuringActiveProcessing`
  regression passed after the Review mutation guard was added.
- The complete current-checkout `PageLumenCoreTests` and `PageLumenTests`
  suites passed after the Review mutation guard and command-menu alignment.
- The same injected-failure regression passed after the Processing recovery UI
  change, and a fresh Xcode build-for-testing passed.
- UI contract subset passed: home import actions, fixture review-to-export
  controls, and Settings privacy/appearance controls remained discoverable.
- The new empty Review/Export UI cases reached Xcode test launch, but the
  runner stalled while materializing the macOS UI-test worker and was stopped;
  their source-level seams and app build are verified, while those two runtime
  assertions remain unverified on this host.
- Representative UI cases pass in focused runs. Full-class execution still
  reports pre-assertion `Failed to activate application ... (current state:
  Running Background)` failures on this host; no product-level assertion is
  reached in those cases, so the full-class result remains unverified.
- `xcodebuild ... test -only-testing:PageLumenCoreTests
  -only-testing:PageLumenTests`: completed successfully after the optional
  LibreOffice consumer was made environment-aware. The consumer now skips when
  the installed wrapper cannot produce a PDF inside the app test container;
  deterministic DOCX package and system-unzip checks remain hard gates. The UI
  changes did not cause a compile or test-discovery failure.
- `swift test`: could not run in the sandbox because SwiftPM manifest
  compilation attempted a restricted user Clang module cache and then failed
  with `sandbox_apply: Operation not permitted`.
- Final source scan found only guarded workflow/setup destination assignments
  for Review and Export; no unguarded app navigation route remained.
- Final `git diff --check` passed; the current implementation remains
  uncommitted on `main` pending explicit commit/push direction.
- Fresh current-checkout verification at 05:39-05:40 BST: Xcode
  `build-for-testing` passed, followed by complete `PageLumenCoreTests` and
  `PageLumenTests` via `test-without-building` with exit code 0. Xcode emitted
  only destination/build-environment warnings; no test failure was reported.
- Found and fixed a remaining Settings-to-store bypass: changing the language
  hint could rewrite a partially processed document through the public helper.
  The importer still applies the preference to its private snapshots, while
  the public settings path now fails closed during processing. The focused
  regression passed, followed by a fresh build and complete Core/app suite at
  05:42-05:43 BST.
- Found and fixed a remaining sidebar selection seam: the `List(selection:)`
  binding now routes every destination change through `canNavigate`, so row
  disabled states cannot be bypassed by selection events during processing.
  Disabled workflow steps also expose their prerequisite as an accessibility
  hint. Fresh build-for-testing and the complete Core/app suites passed at
  05:43-05:45 BST.
- Found and fixed the early-processing recovery seam: when no OCR snapshot is
  available yet, Processing's Open Files and Back to Add actions now respect
  the active-processing gate; cancellation remains the available escape path.
  Fresh build-for-testing and complete Core/app suites passed at 05:45-05:47
  BST.
- The early-processing Open Files affordance now also renders disabled with an
  explanatory help string, avoiding an enabled-looking no-op. Final fresh
  build-for-testing and complete Core/app suites passed at 05:48-05:49 BST.
- Closed the matching race in the all-failed recovery banner: both its Open
  Files and Back to Add actions now re-check the processing gate at activation
  time. Fresh build-for-testing and complete Core/app suites passed at
  05:49-05:50 BST. A direct screenshot attempt reached the macOS login screen,
  so it is recorded as host-blocked rather than visual product evidence.
- Hardened `openDocumentPanel()` itself so command-menu, Dock/file-open,
  recovery, and future callers cannot present a new modal while OCR is active;
  they now receive the same finish-or-cancel status. Fresh build-for-testing
  and complete Core/app suites passed at 05:51-05:52 BST.
- Fixed launch-time external file opening: supported URLs are retained until
  the SwiftUI scene has mounted, while already-running scenes acknowledge only
  the specific delivered URL. Multi-file Finder opens therefore cannot be
  lost or duplicated at the app lifecycle boundary. Fresh build-for-testing
  and complete Core/app suites passed at 05:53-05:55 BST.
- Follow-up audit found that one-notification-per-file would still reject
  multi-file Finder opens once the first import began. External opens now queue
  one supported URL batch; the focused queue regression passed after removing
  unnecessary AppKit startup coupling from the test seam. Fresh build passed;
  the later full app-host run exited before test bootstrap (`signal trap`, exit
  65), while the isolated Core suite completed successfully. This latest app
  suite result is host-unverified, not claimed as a product failure or pass.
- The queue test seam was simplified further to avoid a custom AppDelegate
  initializer; the pure URL queue regression passed again and the app built
  successfully. Subsequent app-test attempts continued to fail before runner
  bootstrap, while the isolated Core suite completed and `git diff --check`
  remained clean.
- Closed the active-import external-open loss: `startImport` now reports
  whether it accepted a request; Finder/Dock batches remain pending when OCR is
  active and are drained after processing ends or is cancelled. The focused
  lifecycle and active-import regressions passed, a fresh build passed, and the
  final source scan plus `git diff --check` passed.
- Strengthened the active-import regression to assert the rejected `startImport`
  result explicitly. The focused lifecycle/processing regressions and the
  complete Core suite passed after this assertion; the app-host suite remains
  pre-bootstrap blocked by the previously observed host exit.
- Preserved the processing-budget prompt when another supported file arrives:
  new files append to the pending batch instead of replacing the original
  choice context. Fresh build-for-testing, focused import/lifecycle tests, and
  the complete Core suite passed after this change. `git diff --check` also
  passed.
- Deferred Finder/Dock batches now announce their queued state in the active
  workflow (`Queued N files; it will import after the current operation
  finishes.`), making the automatic follow-up explicit. Fresh build-for-testing
  and focused import/lifecycle regressions passed.
- Added a combined, frequently-updating accessibility element to the Review
  processing/low-confidence banner, completing the live-status treatment
  across Home, Processing, Review, and Export. Fresh build-for-testing and
  focused import/lifecycle regressions passed; the subsequent Core run was
  still live at observation timeout and is not claimed as complete.
- After exact test-process cleanup, a fresh combined Core/app invocation again
  exited 65 before test assertions (`TEST EXECUTE FAILED`); no product-level
  failing test was reported. The focused import/lifecycle tests and fresh build
  remain green, while the app-host bootstrap result remains environment-
  unverified.
- A stale manually launched PageLumen process was removed and the combined
  suite was retried from a clean app state; it again exited 65 before product
  assertions. This confirms the app-host bootstrap limitation is independent
  of the stale process. Focused tests and build remain the authoritative green
  evidence for the latest changes.
- Final `startImport` caller audit confirms external-open paths inspect the
  acceptance result and retain rejected batches; ordinary UI and watch-folder
  callers remain intentionally fire-and-forget because their entry-point
  guards and status surfaces handle rejection. `git diff --check` remains
  clean.
- Centralized normal UI workflow transitions in `DocumentStore.navigate(to:)`.
  Sidebar selection, workflow pills, Processing recovery/page actions, Review
  Continue, and Export Back now share one navigation policy and failure
  message; direct assignments remain only for import completion, restored/test
  setup, or validated store internals. Fresh build and focused navigation
  regression passed.
- Fresh verification after the final source audit: `build-for-testing` passed,
  and focused `PageLumenTests` passed for navigation availability, active-import
  entry-point protection, external-open batch preservation, and export guards.
  `git diff --check` remains clean. No live Xcode test or app process remained
  running after verification.
- The complete `PageLumenCoreTests` suite also passed in a clean test session
  (56.655 seconds). This verifies the document, OCR, export, persistence, and
  accessibility-data foundations; it does not replace live UI acceptance.
- A follow-up audit found that Privacy mode, export defaults, and review
  presets could still be changed while processing. Those settings now use
  store-backed mutation gates, and the Settings controls are disabled during
  active processing. The new processing-lock regression and a fresh
  build-for-testing both pass after correcting the initial binding refactor.
- The full Swift package run initially exposed an outdated single-file Finder
  notification expectation after the multi-file queue change. AppDelegate now
  emits the batch `urls` payload and preserves the legacy `url` key for a
  single file. The corrected full package suite passed all 346 tests, and the
  Xcode build plus focused bridge/settings regressions also passed.
- A current runtime preflight reports macOS 26.6 but no usable WindowServer or
  `sysmond` session, so live UI interaction remains unavailable. It also finds
  the existing archive fails deep code-signature verification; that is a
  distribution artifact issue and is not treated as proof against the source
  UI revamp.
- A responsive-layout audit found rigid Review popover, filter, block-type,
  and Export preview widths that could crowd larger text or narrower windows.
  These now use bounded minimum/ideal/maximum sizing. A fresh Xcode
  build-for-testing and the complete 346-test package suite passed afterward.
- The current coverage run completed successfully and refreshed
  `docs/coverage-report-2026-08-20.txt`. It reports 40.99% line coverage
  overall; the uninstrumented SwiftUI view surfaces are intentionally covered
  by the manual GUI gate, while the app-store queue seam now includes
  restore/remove ordering coverage. Coverage is diagnostic and does not claim
  VoiceOver or TCC behavior.
- A final dynamic-text audit relaxed one-line constraints on watch-folder
  filenames and Review status values, using two-line wrapping and middle
  truncation where appropriate. The fresh Xcode build-for-testing and full
  346-test package suite passed after this change.
- A fresh arm64 Debug app bundle was built with Xcode at
  `/tmp/PageLumenDerivedData/Build/Products/Debug/PageLumen.app`, copied to
  `/Applications/PageLumen.app`, and sealed with a local ad-hoc signature.
  `codesign --verify --deep --strict` passes for the installed bundle. This is
  an installable local test build, not a Developer ID, notarized, or
  distribution-ready artifact.

## Remaining acceptance gates

The following require a live interactive macOS session and are not proven by
source inspection or build-for-testing:

1. VoiceOver rotor order and activation for the sidebar, workflow steps,
   review block header, editors, status banners, and export controls.
2. Full Keyboard Access, visible focus rings, and keyboard selection of review
   blocks and table cells.
3. Light, dark, Increase Contrast, Reduce Transparency, Reduce Motion, and
   large-text behavior at the minimum supported window size.
4. Real import, OCR cancellation, denied Screen Recording recovery, native
   save panels, speech playback, and every export format.
5. A screenshot or participant review of the revised shell at compact and
   expanded widths.

These gates should be recorded as observed outcomes before calling the UI
release-ready.
