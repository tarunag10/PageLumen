# PageLumen assistive-technology regression checklist

Use this checklist for every release candidate. Automated checks prove that
labels, keyboard commands, and deterministic export contracts exist; they do
not replace a hands-on macOS accessibility pass.

## Automated evidence

- [x] Review controls expose labels, hints, and traits in SwiftUI.
- [x] `Cmd-Shift-[` / `Cmd-Shift-]` navigate review findings with wrap-around.
- [x] `Cmd-Shift-A` accepts the current block-backed finding.
- [x] `Cmd-Shift-X` rejects the current block-backed finding.
- [x] Selected review findings synchronize page/block selection and receive a
  visible focus treatment in the preview and extracted-text surfaces.
- [x] Reading mode persists focus highlighting, line spacing, typography, and
  speech speed preferences without changing source document data.
- [x] Export remediation output includes blocker/warning counts, a checklist,
  and an explicit manual-review notice.

## Manual macOS pass

Record the macOS version, app build, tester, date, and outcome for each item.

- [ ] VoiceOver rotor reaches headings, pages, review findings, editable text,
  tables, figures, and export controls in a logical order.
- [ ] VoiceOver focus remains on the selected block after accepting, rejecting,
  reopening, or moving a finding.
- [ ] Full keyboard workflow completes Add → Process → Review → Export without
  requiring a pointer; focus indicators remain visible in light and dark mode.
- [ ] Switch Control can activate import, review, accept/reject, reading-mode,
  and export actions.
- [ ] Larger text settings preserve usable layout, readable labels, and access
  to all controls without clipped or overlapping content.
- [ ] Increase Contrast and Reduce Transparency preserve distinguishable
  borders, selected-source focus, status icons, and disabled states.
- [ ] Reduce Motion produces no disorienting transitions or hidden state
  changes; reading-mode focus remains understandable without animation.
- [ ] Pointer/trackpad zoom and scrolling work in the source preview,
  extracted text, review queue, and export preview.

## Evidence and triage

For every failure, capture the workflow step, expected result, observed result,
macOS accessibility setting, and severity. Do not retain imported user
documents or screenshots containing private document content unless the tester
has explicitly consented for the agreed research session.
