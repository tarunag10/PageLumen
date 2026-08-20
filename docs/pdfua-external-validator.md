# Optional PDF/UA validator boundary

Updated 20 August 2026.

PageLumen now has a testable, local-process adapter for
[`speedata/pdfa11y`](https://github.com/speedata/pdfa11y). The adapter is
developer/CI-only. It is not an SPM dependency, is not embedded in the app,
does not run automatically during export, and never sends a document to a
network service.

## Approved scope

- License: MIT, suitable for an optional developer/CI integration.
- Invocation: `pdfa11y --format json --strict <temporary-pdf>`.
- Input: a temporary local PDF that is removed after the command returns.
- Output: bounded JSON parsed into `PDFUAExternalValidationReport`.
- Exit status: status `0` and validation status `1` are report results; status
  `2` is a tool/usage failure.
- Output limit: 2 MiB, preventing an unexpectedly large report from becoming a
  memory or log sink.

The boundary is implemented in
`Sources/PageLumenCore/PDFUAExternalValidator.swift` and covered by
`PDFUAExternalValidatorTests` with a fake command runner. The production
process runner remains opt-in and requires the user or CI environment to
install and pin the executable independently.

## Deliberate limitations

This does not turn PageLumen's `Readable PDF` into a PDF/UA-conformant export.
`pdfa11y` covers a machine-checkable subset and is not a replacement for
specialist human review or the ISO-reference veraPDF validator. veraPDF is not
bundled because its GPL/MPL licensing, Java runtime, distribution terms, and
larger validation corpus need a separate legal and release decision.

Before enabling this adapter in CI, pin a reviewed `pdfa11y` release, verify
the checksum and macOS architecture, record the binary's notice, and run it
against the PageLumen fixture corpus. A failing or unavailable optional tool
must never block the normal export path or be presented as proof of PDF/UA
conformance.
