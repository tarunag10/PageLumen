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

