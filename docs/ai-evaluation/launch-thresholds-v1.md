# PageLumen AI launch-threshold template v1

Thresholds are intentionally blank until the corpus, consent, and review
protocol are approved. This file prevents post-hoc threshold selection; it is
not evidence that the current implementation passes any quality bar.

Before an experimental feature can leave opt-in mode, complete one signed
record containing:

| Field | Required value |
| --- | --- |
| Corpus revision | `v1` or a reviewed successor |
| Consent version/status | Approved, current, and product documents excluded |
| Task set | Declared task IDs; no cherry-picking |
| Model/provider | Exact identifier and adapter version |
| Xcode/macOS/device | Exact versions and supported-device class |
| Run ID/time | Reproducible run identifier and timestamp |
| Threshold approval | Product owner plus accessibility advisor |

## Threshold table

Fill every threshold before collecting final scores. Use a directionally clear
bound (minimum for higher-is-better, maximum for lower-is-better), and record
the rationale and confidence interval method.

| Metric | Direction | Launch threshold | Observed value | Status | Rationale/owner |
| --- | --- | --- | --- | --- | --- |
| Citation precision | Higher | TBD | Not run | Blocked | Grounding review |
| Citation recall | Higher | TBD | Not run | Blocked | Grounding review |
| Unsupported-claim rate | Lower | TBD | Not run | Blocked | Safety review |
| User-correction rate | Lower | TBD | Not run | Blocked | Participant study |
| Description usefulness | Higher | TBD | Not run | Blocked | Accessibility advisor |
| Latency | Lower | TBD | Not run | Blocked | Device run |
| Availability failure rate | Lower | TBD | Not run | Blocked | Device matrix |
| Energy/memory cost | Lower | TBD | Not run | Blocked | Device run |

The feature remains experimental when any metric is `Not run`, a threshold is
`TBD`, a rubric stop condition occurs, or a supported-device fallback fails.
