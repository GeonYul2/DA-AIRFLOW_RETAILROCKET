# Runbook

## 기본 실행

```bash
cp .env.example .env
make up
make init
make run-dag
make check
```

## 수동 백필

- Airflow UI에서 DAG `rr_funnel_daily` 트리거
- `dag_run.conf.target_date` 지정 (예: `2015-09-18`)

## 산출물 확인

```text
logs/reports/rr_funnel_daily_<target_date>.csv
logs/reports/rr_cohort_weekly_<target_date>.csv
logs/reports/rr_crm_targets_<target_date>.csv
logs/reports/rr_pipeline_summary_<target_date>.txt
```

## 트러블슈팅

### Jinja 템플릿 datetime 타입 오류

- 증상: `in_timezone` 호출 시 타입 불일치
- 조치:
  1. datetime 호환 템플릿 사용
  2. `dag_run.conf.target_date` 우선 처리
  3. `catchup=False` 유지
