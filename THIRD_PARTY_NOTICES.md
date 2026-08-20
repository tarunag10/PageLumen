# Third-party notices

PageLumen currently resolves these Swift Package Manager dependencies:

| Package | Pinned requirement | License | Product use |
| --- | --- | --- | --- |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | `from: 0.9.20` (resolved `0.9.20`) | MIT | DOCX Office Open XML archive creation and package framing |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | `from: 1.17.0` (resolved `1.19.4`) | MIT | Test-target-only golden output and UI regression infrastructure |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | `exact: 0.8.0` (resolved `0.8.0`) | Apache-2.0 with Runtime Library Exception | Production Markdown export contract validation and test-target AST assertions |

SnapshotTesting is linked only to test targets and is not shipped in the
PageLumen application. swift-markdown is linked by `PageLumenCore` so the app
can validate its own Markdown export boundary. Package resolution is recorded in the
Xcode project and must be reviewed before dependency updates. No package
receives document data outside the local process.

Each dependency remains removable behind its target boundary: DOCX generation
uses `ZIPFoundation` through `DOCXWriter`, SnapshotTesting remains test-only,
and swift-markdown is isolated to `MarkdownExportContract`. Before a release, review upstream
security advisories and confirm the resolved version and license text against
the package checkout.

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
