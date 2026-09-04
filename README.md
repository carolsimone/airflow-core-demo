# airflow-core-demo — START HERE

Two teams, two separate Airflows, one shared warehouse. This is what a dbt pipeline looks like *before* Continuo. `core` (upstream) and `finance` (downstream), plus a scripted cross-team break.

## The point

`core` runs at 02:00, `finance` runs at 03:00 on a **separate** Airflow. `finance` reads a table `core` owns (`revenue_per_user`) but has no dependency edge to core's run — it fires at 03:00 whether core finished, failed, or renamed a column. That guess is the bug Continuo removes.

## Prerequisites

- Docker + Docker Compose
- A sibling `../continuo-demo` checkout — only needed to re-vendor dbt projects via `scripts/sync-dbt.sh`, not for this walkthrough
- Ports 8080, 8081 free. The warehouse publishes 5432; if your host already binds 5432, see "Notes" below

## Run the "before" (happy path)

Start the core team's stack (this also starts the shared warehouse):

```bash
cd airflow-core-demo && make up
```

Wait until `core_daily` shows up at http://localhost:8080 (admin/admin) — the scheduler needs a moment to parse it after `up` returns — then trigger it and wait for green:

```bash
docker compose exec -T scheduler airflow dags trigger core_daily
```

Then start the finance team's stack (separate Airflow, same warehouse), wait for `finance_daily` at http://localhost:8081, and trigger it:

```bash
cd ../airflow-finance-demo && make up
docker compose exec -T scheduler airflow dags trigger finance_daily
```

Result: both green. finance's `analytics.ltv_per_user` is built on core's `revenue_per_user`.

## Break it (the point)

```bash
cd ../airflow-core-demo && make break        # core renames revenue_per_user's output column revenue_eur -> net_revenue_eur
docker compose restart scheduler webserver
docker compose exec -T scheduler airflow dags trigger core_daily      # core STILL GREEN — its own tests pass

cd ../airflow-finance-demo
docker compose exec -T scheduler airflow dags trigger finance_daily   # FAILS: column "revenue_eur" does not exist
```

The lesson, one line: core's release passed every check core owns. Nothing core runs knows finance reads that column. Two separate schedulers can't catch it.

[screenshot slot: 8080 green next to 8081 red]

## Reset

```bash
cd ../airflow-core-demo && make reset && docker compose restart scheduler webserver
docker compose exec -T scheduler airflow dags trigger core_daily

cd ../airflow-finance-demo && docker compose exec -T scheduler airflow dags trigger finance_daily   # green again
```

## The "after"

On Continuo the same change is rejected at release time, before it ships, because Continuo validates the whole topology — not just the changed project. See [continuo-demo](https://github.com/carolsimone/continuo-demo) and the article [link placeholder].

## Dependency map (short)

`finance.ltv_per_user → analytics.revenue_per_user (core)` is the featured edge. `fx_transactions_eur` and `marketing_cost_per_user` are pre-loaded fixtures (frozen tables, not teams): `fx_transactions_eur` lets `core` build standalone, and `marketing_cost_per_user` lets `finance` run without a marketing team. `dbt_daily_kpis` is excluded — it belongs to a python service outside this two-team demo.

## Notes / troubleshooting

- **Host port 5432 already bound?** Create a gitignored `docker-compose.override.yml`:
  ```yaml
  services:
    warehouse:
      ports: !override ["5433:5432"]
  ```
- **Fixture load error mentioning `\restrict`?** Your cached `postgres:16` is older than the one the fixtures were dumped with. Refresh:
  ```bash
  docker compose down -v && docker pull postgres:16 && make up
  ```
