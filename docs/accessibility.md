# PageLumen Accessibility

PageLumen is an accessibility-first product: the app exists to make other documents more accessible, so the app itself has to be a model citizen. This page summarises the accessibility posture of the current build and its known limitations. The audit implementation plan (`docs/superpowers/plans/2026-06-15-audit-implementation-plan.md`, Phase 4) tracks the work in flight.

## VoiceOver-Friendly Workflows

- The four-step workflow — **Add → Process → Review → Export** — is fully labelled. Every major control has an `accessibilityLabel`, an `accessibilityHint` where the action is non-obvious, and a `traits` value that matches what the control actually does.
- Editable text blocks in the review surface expose a live `.accessibilityValue` so VoiceOver reads the current OCR text, not just the placeholder.
- The reading-order overlay in `PreviewPane` labels each rectangle with its block index, type, and the first 40 characters of the block text, so a screen-reader user can navigate the page in the same order as a sighted user.

## Colour, Contrast, and Status

- All colours come from system tokens (`AccessibleStyle` in `Sources/PageLumen/Support/AccessibleStyle.swift`) so Increase Contrast, Reduce Transparency, and Light/Dark mode just work.
- Status indicators are never colour-only. A `StatusBadge` helper pairs a colour tint with an SF Symbol and a text label, matching the README and CONTRIBUTING guidance against colour-only signalling.

## Reading-Order Overlay

The reading-order overlay is fully accessible:

- Each overlay rectangle has a label, a value, and a hint.
- The overlay reacts to keyboard focus so a VoiceOver user can step through the blocks in the same order a sighted user reads them.
- Block move actions (up / down) keep the VoiceOver cursor on the moved block.

## Tagged Export for Screen-Reader Users

- The **Tagged HTML** export writes a structurally valid HTML document with `<h1>`…`<h6>`, lists, table headers, figure captions, and ARIA landmarks. It is the recommended format for users who want to take the document into another tool.
- The **Accessible PDF** export goes through PDFKit and is designed to be more accessible than a flat text PDF. It is **not** PDF/UA compliant. See the limitations below.

## Known Limitations

- **Not PDF/UA compliant.** The current PDF export does not claim PDF/UA conformance. We are tracking this in the audit plan; a tagged-PDF pass would require moving the export onto `PDFKit`'s `PDFDocument` / `PDFPage` APIs and adding structure-tree metadata.
- **Dynamic Type is partial.** Most of the UI uses semantic font styles (`Font.body`, `Font.title3`, …) so it scales with the user's preferred text size. A few fixed-size affordances (workflow step pill numbers, the batch queue status dot) are intentionally fixed; they will move to `ScaledMetric` in a follow-up.
- **Reduce-motion is not yet implemented.** No current view animates in a way that would trigger a motion sensitivity, but the `accessibilityReduceMotion` environment value is not yet threaded into the codebase. Any future animation work must gate on it.
- **Onboarding flow for accessibility permissions is not yet present.** The first-time ScreenCaptureKit prompt (audit plan 1.3.2) is the next accessibility-facing change to land.

## Reporting Accessibility Issues

If you find an accessibility regression, please open an issue (or, for security-sensitive material, follow [`SECURITY.md`](../SECURITY.md)). Include VoiceOver output, the macOS version, and the workflow step that triggered the issue.
