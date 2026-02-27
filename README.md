# DA-AIRFLOW_RETAILROCKET
**Apache Airflow 기반 RetailRocket clickstream 데이터 파이프라인 포트폴리오**  
`rr_funnel_daily` DAG가 **RAW → STAGING → MART → KPI → QA → EXPORT**를 일 배치로 자동화합니다.

> 목표: “실데이터 기반”으로 **퍼널/코호트/CRM 타겟 산출**까지 연결되는 **운영형 분석 파이프라인**을 구현하고,  
> 지표 정의/데이터 모델/품질 게이트/산출물 전달까지 **End-to-End 재현 가능한 형태**로 제시합니다.

---

## What this project demonstrates (포트폴리오 핵심)
- **Event log 기반 퍼널 분석**: `view → addtocart → transaction` 전환율/병목 구간 산출
- **Sessionization(세션 정의)**: 30분 inactivity 룰로 `session_id` 부여 및 세션 단위 KPI 생성
- **Analytics-ready Mart 설계**: `dim/fact` 구조로 반복 분석 비용 최소화
- **Data Quality Gate 내장**: 도메인/널/무결성/지표 범위 sanity check 자동화
- **Deliverable 중심 산출물**: BI 도구(Tableau Public 등) 업로드 가능한 CSV + 요약 리포트(TXT) 자동 생성

---

## Tech Stack
- **Orchestration**: Apache Airflow (Docker Compose)
- **Warehouse**: PostgreSQL
- **Transform**: SQL (staging/mart/kpi), Python (loader/export)
- **Runtime**: Windows + WSL(개발) / Docker 기반 재현

---

## Dataset (RAW)
원본 파일 경로: `data/raw/retailrocket/` *(원본 데이터는 커밋하지 않습니다)*

- Kaggle: https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset
- 데이터 기간(이벤트 기준): **2015-05-03 ~ 2015-09-18 (KST)**

- `events.csv` — 사용자 이벤트 로그  
  `timestamp, visitorid, event, itemid, transactionid`
- `category_tree.csv` — 카테고리 계층(트리)  
  `categoryid, parentid`
- `item_properties_part1.csv`, `item_properties_part2.csv` — 상품 속성 이력(시간 의존)  
  `timestamp, itemid, property, value`

> Note) 본 데이터는 익명화/ID 기반으로 제공되며, 카테고리/상품 속성은 숫자/코드 형태입니다.  
> 본 프로젝트는 “이름 해석”이 아니라 “구조(트리/세션/퍼널)와 성과 차이”를 분석 대상으로 삼습니다.

### Raw 규모(로컬 기준)
- `events.csv`: 2,756,101 rows (header 제외)
- `category_tree.csv`: 1,669 rows
- `item_properties_part1.csv`: 10,999,999 rows
- `item_properties_part2.csv`: 9,275,903 rows

### Dataset 메타 정보 (출처 설명 기반)
- 관측 기간: 약 **4.5개월**
- 이벤트 분포:
  - `view`: 2,664,312
  - `addtocart`: 69,332
  - `transaction`: 22,457
- 고유 방문자 수: **1,407,580**
- item property 로그:
  - 총 20,275,902 rows (part1+part2)
  - 약 417,053 unique items
  - 속성은 시계열 변경 로그 형태(변경 없는 값은 중복 스냅샷 병합)

### 데이터 해석 주의사항
- 원본 값은 익명화/해시 처리되어 있으며,
  `categoryid`, `available`를 제외한 대부분의 property value는 해시값입니다.
- 따라서 본 프로젝트는 “상품명/텍스트 의미 해석”보다
  **행동 로그 구조(세션/퍼널/전환)와 지표 계산 체계**에 초점을 둡니다.
- 라이선스: **CC BY-NC-SA 4.0** (비상업적 활용 기준)

---

## Pipeline Architecture
### Diagram (SVG)
![Pipeline Architecture](docs/assets/pipeline_architecture.svg)

### Layered Design
- **RAW**: 원본 CSV → DB 적재(재실행 가능한 TRUNCATE+LOAD)
- **STAGING**: 타입/포맷 표준화(분석-friendly), 이벤트 canonicalization
- **MART**: 의사결정용 데이터 모델(dim/fact), 세션화 포함
- **KPI**: 퍼널/코호트/CRM 타겟을 즉시 사용 가능한 지표 레이어로 제품화
- **QA**: 배치 성공과 별개로 “데이터 품질”을 보장하는 게이트
- **EXPORT**: CSV/TXT 산출물 생성(대시보드/보고서/검증 용이)

