# Manual accessibility acceptance — 2026-08-20

This is an evidence form, not a claim that the sessions have been completed.
Run it on the signed Developer ID app from the release evidence record with a
fresh test document that contains headings, a table, a figure, low-confidence
OCR, and a page warning. Do not retain participant documents after the session.

## Session record

- Tester/participant code:
- macOS version:
- PageLumen version/build:
- VoiceOver/Switch Control configuration:
- Consent and document-destruction confirmation:

## Critical workflows

| Workflow | Pass criteria | Evidence / issue ID |
| --- | --- | --- |
| Import PDF/image | User can select, process, and recover from a denied permission without losing the document. | |
| Review navigation | VoiceOver reaches page, heading, block, finding, and quote controls in reading order. Cmd-Shift-[ and ] move between findings and wrap correctly. | |
| Correct OCR | User can edit a block, mark it reviewed, and copy an accessible excerpt containing page/block citation. | |
| Export | User can choose an export, understand validation findings, and recover from an unavailable format. | |
| Search/App Intent | Search returns only retained local documents and exposes provenance; opening a result lands on the expected page. | |

## Assistive-technology matrix

- [ ] VoiceOver rotor: headings, buttons, text fields, tables/figures.
- [ ] Full keyboard workflow, including focus visibility and no mouse-only action.
- [ ] Switch Control or equivalent alternate input.
- [ ] Larger text/zoom and increased contrast.
- [ ] Reduced transparency and reduced motion.
- [ ] Light and dark appearance.
- [ ] Screen-capture permission denial and cancellation.
- [ ] Offline operation and clearing recent documents.

## Exit decision

- Successful task completion rate:
- Median time-to-correct before PageLumen:
- Median time-to-correct with PageLumen:
- Critical issues requiring remediation:
- Reviewer/sign-off:

Do not mark this form complete from automated unit tests alone. Attach the
participant-safe notes and issue IDs only in the approved private research
location.
