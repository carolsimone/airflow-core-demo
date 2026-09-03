#!/usr/bin/env bash
# Revert the break — restore the vendored project to HEAD and clear any *.bak.
set -euo pipefail
cd "$(dirname "$0")/.."
find dbt -name '*.bak' -delete 2>/dev/null || true
git checkout -- dbt/
echo "break reverted"
