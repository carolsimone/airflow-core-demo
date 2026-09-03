from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator

DBT = "/opt/dbt-venv/bin/dbt"
PROJECT = "/opt/dbt/core"                      # dbt/ is mounted here by compose
COMMON = f"--project-dir {PROJECT} --profiles-dir {PROJECT}"

# core runs at 02:00. Its POSTGRES_* env (the shared warehouse) comes from
# compose. Nothing downstream is told when this run actually finishes.
#
# dbt_daily_kpis reads FROM analytics.py_daily_kpis, owned by service-py --
# a service outside this two-team (core/finance) demo, with no producer
# anywhere in this repo set. Excluded at the DAG level (not the dbt model)
# so core's own build stays green without touching vendored model files.
with DAG(
    dag_id="core_daily",
    start_date=datetime(2026, 1, 1),
    schedule="0 2 * * *",
    catchup=False,
    tags=["core"],
) as dag:
    seed = BashOperator(task_id="dbt_seed", bash_command=f"{DBT} seed {COMMON}")
    run = BashOperator(task_id="dbt_run", bash_command=f"{DBT} run --exclude dbt_daily_kpis {COMMON}")
    test = BashOperator(task_id="dbt_test", bash_command=f"{DBT} test --exclude dbt_daily_kpis {COMMON}")
    seed >> run >> test
