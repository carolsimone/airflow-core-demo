#!/usr/bin/env bash
# Re-vendor dbt/ from continuo-demo's core project. Single source of truth is
# continuo-demo; run before every launch. Dockerfile*/entrypoint.sh excluded —
# Airflow runs dbt directly, not the service image.
set -euo pipefail
SRC="${1:-../continuo-demo/services/core}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
rsync -a --delete \
  --exclude 'Dockerfile' --exclude 'Dockerfile.local' --exclude 'entrypoint.sh' \
  "$SRC/" "$HERE/dbt/"
echo "vendored $SRC -> $HERE/dbt"
