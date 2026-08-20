#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

identities="$(jq -r '.pins[].identity' Package.resolved | sort -u)"
if [ -z "$identities" ]; then
  echo "Package.resolved contains no pins" >&2
  exit 1
fi

missing=0
identity_count=0
while IFS= read -r identity; do
  identity_count=$((identity_count + 1))
  checkout=".build/checkouts/$identity"
  if [ ! -d "$checkout" ]; then
    echo "missing local checkout: $checkout" >&2
    missing=1
  fi
done <<EOF
$identities
EOF
if [ "$missing" -ne 0 ]; then
  echo "Resolve dependencies once online, then rerun this offline readiness check." >&2
  exit 1
fi

# --skip-update prevents SwiftPM from contacting remotes during these focused
# contract runs. The normal sandbox remains enabled; this is a readiness check
# for already-resolved dependencies, not a claim about App Store distribution.
swift test --skip-update -Xswiftc -gnone --filter MarkdownContractTests >/tmp/pagelumen-offline-markdown.log
swift test --skip-update -Xswiftc -gnone --filter DOCXWriterTests >/tmp/pagelumen-offline-docx.log
swift test --skip-update -Xswiftc -gnone --filter ExportSnapshotTests >/tmp/pagelumen-offline-snapshots.log

echo "Offline dependency readiness passed: resolved checkouts and focused contract suites."
