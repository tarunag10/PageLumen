# Screen capture behavior

PageLumen requests Screen Recording access immediately before a capture. A
denied request produces a permission-specific message and does not launch the
interactive picker. The user can grant access in **System Settings → Privacy &
Security → Screen Recording** and retry.

For window capture on macOS 14 and later, PageLumen uses
`SCContentSharingPicker`. The picker is configured for a single window and
capture does not inspect a window or create a filter until the person selects
one. Dismissing the picker is reported as **Screenshot capture was cancelled.**
For selected-region capture, PageLumen continues to use Apple's interactive
`screencapture -i` surface because `SCContentSharingPicker` does not expose a
freeform rectangle. On older systems the window mode uses the interactive
`screencapture -w` picker. Neither path ever chooses the first eligible
window, and there is no fallback after a picker cancellation or modern API
failure.

ScreenCaptureKit paths remain availability-gated. Their cancellation errors are
normalized to the same cancellation state; other API errors remain visibly
distinct from permission denial. Manual validation is still required on each
supported macOS release because TCC prompts and picker behavior are system UI.
