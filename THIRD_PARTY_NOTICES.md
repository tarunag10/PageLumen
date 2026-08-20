# Third-party notices

PageLumen currently resolves these Swift Package Manager dependencies:

| Package | Pinned requirement | License | Product use |
| --- | --- | --- | --- |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | `exact: 0.9.20` (tag/revision `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`) | MIT | DOCX Office Open XML archive creation and package framing |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | `from: 1.17.0` (resolved `1.19.4`) | MIT | Test-target-only golden output and UI regression infrastructure |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | `exact: 0.8.0` (resolved `0.8.0`) | Apache-2.0 with Runtime Library Exception | Production Markdown export contract validation and test-target AST assertions |

SnapshotTesting is linked only to test targets and is not shipped in the
PageLumen application. swift-markdown is linked by `PageLumenCore` so the app
can validate its own Markdown export boundary. Package resolution is recorded in the
Xcode project and must be reviewed before dependency updates. No package
receives document data outside the local process.

## Optional developer validator: pdfa11y

PageLumen contains a process boundary for the optional MIT-licensed
[`speedata/pdfa11y`](https://github.com/speedata/pdfa11y) command-line
validator. The executable is not bundled, copied, linked, or invoked by the
shipping application. It is used only when a developer or CI job explicitly
provides a reviewed local binary; the temporary input PDF is removed after
validation. See [`docs/pdfua-external-validator.md`](docs/pdfua-external-validator.md)
for the scope, limitations, pinning, and removal procedure.

Each dependency remains removable behind its target boundary: DOCX generation
uses `ZIPFoundation` through `DOCXWriter`, SnapshotTesting remains test-only,
and swift-markdown is isolated to `MarkdownExportContract`. Before a release, review upstream
security advisories and confirm the resolved version and license text against
the package checkout.

## ZIPFoundation notice and removal record

The PageLumen build consumes the unmodified ZIPFoundation `0.9.20` release at
revision `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`. Its upstream MIT notice
and license text are available in the [release source](https://github.com/weichsel/ZIPFoundation/tree/0.9.20)
and [LICENSE](https://github.com/weichsel/ZIPFoundation/blob/0.9.20/LICENSE).
The package is used only by the `PageLumen` app target through
`ZIPFoundationDOCXArchiveWriter`; no document bytes are sent to the package or
retained outside the requested local DOCX output. The package is not copied or
modified in this repository.

To remove or replace ZIPFoundation, restore a writer conforming to
`DOCXArchiveWriting`, run the DOCX package and independent-consumer suites,
remove the app-target product and lock entry, then remove this notice after
review. A release must not loosen the exact version requirement without
updating this record, `Package.resolved`, and the security/advisory review.

## External services (not bundled)

### Stirling-PDF

PageLumen contains an optional HTTP adapter for a user-managed Stirling-PDF
instance. Stirling source code, binaries, containers, Java/Spring/React/Tauri
runtime components, and server artifacts are **not** included in the PageLumen
application or Swift package graph. No Stirling license is being redistributed
by the current app binary.

Stirling-PDF is open-core and license scope is path-sensitive: the upstream
repository root describes MIT coverage for some paths, while `engine/` and
other excluded/proprietary paths have separate terms. See the upstream
[`LICENSE`](https://github.com/Stirling-Tools/Stirling-PDF/blob/main/LICENSE),
[`engine/LICENSE`](https://github.com/Stirling-Tools/Stirling-PDF/blob/main/engine/LICENSE),
and PageLumen's [`Stirling security review`](docs/stirling-pdf-security-review.md).
Before any bundled or redistributed use, record an immutable upstream version,
all selected modules and transitive notices, checksums, and legal approval.
