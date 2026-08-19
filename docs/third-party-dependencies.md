# Third-party dependency workflow

PageLumen keeps production dependencies small and auditable. The complete
inventory and license summaries live in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md);
`Package.resolved` is the authoritative resolved-version lock file.

## SnapshotTesting

`swift-snapshot-testing` is test-target-only. It protects deterministic text
exports and is not a substitute for VoiceOver, keyboard, contrast, or other
accessibility testing. Current golden tests cover the demo Markdown and tagged
HTML exports in
`Tests/PageLumenCoreTests/__Snapshots__/ExportSnapshotTests/`.

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

## Adoption and removal rules

Each dependency must have a bounded user outcome, a pinned resolved version, a
license entry, an update owner, a security-review path, and a removal strategy.
Dependencies must continue to work when the app is run offline after package
resolution. Packages that download models or send document data are not enabled
by dependency resolution alone; they require a separate consented feature and
privacy review.

Before updating a package:

1. Review the upstream release notes, license, and security advisories.
2. Run `swift test` and the app-target build on the supported macOS baseline.
3. Inspect the resolved diff and update `THIRD_PARTY_NOTICES.md` if the
   requirement or user-facing purpose changes.
4. Confirm that the package remains behind its documented target/protocol
   boundary so it can be removed without rewriting unrelated workflows.
