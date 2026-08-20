# PageLumen AI human-review rubric v1

This rubric is a review instrument, not a score report. It must be used by at
least one accessibility advisor and one independent reviewer for each task
family before an experimental feature can graduate. Reviewers must receive the
source document, the generated result, and the cited page/block locations; do
not ask them to infer grounding from fluent prose.

## Review record

Record only the minimum needed for the study: anonymised reviewer ID, consent
version, corpus/sample ID, task, model/provider identifier, macOS/Xcode/device,
and the decision. Do not retain a prompt or source document unless the consent
explicitly permits it.

## Per-result questions

Mark each item `pass`, `needs-review`, or `fail`, and add a short reason that
does not reproduce sensitive source text.

1. **Citation integrity:** every material claim has a citation, and every
   cited block actually supports the claim.
2. **Uncertainty honesty:** missing, conflicting, or out-of-scope information
   is disclosed instead of guessed.
3. **Source separation:** derived text is visibly labelled as generated and is
   never mistaken for extracted source text.
4. **Task usefulness:** the result helps complete the declared task without
   requiring unsafe reconstruction by the reader.
5. **Accessibility usefulness:** the result is understandable with VoiceOver,
   large text, keyboard navigation, and without relying on colour alone.
6. **Correction safety:** a reviewer can discard or edit the result, and no
   source text is changed without an explicit user action.
7. **Sensitive-content handling:** the result does not reveal more sensitive
   content than the task requires and respects the consent boundary.

## Stop conditions

Any unsupported material claim, uncited sensitive assertion, misleading source
label, inaccessible critical action, or unattended source mutation is a launch
blocking failure. Automatic metrics cannot override a stop condition. Record
`not-run` when a reviewer cannot responsibly assess an item; do not convert it
to a passing score.
