# Release preflight

Run `make release-preflight` before attempting `script/package_release.sh`.
The check validates repository artifacts and local tooling, reports whether a
Developer ID Application identity is present, and identifies writable build
paths. It does not sign, notarize, upload, submit, or mutate release state.

In restricted automation environments, a missing signing identity or protected
SwiftPM/Xcode cache is an environment prerequisite failure—not evidence that
the source archive, notarization, or App Review state succeeded.
