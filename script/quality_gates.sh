#!/bin/zsh
set -euo pipefail

echo "Checking whitespace"
git diff --check
echo "Checking privacy manifest"
plutil -lint Config/PrivacyInfo.xcprivacy
echo "Checking required baseline and plan artifacts"
test -s docs/performance-baseline-2026-08-20.md
test -s docs/superpowers/plans/2026-08-20-comprehensive-product-implementation-plan.md
echo "Quality gates passed"
