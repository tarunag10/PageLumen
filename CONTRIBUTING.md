# Contributing to PageLumen

Thanks for your interest in contributing.

PageLumen is an accessibility-first macOS document reader (previously developed as "Sightline Reader" and renamed to "PageLumen" in 2026). Contributions should improve access, trust, privacy, reviewability, or export quality.

## Development Setup

1. Clone the repo.
2. Open `PageLumen.xcodeproj` in Xcode, or use SwiftPM from the terminal.
3. Run tests before submitting changes:

```sh
swift test
```

4. If you change `project.yml`, regenerate the Xcode project:

```sh
xcodegen generate
```

## Documentation

Before opening a pull request, skim the docs that match your change so the new behavior lines up with the documented intent:

- [`docs/architecture.md`](docs/architecture.md) — the `PageLumenCore` ↔ `PageLumen` split, import / review / export pipelines, and the recipe for adding a new export format.
- [`docs/privacy.md`](docs/privacy.md) — local-first promise, what never leaves the device, and how to clear local data.
- [`docs/accessibility.md`](docs/accessibility.md) — the app's accessibility posture, supported assistive-tech features, and known limitations.
- [`docs/superpowers/plans/2026-06-15-audit-implementation-plan.md`](docs/superpowers/plans/2026-06-15-audit-implementation-plan.md) — the open audit plan that catalogs known gaps; if your change closes one of them, update the relevant checkbox.

## Contribution Guidelines

- Keep processing local-first unless a feature explicitly requires otherwise.
- Add or update tests for core logic changes.
- Keep UI changes keyboard and VoiceOver friendly.
- Avoid color-only status indicators.
- Use semantic macOS system colors and accessible contrast.
- Be precise about export claims. Do not describe readable PDF output as full PDF/UA compliance unless validated.
- Keep features scoped and reviewable.

## Dependency and security review

Before adding or updating a package:

1. Record the exact URL, resolved version, license, and shipped/test-only scope
   in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
2. Review the upstream release notes and security advisories, then run the
   package tests in an offline-capable checkout after resolution.
3. Keep credentials, document content, and generated user data out of build
   logs, fixtures, snapshots, and issue reports.
4. Add a removal or fallback path for every non-system dependency; optional
   integrations must not become a requirement for the default local workflow.

Dependency updates require a focused test run plus the full regression command
documented in the pull request. Automated update tooling may open review-only
changes, but must not merge directly into a release branch.

## Pull Requests

Please include:

- A summary of the change
- Why it helps users
- Tests run
- Any accessibility or privacy implications

For large changes, open an issue first to discuss scope.
