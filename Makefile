.PHONY: up down init run-dag run-dag-backfill psql check logs run-linux fmt lint

PORTFOLIO_TARGET_DATE ?= 2015-06-16

up:
	test -f .env || cp .env.example .env
	docker compose up -d --build

down:
	docker compose down

init:
	docker compose exec airflow-apiserver bash -lc "cd /opt/airflow/project && python -m scripts.run_sql_dir --dir $${SQL_ROOT:-sql/retailrocket}/00_ddl"

run-dag:
	docker compose exec airflow-apiserver airflow dags trigger rr_funnel_daily

run-dag-backfill:
	docker compose exec airflow-apiserver airflow dags trigger rr_funnel_daily --conf '{"target_date":"$(PORTFOLIO_TARGET_DATE)"}'

psql:
	docker compose exec postgres psql -U airflow -d warehouse

check:
	docker compose exec airflow-apiserver bash -lc "cd /opt/airflow/project && python -m scripts.check_tables_rr"

logs:
	docker compose logs -f airflow-scheduler airflow-apiserver airflow-dag-processor

run-linux:
	docker compose exec airflow-apiserver bash -lc "cd /opt/airflow/project && bash ./scripts/run_pipeline_linux_rr.sh"

fmt:
	python3 -m black dags scripts

lint:
	python3 -m ruff check dags scripts
