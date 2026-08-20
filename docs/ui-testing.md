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
| Settings | `settings.privacyMode`, `settings.searchableCopies`, `settings.forgetAll`, `settings.appearance`, `settings.boostContrast`, `settings.intelligenceMode`, `settings.documentIntelligenceOptOut`, `settings.intelligenceAvailability` |

The bounded import seam accepts `-ui-testing -ui-testing-import` and exposes
`home.uiTestImportFixture`; activating it loads the in-memory demo document and
asserts the transition to Review without opening `NSOpenPanel`. The recovery
seam accepts `-ui-testing -ui-testing-import-denied`, exposes the explicit
`home.importPermissionDenied` state and `home.retryImport` action, then loads
the same bounded fixture after retry. These routes validate state transitions
and loss-free recovery only. They do not simulate or prove macOS sandbox,
security-scoped bookmark, Screen Recording, or real picker permission behavior.

The additional identifiers are intentionally not asserted from the initial
Home-only headless contract because their views are reached after import or
settings navigation. A participant run must exercise each enabled control and
record the resulting state transition.

The deterministic settings launch now also asserts the on-device intelligence
controls and availability announcement. This proves that the explicit
intelligence opt-in/opt-out surface is present and discoverable in a clean
settings launch; it does not prove Apple Intelligence availability on a given
Mac, model output quality, or the behavior of the system settings that govern
eligibility.

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

For deterministic review/export coverage, launch with both
`-ui-testing -ui-testing-fixture`. This loads the bounded in-memory demo
document and opens Review without touching the persisted library. The fixture
test asserts Review Queue/Continue and navigates to export controls; it does
not prove OCR, save-panel, permission, or accessibility-participant behavior.

On 20 August 2026, a live `xcodebuild ... -only-testing:PageLumenUITests test`
attempt built the app and UI-test runner, then stalled while Xcode waited for a
test worker to materialize. It was interrupted after approximately 43 seconds;
no UI assertions are counted as passed. The result bundle is retained at
`~/Library/Developer/Xcode/DerivedData/PageLumen-hbeprxkxvdpbnyeekgojupdmzjpn/Logs/Test/Test-PageLumen-2026.08.20_18-16-56-+0530.xcresult`.
This is a host test-runner limitation, not participant evidence.
