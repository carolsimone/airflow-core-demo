#!/usr/bin/env bash
# Regenerate fixtures/10_marketing_cost_per_user.sql from continuo-demo's
# marketing project. user_ids stay consistent with core's seed_users because
# both derive from the same committed continuo-demo seeds. Run only when the
# marketing seeds change.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MKT="${1:-../continuo-demo/services/marketing}"
CID=$(docker run -d --rm -e POSTGRES_DB=continuo_dbt -e POSTGRES_USER=continuo_svc \
  -e POSTGRES_PASSWORD=runner -p 55432:5432 postgres:16)
trap 'docker stop "$CID" >/dev/null' EXIT
until docker exec "$CID" pg_isready -U continuo_svc -d continuo_dbt >/dev/null 2>&1; do sleep 1; done
python3 -m venv /tmp/dbtfix && /tmp/dbtfix/bin/pip -q install "dbt-core==1.12.0b1" "dbt-postgres==1.10.0"
POSTGRES_HOST=localhost POSTGRES_PORT=55432 POSTGRES_DB=continuo_dbt \
POSTGRES_USER=continuo_svc POSTGRES_PASSWORD=runner \
  /tmp/dbtfix/bin/dbt seed --project-dir "$MKT" --profiles-dir "$MKT"
POSTGRES_HOST=localhost POSTGRES_PORT=55432 POSTGRES_DB=continuo_dbt \
POSTGRES_USER=continuo_svc POSTGRES_PASSWORD=runner \
  /tmp/dbtfix/bin/dbt run --project-dir "$MKT" --profiles-dir "$MKT"
docker exec "$CID" pg_dump -U continuo_svc -d continuo_dbt \
  --table=analytics.marketing_cost_per_user --no-owner --no-privileges \
  > "$HERE/fixtures/10_marketing_cost_per_user.sql"
echo "wrote $HERE/fixtures/10_marketing_cost_per_user.sql"
