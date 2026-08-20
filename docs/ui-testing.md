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
| Review | `review.undo`, `review.redo`, `review.queue`, `review.continue`, `review.issueNavigator`, `review.firstIssue`, `review.more`, `review.search`, `review.nextMatch`, `review.previousMatch` |
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

The appearance contract has an isolated launch seam for each supported choice:
`-ui-testing-appearance-system`, `-ui-testing-appearance-light`, and
`-ui-testing-appearance-dark` (used with `-ui-testing -ui-testing-settings`).
The test asserts the visible `settings.appearanceValue` preview for all three
values. These arguments override only the test process's effective color
scheme; they do not write `@AppStorage` or alter the user's macOS appearance
preference. This proves the app's System/Light/Dark wiring deterministically,
while contrast, transparency, motion, VoiceOver, and host-level visual
verification remain separate accessibility gates.

The `-ui-testing-stirling` launch argument (combined with
`-ui-testing-fixture`) uses an in-process loopback endpoint seam and exposes
the compression and merge controls without persisting settings or contacting
a server. The contract verifies that the controls are present and that no
save panel opens; provider execution and real-server behavior remain separate
tests.

The `-ui-testing-export` argument (combined with `-ui-testing-fixture`) routes
the normal Markdown and DOCX writers to a temporary `PageLumenUITestExports`
directory. It still validates the document, generates real output bytes, and
reports the normal status message, but avoids a native save panel so a
deterministic UI test can verify file writing. Normal launches always use
`NSSavePanel`.

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

When executing the runner on current Xcode, use an explicit local Mac
destination and disable parallel destination scheduling. This avoids the
ambiguous `Supported platforms for the buildables in the current scheme is
empty` path and makes worker materialization diagnostics reproducible:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/PageLumenClangCache \
SWIFT_MODULECACHE_PATH=/tmp/PageLumenSwiftCache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/PageLumenSPMCache \
xcodebuild -project PageLumen.xcodeproj \
  -scheme PageLumen \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO \
  -disable-concurrent-destination-testing \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY=- \
  -only-testing:PageLumenUITests \
  test
```

Ad-hoc signing is a launch diagnostic for the local GUI session; it is not
distribution signing. A run counts as UI evidence only when the output (or
the `.xcresult` summary) contains executed UI test assertions. A build,
`Testing started` line, worker timeout, interruption, or result bundle with
zero executed tests must be recorded as infrastructure evidence instead.

Running the tests requires a logged-in macOS GUI session. A participant run
must separately record outcomes for onboarding, dark/light appearance,
permission denial/recovery, import, review, and export; compilation alone is
not evidence for those gates.

Before a physical acceptance session, run `make runtime-acceptance-preflight`.
It verifies the current signed archive and reports whether WindowServer and
sysmond are visible to the shell. `WARN` results are host diagnostics, not app
failures; a participant session should be run in a normal logged-in GUI
session. `script/runtime_acceptance_preflight.sh --strict` fails only when the
signed archive is missing or fails deep signature verification.

For deterministic review/export coverage, launch with both
`-ui-testing -ui-testing-fixture`. This loads the bounded in-memory demo
document and opens Review without touching the persisted library. The fixture
tests assert Review Queue/Continue, enumerate every export format and export
option, and confirm the preview is present without opening a native file panel.
This is a control-surface/wiring contract only; it does not prove OCR,
save-panel/file-writing success, permission, or accessibility-participant
behavior. Export confirmation remains a participant/release gate because
clicking a format intentionally invokes the native save panel.

On 20 August 2026, a live `xcodebuild ... -only-testing:PageLumenUITests test`
attempt built the app and UI-test runner, then stalled while Xcode waited for a
test worker to materialize. It was interrupted after approximately 43 seconds;
no UI assertions are counted as passed. The result bundle is retained at
`~/Library/Developer/Xcode/DerivedData/PageLumen-hbeprxkxvdpbnyeekgojupdmzjpn/Logs/Test/Test-PageLumen-2026.08.20_18-16-56-+0530.xcresult`.
This is a host test-runner limitation, not participant evidence.

The rebuilt bundle was rechecked on 20 August 2026 after the Settings view
compiler fix: `build-for-testing` completed with `** TEST BUILD SUCCEEDED **`.
A direct `test-without-building` run of
`testSettingsLaunchExposesPrivacyAndAppearanceControls` still stopped before
worker materialization (`Supported platforms for the buildables in the current
scheme is empty`); no UI assertion is counted as passed. The deterministic
bundle remains ready for a GUI-session/participant run.

A fresh `xcodebuild ... -only-testing:PageLumenUITests test` attempt on 20
August 2026 again reached `Testing started` and then stalled while waiting for
the local macOS test worker to materialize. It was interrupted after 58 seconds;
the result bundle is
`~/Library/Developer/Xcode/DerivedData/PageLumen-hbeprxkxvdpbnyeekgojupdmzjpn/Logs/Test/Test-PageLumen-2026.08.20_19-43-14-+0530.xcresult`.
This is infrastructure evidence only; no UI assertion is counted as passed.

A direct launch attempt of the current unsigned Debug bundle on the same host
also produced no running `PageLumen` process. The host reported `sysmon
request failed: sysmond service not found`, and deep signature verification of
the unsigned bundle reported `code has no resources but signature indicates
they must be present`. This does not invalidate the successful build; it means
runtime visual and accessibility inspection must use a normal logged-in GUI
session with a launchable signed/ad-hoc app bundle.

The newly generated Developer ID-signed archive was also launched directly from
`dist/PageLumen.xcarchive/Products/Applications/PageLumen.app`; this host again
produced no running process or matching unified-log event. The archive itself
passes `codesign --verify --deep --strict` and the release validator, so this is
recorded as a host GUI/runtime limitation rather than an application assertion.

On 20 August 2026 at 20:29 IST, a fresh explicit-arm64 run using the command
above reached `Testing started` but stalled before worker materialization. On
interruption, Xcode reported `waiting for workers to materialize` and
`Xcode.IDEFoundation.Launcher.LaunchServices`; the result bundle is
`~/Library/Developer/Xcode/DerivedData/PageLumen-hbeprxkxvdpbnyeekgojupdmzjpn/Logs/Test/Test-PageLumen-2026.08.20_20-29-27-+0530.xcresult`.
No UI assertions are counted as passed. A real signed app window was separately
captured in the same GUI session, so this remains a test-runner infrastructure
limitation rather than evidence that the app cannot render.

After stopping six stale PageLumen app instances, an isolated single-test run
was retried at 20:37 IST with fresh module-cache paths. It reproduced the same
LaunchServices worker stall. `xcresulttool` reports one failed runner target
(`PageLumenUITests-Runner ... encountered an error`, `Testing was canceled`),
zero passed tests, and no test statistics. The result bundle is
`~/Library/Developer/Xcode/DerivedData/PageLumen-hbeprxkxvdpbnyeekgojupdmzjpn/Logs/Test/Test-PageLumen-2026.08.20_20-37-34-+0530.xcresult`.
