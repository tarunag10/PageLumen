# Third-party dependency workflow

PageLumen keeps production dependencies small and auditable. The complete
inventory and license summaries live in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md);
`Package.resolved` is the authoritative resolved-version lock file.

## SnapshotTesting

`swift-snapshot-testing` is test-target-only. It protects deterministic text
exports and is not a substitute for VoiceOver, keyboard, contrast, or other
accessibility testing. Current golden tests cover the demo plus stable legal,
multilingual, receipt/table, and links/figure Markdown or tagged HTML exports
in `Tests/PageLumenCoreTests/__Snapshots__/ExportSnapshotTests/`. Generated
HTML and Tagged HTML also pass the dependency-free `HTMLExportContract` checks
for language, landmarks, heading hierarchy, table headers, figure
descriptions, safe links, and escaped content.

## swift-markdown

`swift-markdown` is pinned to `0.8.0` and is test-target-only. The focused
`MarkdownContractTests` suite parses representative PageLumen Markdown output
with Apple's/Swift.org's GitHub-Flavored Markdown AST and checks headings,
tables, and block quotes. It does not change the production export path or
send document data outside the local test process. If the package is removed,
remove its single test dependency and contract suite; the production exporter
continues to use its existing deterministic string writer.

Run the focused parser contract with:

```sh
swift test --filter MarkdownContractTests
```

Run the focused tests with:

```sh
swift test --filter ExportSnapshotTests
```

When an intentional output change is made, record snapshots explicitly and
review the resulting text diff before committing it. The recording run should
never be part of the normal CI command:

```sh
SNAPSHOT_TESTING_RECORD=1 swift test --filter ExportSnapshotTests
swift test --filter ExportSnapshotTests
```

The second command is required to prove that the committed references pass.
Snapshot changes require reviewer approval and a description of the user-visible
export change. Do not record snapshots from a machine-specific UI renderer.
The focused suite covers six deterministic outputs. A missing reference is
expected to fail the recording run; rerun the same focused command without
`SNAPSHOT_TESTING_RECORD` and require the committed references to pass.

## ZIPFoundation and independent DOCX consumer checks

ZIPFoundation is pinned to exact release `0.9.20` (revision
`22787ffb59de99e5dc1fbfe80b19c97a904ad48d`) and is used only by the app's
`ZIPFoundationDOCXArchiveWriter`. `DOCXPackageValidator` remains dependency
free and checks required OOXML parts, XML parseability, relationship safety,
and path traversal/dangling-target failures. `DOCXWriterTests` additionally
writes the generated archive to a temporary file and runs the host's
independent `/usr/bin/unzip -tqq` package test. This validates ZIP framing and
CRC/readability independently of PageLumen's package-part parser.

Run the focused contract with:

```sh
swift test -Xswiftc -gnone --filter DOCXWriterTests
```

The unzip check is not a Word, Pages, or LibreOffice rendering test. Those
desktop-consumer checks remain a release/manual gate and are intentionally not
claimed by the automated suite. Exact version, MIT license links, ownership,
security-review path, and removal procedure are recorded in
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

## Adoption and removal rules

Each dependency must have a bounded user outcome, a pinned resolved version, a
license entry, an update owner, a security-review path, and a removal strategy.
Dependencies must continue to work when the app is run offline after package
resolution. Packages that download models or send document data are not enabled
by dependency resolution alone; they require a separate consented feature and
privacy review.

Run the deterministic readiness check after an intentional online resolution:

```sh
make offline-dependencies
```

The check requires every `Package.resolved` checkout to exist locally, then
runs the Markdown, DOCX, and export-snapshot contracts with SwiftPM's
`--skip-update` flag and its normal sandbox. It proves the current resolved
packages can build and run without a dependency update; it does not claim a
network firewall test or a signed distribution artifact.

Before updating a package:

1. Review the upstream release notes, license, and security advisories.
2. Run `swift test` and the app-target build on the supported macOS baseline.
3. Inspect the resolved diff and update `THIRD_PARTY_NOTICES.md` if the
   requirement or user-facing purpose changes.
4. Confirm that the package remains behind its documented target/protocol
   boundary so it can be removed without rewriting unrelated workflows.
