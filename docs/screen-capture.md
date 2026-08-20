# Screen capture behavior

PageLumen requests Screen Recording access immediately before a capture. A
denied request produces a permission-specific message and does not launch the
interactive picker. The user can grant access in **System Settings → Privacy &
Security → Screen Recording** and retry.

The current supported capture path uses Apple's interactive `screencapture`
picker so the user chooses the region or window. Dismissing that picker is
reported as **Screenshot capture was cancelled.** A non-zero command status
other than the documented cancellation status is reported as a capture
failure. PageLumen does not retry with another capture path after permission
denial or picker cancellation, and it never silently selects the first window.

ScreenCaptureKit helper paths remain availability-gated platform work. Their
cancellation errors are normalized to the same cancellation state; other API
errors remain visibly distinct from permission denial. Manual validation is
still required on each supported macOS release because TCC prompts and picker
behavior are system UI.
