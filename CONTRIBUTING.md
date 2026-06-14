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

## Pull Requests

Please include:

- A summary of the change
- Why it helps users
- Tests run
- Any accessibility or privacy implications

For large changes, open an issue first to discuss scope.
