# PDF/UA direction record

Updated 20 August 2026. This is an implementation record for the current
`Readable PDF` exporter, not a PDF/UA conformance statement.

## Finding

The current exporter uses Core Graphics (`CGContext` with PDF output) and
PDFKit for deterministic text-based output. The generated artifact can expose
selectable text and document metadata, but the current path does not author or
validate the PDF constructs required for a defensible PDF/UA claim:

- document language and marked-content metadata;
- a structure tree describing headings, paragraphs, tables, and reading order;
- figure alternate text associated with figure content;
- table header/scope relationships; and
- an independent conformance result.

The supported Apple PDFKit surface provides `PDFDocument`, `PDFPage`,
`PDFOutline`, text selection, annotations, and document attributes. Those APIs
are useful for reading and writing PDF artifacts, but the current PageLumen
export path has no stable, tested structure-tree authoring boundary. Core
Graphics metadata alone is not equivalent to tagged PDF semantics.

References:

- [PDFKit](https://developer.apple.com/documentation/pdfkit)
- [PDFDocument](https://developer.apple.com/documentation/pdfkit/pdfdocument)
- [PDFAnnotation](https://developer.apple.com/documentation/pdfkit/pdfannotation)

## Bounded prototype

`PDFUADirectionValidator` runs against the bytes produced by the existing
exporter. It records only observable evidence:

- PDFKit can parse the artifact;
- the artifact exposes selectable text;
- title metadata is present; and
- language, marked content, structure tree, figure alternate text, and table
  semantics are explicitly reported as not implemented.

The prototype is covered by
`Tests/PageLumenCoreTests/PDFUADirectionTests.swift`. It includes the demo
fixture and malformed-byte cases. A successful prototype result never sets
`isPDFUAConformant` to `true`; this prevents a smoke test from being mistaken
for a standards validation result.

## Product decision

Keep the user-facing format name `Readable PDF`. Do not expose a
“PDF/UA-oriented” option until a specialist PDF authoring boundary and an
approved independent validator have been selected, licensed, automated, and
tested against a fixture corpus. Keep `Tagged HTML` as the recommended
accessibility remediation export in the meantime. It preserves semantic
headings, landmarks, table headers, figure descriptions, and stable PageLumen
anchors in a format that can be reviewed with established HTML accessibility
tools.

An external validator remains a future approval-gated decision. Before adding
one, record its license and redistribution terms, runtime/toolchain support,
offline/CI behaviour, fixture coverage, and known false-positive/false-negative
limits. No external validator is bundled by this phase.
