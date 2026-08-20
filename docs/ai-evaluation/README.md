# AI evaluation artifacts

These artifacts are intentionally separate from product documents and contain
no user documents or fabricated quality scores:

- `corpus-manifest-v1.json` — consent/separation contract and adversarial sample manifest.
- `metrics-report-v1.json` — task metrics and an explicitly unavailable scaffold report.
- `human-review-rubric-v1.md` — accessibility-aware review questions and stop conditions.
- `launch-thresholds-v1.md` — predeclared-threshold template and release rules.

Run `./script/validate_ai_evaluation.sh` (or `make ai-evaluation`) before
reviewing or replacing the report. The gate accepts an explicitly unavailable
scaffold, but rejects measured values without run metadata, missing values, or
unavailable metrics without a reason. It is a contract check, not evidence
that a consented model comparison has been performed.

`Sources/PageLumenCore/EvaluationContract.swift` is the deterministic schema
validator used by tests. Any future measured report must include exact model,
Xcode, macOS, device, corpus revision, and processing-profile metadata.

`ModelComparator` is the fail-closed decision boundary for a future
Foundation-Models comparison: both snapshots must use the same corpus and
provide finite unsupported-claim and cost measurements. It prefers lower
unsupported-claim rate, then higher citation coverage when both are measured,
then lower operational cost. It never treats missing or non-finite values as
zero, and the current repository does not claim that a consented comparison
run has occurred.
