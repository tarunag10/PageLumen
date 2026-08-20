#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORPUS_PATH="${ROOT_DIR}/docs/ai-evaluation/corpus-manifest-v1.json"
REPORT_PATH="${ROOT_DIR}/docs/ai-evaluation/metrics-report-v1.json"

command -v jq >/dev/null || { echo "jq is required to validate AI evaluation artifacts" >&2; exit 1; }
for path in "$CORPUS_PATH" "$REPORT_PATH"; do
  [[ -s "$path" ]] || { echo "AI evaluation artifact not found: $path" >&2; exit 1; }
  jq empty "$path"
done

corpus_schema="$(jq -er '.schemaVersion' "$CORPUS_PATH")"
report_schema="$(jq -er '.schemaVersion' "$REPORT_PATH")"
[[ "$corpus_schema" == "1" && "$report_schema" == "1" ]] || {
  echo "AI evaluation artifacts must use schema version 1" >&2
  exit 1
}

corpus_revision="$(jq -er '.revision' "$CORPUS_PATH")"
report_revision="$(jq -er '.corpusRevision' "$REPORT_PATH")"
[[ "$corpus_revision" == "$report_revision" ]] || {
  echo "AI evaluation corpus/report revisions do not match" >&2
  exit 1
}

required_metrics=(citation-precision citation-recall unsupported-claim-rate user-correction-rate description-usefulness latency availability-failure-rate energy-memory-cost)
for index in "${!required_metrics[@]}"; do
  expected="${required_metrics[$index]}"
  actual="$(jq -er ".metrics[${index}].metricID" "$REPORT_PATH")"
  [[ "$actual" == "$expected" ]] || {
    echo "metrics.${index}.metricID must be ${expected}" >&2
    exit 1
  }
done

# A report may remain a documented scaffold, but it must never claim a
# measurement without run metadata or silently turn an unavailable value into
# a zero. The same rules are enforced by EvaluationContract in Swift; this
# shell gate protects CI and release review before package tests run.
if jq -e '.run == null and any(.metrics[]; .status == "measured")' "$REPORT_PATH" >/dev/null; then
  echo "Measured AI metrics require run metadata" >&2
  exit 1
fi
if jq -e 'any(.metrics[]; (.status == "unavailable" and .value != null) or (.status == "measured" and .value == null) or (.status == "unavailable" and ((.unavailableReason // "") | length == 0)))' "$REPORT_PATH" >/dev/null; then
  echo "AI metric status/value/reason contract is invalid" >&2
  exit 1
fi

echo "AI evaluation artifacts are valid: revision ${report_revision}; measured runs remain explicit."
