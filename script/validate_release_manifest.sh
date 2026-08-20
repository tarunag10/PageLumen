#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="${1:-${ROOT_DIR}/docs/release-manifest-v1.json}"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Release manifest not found: $MANIFEST_PATH" >&2
  exit 1
fi

command -v jq >/dev/null || { echo "jq is required to validate JSON release manifests" >&2; exit 1; }
jq empty "$MANIFEST_PATH"

extract() {
  jq -er "$1" "$MANIFEST_PATH"
}

[[ "$(extract '.schemaVersion')" == "1" ]] || { echo "Unsupported release manifest schema" >&2; exit 1; }
[[ "$(extract '.product')" == "PageLumen" ]] || { echo "Release manifest product must be PageLumen" >&2; exit 1; }
[[ "$(extract '.minimumMacOS')" == "14.0" ]] || { echo "minimumMacOS must remain 14.0 until the product target changes" >&2; exit 1; }
[[ "$(extract '.artifactPolicy.ci')" == "unsigned-build-only" ]] || { echo "CI must not require signing credentials" >&2; exit 1; }
[[ "$(extract '.artifactPolicy.distribution')" == "signed-archive-required" ]] || { echo "Distribution must require a signed archive" >&2; exit 1; }
[[ "$(extract '.signing.requiredForDistribution')" == "true" ]] || { echo "Distribution signing requirement is missing" >&2; exit 1; }
[[ "$(extract '.signing.ciSigning')" == "disabled" ]] || { echo "CI signing must be disabled" >&2; exit 1; }
[[ "$(extract '.versionSource')" == "project.yml" ]] || { echo "Version source must be project.yml" >&2; exit 1; }

required_evidence=(archive bundle-validation privacy-manifest entitlements checksum external-state-disclosure)
for index in "${!required_evidence[@]}"; do
  value="$(extract ".requiredEvidence[${index}]")"
  [[ "$value" == "${required_evidence[$index]}" ]] || {
    echo "requiredEvidence.${index} must be ${required_evidence[$index]}" >&2
    exit 1
  }
done

disclosure="$(extract '.externalStateDisclosure')"
[[ "$disclosure" == *"do not prove notarization"* ]] || {
  echo "Manifest must disclose the boundary between local evidence and notarization" >&2
  exit 1
}

echo "Release manifest is valid: $MANIFEST_PATH"
echo "Signing and external distribution remain explicit release-owner gates."
