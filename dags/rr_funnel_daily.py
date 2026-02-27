from datetime import timedelta

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG
from pendulum import datetime

TARGET_DATE_TEMPLATE = "{{ dag_run.conf.get('target_date') if dag_run and dag_run.conf and dag_run.conf.get('target_date') else (dag_run.logical_date if dag_run.logical_date else dag_run.run_after).astimezone(dag.timezone).strftime('%Y-%m-%d') }}"
RUN_ID_TEMPLATE = "{{ run_id }}"

with DAG(
    dag_id="rr_funnel_daily",
    description="RetailRocket clickstream: raw -> funnel/cohort/CRM -> quality -> export",
    schedule="0 9 * * *",
    start_date=datetime(2015, 5, 3, tz="Asia/Seoul"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    tags=["rr", "funnel", "cohort", "portfolio"],
) as dag:

    check_raw_freshness = BashOperator(
        task_id="check_raw_freshness",
        bash_command=(
            "cd /opt/airflow/project && "
            "python -m scripts.check_raw_freshness "
            "--data-dir data/raw/retailrocket "
            "--max-age-hours ${RAW_FRESHNESS_MAX_HOURS:-168}"
        ),
    )

    load_raw_rr = BashOperator(
        task_id="load_raw_rr",
        bash_command=(
            "cd /opt/airflow/project && "
            "python -m scripts.load_raw.load_retailrocket "
            "--data-dir data/raw/retailrocket "
            "--events-limit ${RR_EVENTS_LIMIT:-300000} "
            "--properties ${RR_PROPERTIES:-categoryid,available} "
            "--properties-limit ${RR_PROPERTIES_LIMIT:-2000000} "
            "--filter-properties-by-event-items"
        ),
    )

    build_staging = BashOperator(
        task_id="build_staging",
        bash_command=(
            "cd /opt/airflow/project && "
            "python -m scripts.run_sql_dir --dir ${SQL_ROOT:-sql/retailrocket}/10_staging"
        ),
    )

    build_mart = BashOperator(
        task_id="build_mart",
        bash_command=(
            "cd /opt/airflow/project && "
            "python -m scripts.run_sql_dir --dir ${SQL_ROOT:-sql/retailrocket}/20_mart"
        ),
    )

    compute_kpis = BashOperator(
        task_id="compute_kpis",
        bash_command=(
            "cd /opt/airflow/project && "
            "python -m scripts.run_sql_dir "
            "--dir ${SQL_ROOT:-sql/retailrocket}/30_kpi "
            f"--target-date {TARGET_DATE_TEMPLATE}"
        ),
    )

    run_quality_checks = BashOperator(
        task_id="run_quality_checks",
        bash_command=(
            "cd /opt/airflow/project && "
            "python -m scripts.run_quality_checks "
            "--dir ${SQL_ROOT:-sql/retailrocket}/90_quality "
            f"--target-date {TARGET_DATE_TEMPLATE} --run-id {RUN_ID_TEMPLATE}"
        ),
    )

    export_funnel = BashOperator(
        task_id="export_funnel_csv",
        bash_command=(
            "cd /opt/airflow/project && "
            f"python -m scripts.export_rr_funnel_csv --target-date {TARGET_DATE_TEMPLATE} "
            f"--output-path /opt/airflow/logs/reports/rr_funnel_daily_{TARGET_DATE_TEMPLATE}.csv"
        ),
    )

    export_cohort = BashOperator(
        task_id="export_cohort_csv",
        bash_command=(
            "cd /opt/airflow/project && "
            f"python -m scripts.export_rr_cohort_csv "
            f"--output-path /opt/airflow/logs/reports/rr_cohort_weekly_{TARGET_DATE_TEMPLATE}.csv"
        ),
    )

    export_crm = BashOperator(
        task_id="export_crm_targets_csv",
        bash_command=(
            "cd /opt/airflow/project && "
            f"python -m scripts.export_rr_crm_targets_csv --target-date {TARGET_DATE_TEMPLATE} "
            f"--output-path /opt/airflow/logs/reports/rr_crm_targets_{TARGET_DATE_TEMPLATE}.csv"
        ),
    )

    write_summary = BashOperator(
        task_id="write_pipeline_summary",
        bash_command=(
            "cd /opt/airflow/project && "
            "python -m scripts.write_rr_pipeline_summary "
            f"--target-date {TARGET_DATE_TEMPLATE} "
            f"--run-id {RUN_ID_TEMPLATE} "
            f"--output-path /opt/airflow/logs/reports/rr_pipeline_summary_{TARGET_DATE_TEMPLATE}.txt"
        ),
    )

    (
        check_raw_freshness
        >> load_raw_rr
        >> build_staging
        >> build_mart
        >> compute_kpis
        >> run_quality_checks
        >> export_funnel
        >> export_cohort
        >> export_crm
        >> write_summary
    )
