# UI testing contract

PageLumen has a macOS XCUITest target (`PageLumenUITests`) for deterministic
launch-surface and workflow-navigation checks. The target is intentionally
small: it verifies the controls that must be present before an import starts,
without pretending that OCR, Screen Recording permission, or a save panel can
be validated in a headless build.

## Deterministic launch

The test host receives `-ui-testing`. PageLumen treats that argument as a
test-only launch mode and does not present onboarding. It does not modify the
normal launch path or persisted user preferences.

Primary Home actions expose stable identifiers:

| Control | Accessibility identifier |
| --- | --- |
| Open Files | `home.openFiles` |
| Paste Image | `home.pasteImage` |
| Capture Screen | `home.captureScreen` |
| Try Demo | `home.tryDemo` |

Review, export, and settings controls also expose stable identifiers for
participant-driven XCUITest flows:

| Surface | Identifiers |
| --- | --- |
| Review | `review.undo`, `review.redo`, `review.queue`, `review.continue`, `review.search`, `review.nextMatch`, `review.previousMatch` |
| Export | `export.backToReview`, `export.<format>` |
| Settings | `settings.privacyMode`, `settings.searchableCopies`, `settings.forgetAll`, `settings.appearance`, `settings.boostContrast` |

The additional identifiers are intentionally not asserted from the initial
Home-only headless contract because their views are reached after import or
settings navigation. A participant run must exercise each enabled control and
record the resulting state transition.

Workflow step buttons retain their accessible labels (`Step 1, Add` through
`Step 4, Export`) so navigation checks do not depend on SwiftUI view hierarchy
or localized visual text.

## Verification

Compile the app and UI-test bundle without signing:

```sh
xcodebuild -project PageLumen.xcodeproj \
  -scheme PageLumen \
  -configuration Debug \
  -sdk macosx \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Running the tests requires a logged-in macOS GUI session. A participant run
must separately record outcomes for onboarding, dark/light appearance,
permission denial/recovery, import, review, and export; compilation alone is
not evidence for those gates.
