# PageLumen fixture corpus and metrics contract

`corpus-metrics-v1.json` is the versioned schema/report for the bounded
representative corpus. The test-only generators in
`Tests/PageLumenCoreTests/Fixtures.swift` cover papers, legal filings, forms,
receipts, slides, tables, charts, rotated pages, multilingual text, equations,
and deliberate OCR traps. Low-quality scan and handwriting entries are clearly
labelled synthetic proxies.

The current report is intentionally `scaffold-only`. All accuracy fields are
`null`; this is an explicit unavailable value, not a zero or an implied quality
claim. Populating CER, WER, reading-order, table-cell, false-heading, or OCR
processing-time values requires a separately consented and versioned reference
transcript plus a repeatable physical-device run. A baseline update must change
the schema/report in the same review and identify the device, OS, fixture
revision, and processing profile.
