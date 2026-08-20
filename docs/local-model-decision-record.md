# Optional local-model decision record

Updated 20 August 2026.

## Current decision

PageLumen does not add MLX Swift, `mlx-swift-lm`, `swift-transformers`,
WhisperKit, or downloaded model weights to the default product pipeline. The
shipping path remains deterministic OCR/export plus the opt-in Apple
Foundation Models adapter and its deterministic fallback.

This is an explicit scope decision, not an evaluation result. No model has
been downloaded, benchmarked, or represented as supported by this record.

The isolated metadata-only prototype boundary is now represented by
`LocalModelPrototypeManifest` and `LocalModelPrototypeGate` in
`PageLumenCore`. It validates repository/model-card URLs, immutable revision,
license, weight-size, and safe storage metadata, then fails closed unless
prototype enablement, explicit consent, removal policy, and device gates are
all supplied. It does not download weights, persist consent, or alter the
default pipeline. The remaining model-card/license review, real download
manager, and Foundation Models comparison are intentionally not claimed.

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

`ModelComparator` in `PageLumenCore` provides the evaluation boundary:
Foundation Models and a future prototype must submit measured snapshots for
the same corpus revision. It prefers lower unsupported-claim rate, then lower
operational cost, and returns an explicit unavailable/incomparable decision
when required evidence is missing. No model comparison has been run yet.
