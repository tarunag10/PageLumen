# Optional local-model decision record

Updated 20 August 2026.

## Current decision

PageLumen does not add MLX Swift, `mlx-swift-lm`, `swift-transformers`,
WhisperKit, or downloaded model weights to the default product pipeline. The
shipping path remains deterministic OCR/export plus the opt-in Apple
Foundation Models adapter and its deterministic fallback.

This is an explicit scope decision, not an evaluation result. No model has
been downloaded, benchmarked, or represented as supported by this record.

## Why

- PageLumen is a document reader/review/export tool, not an audio or general
  local-model runtime.
- Downloaded models introduce license, storage, update, deletion, progress,
  cancellation, memory, and device-capability obligations.
- Foundation Models already supplies the platform-native opt-in path on
  eligible Macs; unsupported or unavailable Macs use the tested deterministic
  result.
- The current product has no audio/lecture import requirement that would
  justify WhisperKit model management.

## Reopen triggers

Reopen only when a product requirement identifies a concrete task that the
platform path cannot meet. A prototype must be isolated from production,
include a model card and license review, pin the model and repository source,
show download size and storage location, provide explicit consent and removal,
support cancellation/progress, and measure device capability and memory.
It must be compared with Foundation Models on the same consented corpus before
any shipping decision.

Until those gates exist, Intel Macs, unsupported Apple-silicon Macs, and Macs
without a ready model remain on the deterministic non-AI fallback. No current
UI or export label claims downloaded-model support.
