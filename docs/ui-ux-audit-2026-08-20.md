# PageLumen UI/UX Audit — 2026-08-20

## Outcome

The native macOS shell now has an explicit, keyboard-friendly path through Add → Process → Review → Export. High-value actions are wired to real store operations, invalid empty-state transitions are blocked, and status changes are visible in the export workflow.

## Changes shipped in this phase

- Processing page cards are actionable buttons. Selecting a page opens Review at the corresponding page and exposes an explicit VoiceOver hint.
- Review search now supports both Next Match and Previous Match, with wrap-around across matching pages.
- Multi-file drop imports synchronize provider callbacks with a lock and sort filenames deterministically before starting the batch.
- Workflow step pills expose selected/available state to VoiceOver and prevent Review/Export navigation before a usable document exists. Export is disabled while processing is active.
- Continue from Review is disabled while processing is active and includes a help description.
- Export status and failure feedback is surfaced as a visible, accessible banner.
- Privacy mode now has an effect: translated export is blocked while enabled and the Settings toggle reports the state change.
- The menu-bar Open PageLumen Window action explicitly opens the `main` window, including after the window was closed.
- Toolbar actions include native help text.
- The Apple Intelligence preference now regenerates the active summary and reports the selected mode.

## Design and interaction baseline

- Dark-first surfaces use the existing AccessibleStyle tokens, including Boost Contrast and Reduce Transparency fallbacks.
- Controls retain native SwiftUI/AppKit semantics instead of custom hit targets wherever possible.
- Every new action has a visible label, a system-image affordance, or an accessibility label/hint.
- Search and review operations remain local and deterministic; no network service is introduced by this UI pass.

## Manual acceptance matrix

The following require an interactive macOS pass and are intentionally not claimed by automated tests:

1. VoiceOver can reach every toolbar, sidebar, workflow step, review action, export format, and status banner.
2. Keyboard-only traversal shows a visible focus ring and activates Open, Paste, Capture, page cards, search navigation, review issue navigation, and export actions.
3. Large text remains usable at multiple accessibility sizes without clipped controls.
4. Reduce Motion and Reduce Transparency preserve readable hierarchy and do not introduce unexpected animation/materials.
5. Boost Contrast preserves visible borders and selected states.
6. Empty document, active import, failed import, unsupported translated export, audio export, and a closed main window all provide clear recovery feedback.
7. Repeated search navigation lands on the expected page and wraps in both directions.

These gates are tracked separately from local unit/build evidence in `docs/manual-acceptance-2026-08-20.md`.

## Highest-value remaining polish

1. Add XCUITest coverage for the end-to-end import → review → export path, denied screen-capture permission recovery, library deletion confirmation, and light/dark appearance.
2. Run the manual acceptance matrix with VoiceOver, keyboard-only, Switch Control, large text, contrast/transparency, and reduced-motion settings.
3. Add a visible progress/cancellation affordance for long OCR and speech operations where the platform permits it, then verify that every disabled control has a reason exposed to VoiceOver.
4. Record rendered snapshot diffs for the supported appearance and text-size matrix; snapshots are supplementary and do not replace assistive-technology testing.

This audit is code-backed. The participant and physical-device gates remain intentionally unverified until a manual test session is performed.

## Screenshot-driven remediation — 20 August 2026

The supplied review screenshots exposed defects that were not visible in the deterministic UI contracts:

- The custom dark palette was rendered alongside native light-system controls, producing black labels on dark surfaces.
- Review controls were placed in one fixed-width row and clipped at ordinary window widths.
- The review split view required more width than the content area, forcing overflow.
- Native `TextEditor` scroll backgrounds remained white while the custom editor text was light, making edits unreadable.

This phase makes design tokens appearance-aware, reduces split-view minimum widths, allows the review command row to scroll instead of clip, makes search/filter controls flexible, and hides the native editor background in favor of the PageLumen surface token. The changes preserve the system appearance choice and keep the existing high-contrast toggle intact.

## Verification

- `xcodebuild ... build-for-testing`: passed (`** TEST BUILD SUCCEEDED **`).
- `swift test -Xswiftc -gnone`: 332 executed, 0 failures, 2 expected skips.

Physical Light/Dark, VoiceOver, keyboard-only, large text, Increase Contrast, Reduce Transparency, and Reduce Motion checks remain open.

## Responsive polish pass

The follow-up visual review found two remaining overflow risks in compact
windows: the Home import actions and the Listen & Export action row. Home now
uses `ViewThatFits` to switch from a single action row to an adaptive grid;
Listen & Export keeps its controls in a horizontal scroll region rather than
clipping or wrapping labels into unreadable columns. This improves discoverability
without changing any command or keyboard shortcut.

The interface is not declared “perfect” from source inspection alone. A final
quality bar still requires a clean physical run at compact and expanded window
sizes, Light/Dark appearance, large text, VoiceOver, keyboard-only navigation,
and the reduced-transparency/motion settings.

---

# Current runtime slice

## Runtime evidence

The signed archive was launched in the current macOS GUI session and captured at
2880×1800 (`/tmp/pagelumen-runtime-clean4.png`). This is evidence that the
application window can render and accept the fixture document in a real host
session. It is not evidence of VoiceOver, Switch Control, large-text, reduced
motion/transparency, or participant acceptance.

## Findings

### Resolved in this slice

- The Review workspace no longer gives every secondary action equal visual
  weight. Continue, page selection, and reading-order visibility are primary.
- Confidence, edit history, and compare-edits are grouped under a labelled
  **More** menu, while the review queue remains directly reachable and keeps
  the `review.queue` UI-test/accessibility identifier.
- Review controls and search/filter controls are horizontally scrollable rather
  than silently clipping actions at constrained widths.
- The review heading and explanatory copy are single-line, priority-preserved
  content so they do not collapse behind the preview divider.
- The review trust bar uses a compact issue count and first-issue action rather
  than a long, competing toolbar label.

### Still open before calling the UI release-ready

- Verify the redesigned workspace at the minimum supported window size and at
  large text sizes; screenshots are still not a substitute for participant
  testing.
- Run keyboard-only, VoiceOver, Switch Control, Increase Contrast, Reduce
  Transparency, and Reduce Motion checks on a physical Mac.
- Exercise every control in a live worker: import/drop/paste, page navigation,
  queue resolution, editing, undo/redo, audio playback, and every export/save
  panel. The deterministic tests cover state seams but not all native panels.
- Validate light, dark, and system appearance with a human review of focus
  rings, disabled states, contrast, and text truncation.

## Acceptance bar for the next UI phase

The phase is complete only when the review screen remains usable at the minimum
window size, all primary actions are visible without truncation, secondary
actions remain discoverable, and the manual accessibility/participant gates are
recorded with observed outcomes. Until then this is a substantial polish slice,
not a claim that the UI is perfect.
