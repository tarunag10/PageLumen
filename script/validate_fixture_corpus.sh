#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METRICS_PATH="${ROOT_DIR}/docs/fixtures/corpus-metrics-v1.json"
AI_PATH="${ROOT_DIR}/docs/ai-evaluation/corpus-manifest-v1.json"

for path in "$METRICS_PATH" "$AI_PATH"; do
  [[ -f "$path" ]] || { echo "Fixture manifest not found: $path" >&2; exit 1; }
  command -v jq >/dev/null || { echo "jq is required to validate JSON fixture manifests" >&2; exit 1; }
  jq empty "$path"
done

metrics() { jq -er ".$1" "$METRICS_PATH"; }
ai() { jq -er ".$1" "$AI_PATH"; }

[[ "$(metrics schemaVersion)" == "1" ]] || { echo "Unsupported fixture metrics schema" >&2; exit 1; }
[[ "$(metrics status)" == "scaffold-only" ]] || { echo "Unexpected fixture metrics status" >&2; exit 1; }

fixture_ids=(two-column-paper three-column-paper legal-filing form receipt slides multi-page-table chart rotated-page multilingual-text low-quality-scan handwriting equations ocr-traps)
for index in "${!fixture_ids[@]}"; do
  value="$(metrics "fixtures[${index}].id")"
  [[ "$value" == "${fixture_ids[$index]}" ]] || {
    echo "fixtures.${index}.id must be ${fixture_ids[$index]}" >&2
    exit 1
  }
done

for metric in characterErrorRate wordErrorRate readingOrderAccuracy tableCellAccuracy falseHeadingRate processingTimeMilliseconds; do
  [[ "$(metrics "metrics.${metric}")" == "null" ]] || {
    echo "${metric} must remain null until the consented physical-device gate is complete" >&2
    exit 1
  }
done

[[ "$(ai schemaVersion)" == "1" ]] || { echo "Unsupported AI evaluation manifest schema" >&2; exit 1; }
[[ "$(ai consent.productDocumentsExcluded)" == "true" ]] || {
  echo "AI evaluation corpus must exclude product documents" >&2
  exit 1
}
[[ "$(ai consent.status)" == "pending" ]] || {
  echo "AI evaluation consent status must be explicitly pending until approved" >&2
  exit 1
}

adversarial_ids=(adv-incorrect-ocr adv-misleading-caption adv-conflicting-values adv-hidden-text adv-chart-without-values adv-multilingual adv-sensitive-legal-medical)
for index in "${!adversarial_ids[@]}"; do
  value="$(ai "samples[${index}].id")"
  [[ "$value" == "${adversarial_ids[$index]}" ]] || {
    echo "samples.${index}.id must be ${adversarial_ids[$index]}" >&2
    exit 1
  }
done

echo "Fixture corpus manifests are valid and contain the complete bounded scaffold."
echo "OCR accuracy and AI launch metrics remain unavailable/pending by policy."
