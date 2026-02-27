# da-airflow-retailrocket

Apache Airflow 기반 RetailRocket 데이터 파이프라인 프로젝트입니다.

`rr_funnel_daily` DAG가 아래 흐름을 자동화합니다.

`raw 적재 -> staging -> mart -> KPI -> quality check -> CSV export`

---

## 1) 주요 기능

- `BashOperator` 기반 ETL/ELT 파이프라인
- 일 단위 Funnel KPI 계산
- Cohort/CRM 타겟 산출
- 품질 검증 SQL 실행
- 리포트 CSV/TXT export 생성

---

## 2) DAG 정보

- DAG ID: `rr_funnel_daily`
- Schedule: `0 9 * * *` (Asia/Seoul 기준 일 1회)
- `catchup=False` (대량 자동 백필 방지)
- 수동 백필 시 `dag_run.conf.target_date` 지원 (예: `2015-09-18`)

---

## 3) 빠른 실행

### 3-1. 컨테이너 기동

```bash
make up
```

### 3-2. DDL 초기화

```bash
make init
```

### 3-3. DAG 수동 트리거

```bash
make run-dag
```

### 3-4. 특정 날짜 백필 실행

```bash
docker compose exec -T airflow-apiserver \
  airflow dags trigger rr_funnel_daily \
  -r manual_backfill_2015-09-18 \
  -c '{"target_date":"2015-09-18"}'
```

### 3-5. 실행 상태 확인

```bash
docker compose exec -T airflow-apiserver airflow dags list-runs rr_funnel_daily -o table
docker compose exec -T airflow-apiserver airflow tasks states-for-dag-run rr_funnel_daily <run_id>
```

---

## 4) 결과물 위치

성공 시 아래 파일이 생성됩니다.

- `logs/reports/rr_funnel_daily_<target_date>.csv`
- `logs/reports/rr_cohort_weekly_<target_date>.csv`
- `logs/reports/rr_crm_targets_<target_date>.csv`
- `logs/reports/rr_pipeline_summary_<target_date>.txt`

---

## 5) 저장소 업로드 가이드

### 커밋 권장

- `dags/`
- `scripts/`
- `sql/`
- `docker-compose.yml`, `Dockerfile`, `Makefile`, `requirements.txt`
- `README.md`, `.env.example`

### 커밋 제외

- `.env` 및 민감정보
- `logs/`, `exports/`, `.omx/`
- 대용량 원본데이터(`data/raw/`)

