#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX_PATH="${1:-${ROOT_DIR}/docs/privacy-matrix-v1.json}"
MANIFEST_PATH="${ROOT_DIR}/Config/PrivacyInfo.xcprivacy"

[[ -f "$MATRIX_PATH" ]] || { echo "Privacy matrix not found: $MATRIX_PATH" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required to validate the privacy matrix" >&2; exit 1; }
jq empty "$MATRIX_PATH"
plutil -lint "$MANIFEST_PATH" >/dev/null

extract() { jq -er "$1" "$MATRIX_PATH"; }
[[ "$(extract '.schemaVersion')" == "1" ]] || { echo "Unsupported privacy matrix schema" >&2; exit 1; }
[[ "$(extract '.product')" == "PageLumen" ]] || { echo "Privacy matrix product must be PageLumen" >&2; exit 1; }
[[ "$(extract '.appStoreNutritionLabel.tracking')" == "false" ]] || { echo "Tracking must remain false" >&2; exit 1; }
[[ "$(extract '.appStoreNutritionLabel.dataTypesCollected | length')" == "0" ]] || { echo "Current matrix must not claim collected data types" >&2; exit 1; }
[[ "$(extract '.behaviours | length')" -ge 6 ]] || { echo "Privacy matrix is missing behaviour rows" >&2; exit 1; }

ids="$(extract '[.behaviours[].id] | unique | length')"
rows="$(extract '.behaviours | length')"
[[ "$ids" == "$rows" ]] || { echo "Privacy behaviour IDs must be unique" >&2; exit 1; }
[[ "$(extract '[.behaviours[] | select((.evidence | length) == 0)] | length')" == "0" ]] || { echo "Every privacy row needs source evidence" >&2; exit 1; }
[[ "$(extract '[.behaviours[] | select(.developerCollection != false or .usedForTracking != false)] | length')" == "0" ]] || { echo "Matrix contradicts the no-collection/no-tracking posture" >&2; exit 1; }
[[ "$(extract '[.recheckTriggers[]] | length')" -ge 4 ]] || { echo "Privacy recheck triggers are incomplete" >&2; exit 1; }

grep -q 'NSPrivacyTracking' "$MANIFEST_PATH"
grep -q 'NSPrivacyAccessedAPICategoryUserDefaults' "$MANIFEST_PATH"
grep -q 'privacy-matrix-v1.json' "${ROOT_DIR}/docs/privacy.md"
while IFS= read -r path; do
  [[ -f "${ROOT_DIR}/${path}" ]] || { echo "Missing privacy evidence: ${path}" >&2; exit 1; }
done < <(extract '.behaviours[].evidence[]' | sort -u)

echo "Privacy matrix is valid: $MATRIX_PATH"
echo "App Store nutrition-label answers remain a release-owner/legal review gate for conditional platform and user-managed transfers."
