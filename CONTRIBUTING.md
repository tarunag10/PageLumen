# Contributing to PageLumen

Thanks for your interest in contributing.

PageLumen is an accessibility-first macOS document reader. Contributions should improve access, trust, privacy, reviewability, or export quality.

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
