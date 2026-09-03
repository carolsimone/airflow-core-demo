FROM apache/airflow:2.10.5-python3.12
# dbt in an isolated venv so its pins never fight Airflow's own dependency set.
# Defaults are the authoritative continuo-demo pins (e2e-validated). A build-arg
# override exists ONLY for environments whose pip mirror lacks the beta build —
# never relax the pin upward: an unpinned/newer dbt-core resolves to dbt Fusion,
# which refuses Postgres.
ARG DBT_CORE_VERSION=1.12.0b1
ARG DBT_POSTGRES_VERSION=1.10.0
# The base image's default user (airflow, uid 50000) can't write to /opt, so
# build the venv as root, hand it back to airflow, then drop privileges again
# to match the base image's own runtime user.
USER root
RUN python -m venv /opt/dbt-venv \
 && /opt/dbt-venv/bin/pip install --no-cache-dir \
      "dbt-core==${DBT_CORE_VERSION}" "dbt-postgres==${DBT_POSTGRES_VERSION}" \
 && chown -R airflow: /opt/dbt-venv
USER airflow
