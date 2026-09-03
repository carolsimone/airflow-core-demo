#!/usr/bin/env bash
# Regenerate fixtures/10_marketing_cost_per_user.sql and
# fixtures/20_fx_transactions_eur.sql from continuo-demo's marketing and
# finance projects. user_ids stay consistent with core's seed_users because
# all of these derive from the same committed continuo-demo seeds. Run only
# when the marketing/finance seeds or the fx_transactions_eur model change.
#
# fx_transactions_eur is frozen as a static fixture (like marketing_cost_per_user)
# so core's Airflow stack can build standalone: finance's fx_transactions_eur.sql
# reads only two seeds (core's seed_fx_transactions, finance's own
# seed_fx_rates_eur) -- no other models -- so it can be pre-materialized once
# and checked in, breaking the core<->finance circular first-run dependency
# without editing any dbt model.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MKT="${1:-../continuo-demo/services/marketing}"
CORE="${2:-../continuo-demo/services/core}"
FIN="${3:-../continuo-demo/services/finance}"
CID=$(docker run -d --rm -e POSTGRES_DB=continuo_dbt -e POSTGRES_USER=continuo_svc \
  -e POSTGRES_PASSWORD=runner -p 55432:5432 postgres:16)
trap 'docker stop "$CID" >/dev/null' EXIT
until docker exec "$CID" pg_isready -U continuo_svc -d continuo_dbt >/dev/null 2>&1; do sleep 1; done
python3 -m venv /tmp/dbtfix && /tmp/dbtfix/bin/pip -q install "dbt-core==1.12.0b1" "dbt-postgres==1.10.0"

# --- marketing_cost_per_user (static fixture; unchanged) ---
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

# --- fx_transactions_eur (static fixture; new) ---
POSTGRES_HOST=localhost POSTGRES_PORT=55432 POSTGRES_DB=continuo_dbt \
POSTGRES_USER=continuo_svc POSTGRES_PASSWORD=runner \
  /tmp/dbtfix/bin/dbt seed --project-dir "$CORE" --profiles-dir "$CORE"
POSTGRES_HOST=localhost POSTGRES_PORT=55432 POSTGRES_DB=continuo_dbt \
POSTGRES_USER=continuo_svc POSTGRES_PASSWORD=runner \
  /tmp/dbtfix/bin/dbt seed --project-dir "$FIN" --profiles-dir "$FIN"
POSTGRES_HOST=localhost POSTGRES_PORT=55432 POSTGRES_DB=continuo_dbt \
POSTGRES_USER=continuo_svc POSTGRES_PASSWORD=runner \
  /tmp/dbtfix/bin/dbt run --project-dir "$FIN" --profiles-dir "$FIN" --select fx_transactions_eur
docker exec "$CID" pg_dump -U continuo_svc -d continuo_dbt \
  --table=analytics.fx_transactions_eur --no-owner --no-privileges \
  > "$HERE/fixtures/20_fx_transactions_eur.sql"
echo "wrote $HERE/fixtures/20_fx_transactions_eur.sql"
