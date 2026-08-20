# AI evaluation artifacts

These artifacts are intentionally separate from product documents and contain
no user documents or fabricated quality scores:

- `corpus-manifest-v1.json` — consent/separation contract and adversarial sample manifest.
- `metrics-report-v1.json` — task metrics and an explicitly unavailable scaffold report.
- `human-review-rubric-v1.md` — accessibility-aware review questions and stop conditions.
- `launch-thresholds-v1.md` — predeclared-threshold template and release rules.

`Sources/PageLumenCore/EvaluationContract.swift` is the deterministic schema
validator used by tests. Any future measured report must include exact model,
Xcode, macOS, device, corpus revision, and processing-profile metadata.
