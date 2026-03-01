# Runbook

## Quickstart

```bash
cp .env.example .env
make up
make init
make run-dag
```

## Backfill (target_date 지정)
1. Airflow UI에서 DAG `rr_funnel_daily`를 선택합니다.
2. **Trigger DAG w/ config**에서 아래처럼 입력합니다.

```json
{"target_date":"2015-06-16"}
```

## Verification
아래 4개 파일이 생성되었는지 확인합니다.

```text
logs/reports/rr_funnel_daily_2015-06-16.csv
logs/reports/rr_cohort_weekly_2015-06-16.csv
logs/reports/rr_crm_targets_2015-06-16.csv
logs/reports/rr_pipeline_summary_2015-06-16.txt
```

## 실패 TOP3
- **airflow-apiserver up 상태 확인**: `docker compose ps`에서 `airflow-apiserver`가 Up/healthy인지 확인
- **환경 변수 확인(.env)**: DB 접속 정보/secret 값이 누락되지 않았는지 확인
- **DB 컨테이너 준비/연결 확인**: `postgres` 컨테이너 healthy + 연결 가능한지 확인
