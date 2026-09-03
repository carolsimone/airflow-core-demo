from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator

DBT = "/opt/dbt-venv/bin/dbt"
PROJECT = "/opt/dbt/core"                      # dbt/ is mounted here by compose
COMMON = f"--project-dir {PROJECT} --profiles-dir {PROJECT}"

# core runs at 02:00. Its POSTGRES_* env (the shared warehouse) comes from
# compose. Nothing downstream is told when this run actually finishes.
with DAG(
    dag_id="core_daily",
    start_date=datetime(2026, 1, 1),
    schedule="0 2 * * *",
    catchup=False,
    tags=["core"],
) as dag:
    seed = BashOperator(task_id="dbt_seed", bash_command=f"{DBT} seed {COMMON}")
    run = BashOperator(task_id="dbt_run", bash_command=f"{DBT} run {COMMON}")
    test = BashOperator(task_id="dbt_test", bash_command=f"{DBT} test {COMMON}")
    seed >> run >> test
