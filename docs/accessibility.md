# PageLumen Accessibility

PageLumen is an accessibility-first product: the app exists to make other documents more accessible, so the app itself has to be a model citizen. This page summarises the accessibility posture of the current build and its known limitations. The audit implementation plan (`docs/superpowers/plans/2026-06-15-audit-implementation-plan.md`, Phase 4) tracks the work in flight.

## VoiceOver-Friendly Workflows

- The four-step workflow — **Add → Process → Review → Export** — is fully labelled. Every major control has an `accessibilityLabel`, an `accessibilityHint` where the action is non-obvious, and a `traits` value that matches what the control actually does.
- Editable text blocks in the review surface expose a live `.accessibilityValue` so VoiceOver reads the current OCR text, not just the placeholder.
- The reading-order overlay in `PreviewPane` labels each rectangle with its block index, type, and the first 40 characters of the block text, so a screen-reader user can navigate the page in the same order as a sighted user.
- Review Queue actions expose `Cmd-Shift-A` to accept and `Cmd-Shift-X` to reject the current block-backed finding; page warnings remain source-correction work.

## Colour, Contrast, and Status

- All colours come from system tokens (`AccessibleStyle` in `Sources/PageLumen/Support/AccessibleStyle.swift`) so Increase Contrast, Reduce Transparency, and Light/Dark mode just work.
- Status indicators are never colour-only. A `StatusBadge` helper pairs a colour tint with an SF Symbol and a text label, matching the README and CONTRIBUTING guidance against colour-only signalling.

## Reading-Order Overlay

The reading-order overlay is fully accessible:

- Each overlay rectangle has a label, a value, and a hint.
- The overlay reacts to keyboard focus so a VoiceOver user can step through the blocks in the same order a sighted user reads them.
- Block move actions (up / down) keep the VoiceOver cursor on the moved block.
- Each extracted block has a **Copy accessible excerpt** action. The clipboard
  text is plain text for broad assistive-technology compatibility and includes
  a page and reading-order block citation; source URLs and OCR metadata are not
  copied.

## Tagged Export for Screen-Reader Users

- The **Tagged HTML** export writes a structurally valid HTML document with `<h1>`…`<h6>`, lists, table headers, figure captions, and ARIA landmarks. It is the recommended format for users who want to take the document into another tool.
- The **Readable PDF** export goes through PDFKit and is designed to be more accessible than a flat text PDF. It is **not** PDF/UA compliant. See the limitations below.

Accessibility-sensitive exports are now review-gated. Tagged HTML, HTML, Readable
PDF, and DOCX exports are blocked when automated checks find an unresolved
accessibility blocker (for example, an unknown block type, missing document
language, or missing figure description). Warnings remain visible in the audit
report and do not silently change the export contract. The Accessibility Report
remains available as the remediation path.

## Export capability matrix

The matrix below describes what the current exporters retain and which review
gate applies. “Local anchors” are stable identifiers inside the saved artifact;
they are not deep links that open the PageLumen app.

| Format | Semantics | Source citations | Tables | Figures | Metadata/redaction | Validation gate |
| --- | --- | --- | --- | --- | --- | --- |
| Markdown | headings and reading order | page references | Markdown tables | descriptions | export options; source URL can be redacted | export contract |
| TXT | none beyond reading order | page references when enabled | flattened text | flattened text | export options | export contract |
| HTML | semantic headings, tables, figures | page/data attributes | HTML table headers | figure captions | export options | accessibility audit; blockers stop export |
| Tagged HTML | semantic landmarks and stable block anchors | page/block anchors | header cells and block anchors | ARIA label and caption | export options; source snippets can be redacted | accessibility audit; blockers stop export |
| Readable PDF | selectable text only | page text | flattened text | flattened descriptions | export options | explicitly not PDF/UA; blockers stop export |
| DOCX | Office Open XML structure (consumer review required) | document content | generated table content | description text | export options | independent consumer review required |
| CSV | table cells | page/table columns | preserved cells | not applicable | formula neutralisation | CSV contract tests |
| JSON | machine-readable document model | source URL and block/page fields | structured rows | structured descriptions | source URL/snippet redaction | schema/version gate (in progress) |
| Accessibility Report | automated findings | page/block references | findings only | findings only | redaction options | report is remediation path |
| Audio | spoken text | not retained | not retained | not retained | configured voice/language | speech service and media review |

CSV export is a locale-neutral, long-form cell contract with the columns
`Page,Table,Row,Column,Value`. Every non-empty source cell receives a stable
coordinate, so ragged table rows remain lossless without padding or guessing
missing columns. Values containing commas, quotes, CR, or LF use RFC 4180
quoting (quotes are doubled); spreadsheet-formula-leading values are prefixed
with `'` to prevent formula execution when opened in a spreadsheet.

## Known Limitations

- **Not PDF/UA compliant.** The current PDF export does not claim PDF/UA conformance. We are tracking this in the audit plan; a tagged-PDF pass would require moving the export onto `PDFKit`'s `PDFDocument` / `PDFPage` APIs and adding structure-tree metadata.
- **Dynamic Type is partial.** Most of the UI uses semantic font styles (`Font.body`, `Font.title3`, …) so it scales with the user's preferred text size. A few fixed-size affordances (workflow step pill numbers, the batch queue status dot) are intentionally fixed; they will move to `ScaledMetric` in a follow-up.
- **Reduce-motion is currently a no-animation workflow.** The review workflow
  has no decorative transitions, and any future animation must be gated on
  SwiftUI's `accessibilityReduceMotion` environment value.
- **Onboarding flow for accessibility permissions is not yet present.** The first-time ScreenCaptureKit prompt (audit plan 1.3.2) is the next accessibility-facing change to land.

## Reporting Accessibility Issues

If you find an accessibility regression, please open an issue (or, for security-sensitive material, follow [`SECURITY.md`](../SECURITY.md)). Include VoiceOver output, the macOS version, and the workflow step that triggered the issue.