### Why STAGING?
원본 로그는 그대로 분석에 쓰기 어렵습니다(ms epoch, 문자열, 반복 변환 필요).  
STAGING에서 **타입/정규화 변환을 1회 수행**하여, MART/KPI에서 재사용 가능한 표준 레이어를 제공합니다.

---

## Key Transform Details
### STAGING
- `stg_rr_events`
  - `event_type` 정규화(`LOWER/TRIM`)
  - `timestamp_ms → event_ts, event_date` 변환
- `stg_rr_item_snapshot`
  - `property in (categoryid, available)` 중 **최신값 스냅샷** 추출(`ROW_NUMBER`)
- `stg_rr_category_dim`
  - 재귀 CTE로 카테고리 트리의 **루트/깊이/경로(path)** 생성

### MART
- **Dimensions**: `dim_rr_category`, `dim_rr_item`, `dim_rr_visitor`
- **Facts**:
  - `fact_rr_events`: 이벤트에 `session_id` 부여
  - `fact_rr_sessions`: 세션 단위 집계(views/carts/purchases + flags)

#### Sessionization Rule (핵심)
동일 `visitor_id` 기준으로 새 세션 시작 조건:
- 첫 이벤트
- 날짜 변경
- 이전 이벤트 대비 **30분 초과 inactivity**

세션 ID: `visitor_id-session_index`

### KPI
- `mart_rr_funnel_daily`: 일 단위 funnel/전환율
- `mart_rr_funnel_category_daily`: 루트 카테고리별 funnel
- `mart_rr_cohort_weekly`: 구매 코호트 리텐션(주차)
- `mart_rr_crm_targets_daily`: CRM 타겟 세그먼트
  - 당일 장바구니 이탈
  - 최근 7일 고의도 뷰어(무카트/무구매)
  - 반복 구매자

---

## Data Quality (QA Gate)
ETL의 “성공”과 “신뢰 가능한 데이터”는 다릅니다. 배치 종료 후 품질 검증을 통해 지표 왜곡을 방지합니다.

`sql/retailrocket/90_quality/` 예시:
- 이벤트 도메인 체크(event ∈ view/addtocart/transaction)
- transaction 무결성(transaction인데 transactionid NULL이면 실패)
- null 체크(핵심 키)
- 핵심 테이블 row count sanity
- KPI 범위 sanity(CVR 0~1)

> QA 결과는 `quality_check_runs`에 기록되어 **운영 추적성**을 제공합니다.

---

## Export Artifacts
성공 시 `logs/reports/`에 아래 산출물이 생성됩니다:
- `rr_funnel_daily_<target_date>.csv`
- `rr_cohort_weekly_<target_date>.csv`
- `rr_crm_targets_<target_date>.csv`
- `rr_pipeline_summary_<target_date>.txt`

---

## DAG
- **DAG ID**: `rr_funnel_daily`
- **Schedule**: 매일 09:00 (Asia/Seoul)
- **catchup**: `False` *(대량 자동 백필 방지)*
- **max_active_runs**: 1
- **manual backfill**: `dag_run.conf.target_date` 지원

---

## How to Run (Reproducible)
### 1) 컨테이너 기동
```bash
make up
```

### 2) DDL 초기화
```bash
make init
```

### 3) DAG 실행
```bash
make run-dag
```

### 4) 특정 날짜 백필(수동 실행)
```bash
docker compose exec -T airflow-apiserver \
  airflow dags trigger rr_funnel_daily \
  -r manual_backfill_2015-09-18 \
  -c '{"target_date":"2015-09-18"}'
```

### 5) 실행 상태 확인
```bash
docker compose exec -T airflow-apiserver airflow dags list-runs rr_funnel_daily -o table
docker compose exec -T airflow-apiserver airflow tasks states-for-dag-run rr_funnel_daily <run_id>
```

---

## Repo Policy (GitHub 업로드 가이드)
### Commit 권장

- `dags/`, `scripts/`, `sql/`
- `docker-compose.yml`, `Dockerfile`, `Makefile`, `requirements.txt`
- `README.md`, `.env.example`

### Commit 제외

- `.env` 및 민감정보
- `logs/`, `exports/`, `.omx/`
- 대용량 원본 데이터 `data/raw/`
