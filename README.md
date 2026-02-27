# DA-AIRFLOW_RETAILROCKET
Apache Airflow 기반 RetailRocket clickstream 분석 파이프라인 포트폴리오

> `rr_funnel_daily` DAG로 RAW → STAGING → MART → KPI → QA → EXPORT 전 과정을 자동화해  
> 실데이터 기준으로 재현 가능한 분석 데이터 제품(지표/세그먼트/리포트)을 생성하도록 구현했습니다.

---

## 0) Why I built this (Problem → Goal)

### Problem
데이터 분석 실무에서는 “분석을 잘하는 것”만큼 데이터가 믿을 수 있는 형태로 지속 공급되는가가 중요합니다.

- 원본 로그 비정형성  
  ms epoch 타임스탬프, 문자열 이벤트, 시간 의존 속성(property) 때문에 분석마다 변환 로직이 중복되고 결과가 흔들립니다.
- 지표 정의 불일치  
  전환율(이벤트/세션 기준), 코호트(첫 방문/첫 구매 기준) 정의가 불명확하면 팀 내 숫자 해석이 달라집니다.
- 배치 성공과 데이터 신뢰성의 불일치  
  도메인 오류/무결성 깨짐/결측·중복이 있어도 배치는 성공할 수 있고, KPI는 조용히 왜곡될 수 있습니다.

### Goal
이 프로젝트의 목표는 “분석가가 운영형 데이터 흐름까지 책임질 수 있음을 증명”하는 것입니다.

- 실데이터를 RAW/STAGING/MART 계층으로 모델링하고
- 퍼널/코호트/CRM 타겟을 KPI 레이어로 제품화하며
- 도메인/널/무결성/범위 검증을 QA 게이트로 자동화하고
- 최종 결과를 CSV/TXT 산출물로 전달 가능한 형태로 마무리했습니다.

---

## 1) Project Overview

| 단계 | 역할 | 대표 산출 |
|---|---|---|
| 🟦 RAW | 원본 이벤트/속성 로그 적재 | `raw_rr_*` |
| 🟩 STAGING | 타입/포맷 정규화, 분석용 표준화 | `stg_rr_events`, `stg_rr_item_snapshot`, `stg_rr_category_dim` |
| 🟨 MART | 차원/사실 모델 구성 + 세션화 | `dim_rr_*`, `fact_rr_*` |
| 🟥 KPI | 퍼널/코호트/CRM 지표 계산 | `mart_rr_funnel_daily` 등 |
| 🟪 QA | 품질 검증(도메인/널/무결성/범위) | `quality_check_runs` |
| 🟦 EXPORT | 전달 가능한 산출물 생성 | CSV 3종 + summary TXT |

---

## 2) Architecture Diagram

![Pipeline Architecture](docs/assets/pipeline_architecture.svg)

---

## 3) Dataset (RAW)

- 출처: Kaggle RetailRocket eCommerce Dataset  
  https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset
- 로컬 경로: `data/raw/retailrocket/`
- 이벤트 기간: 2015-05-03 ~ 2015-09-18 (KST)

원본 파일:
- `events.csv` — `timestamp, visitorid, event, itemid, transactionid`
- `category_tree.csv` — `categoryid, parentid`
- `item_properties_part1.csv`, `item_properties_part2.csv` — `timestamp, itemid, property, value`

### 데이터 규모 (로컬 기준)
- `events.csv`: 2,756,101행 (header 제외)
- `category_tree.csv`: 1,669행
- `item_properties_part1.csv`: 10,999,999행
- `item_properties_part2.csv`: 9,275,903행

### 해석 시 유의점
- 데이터는 익명화/해시 처리되어 있으며 `categoryid`, `available`를 제외한 속성값 대부분은 해시입니다.
- 따라서 본 프로젝트는 상품 텍스트 의미 해석보다 행동 로그 구조(세션/퍼널/전환) 분석에 초점을 둡니다.

---

## 4) Data Modeling (Layer Design)

### 4-1. STAGING
원본 로그의 비정형성(ms timestamp, 문자열 이벤트) 때문에 발생하는 반복 변환/불일치를 줄이기 위해,  
변환 로직을 STAGING에 집중해 하위 레이어(MART/KPI)가 재현 가능하도록 설계했습니다.

- `stg_rr_events`: `event_type` 정규화 + `timestamp_ms → event_ts/event_date`
- `stg_rr_item_snapshot`: `categoryid`, `available` 최신값 스냅샷
- `stg_rr_category_dim`: 재귀 CTE 기반 카테고리 트리(루트/깊이/경로)

### 4-2. MART
STAGING이 “정제된 원본”이라면 MART는 “의사결정용 모델”입니다.  
반복 조인·집계 비용을 줄이기 위해 dim/fact 구조로 분리했습니다.

#### Dimensions
- `dim_rr_category`
- `dim_rr_item`
- `dim_rr_visitor`

#### Facts
- `fact_rr_events`: 이벤트에 `session_id` 부여
- `fact_rr_sessions`: 세션 단위 집계 (`views/carts/purchases + flags`)

#### Sessionization Rule (핵심)
동일 `visitor_id` 기준으로 새 세션 시작:
1. 첫 이벤트
2. 날짜 변경
3. 이전 이벤트 대비 30분 초과 inactivity

세션 ID: `visitor_id-session_index`

### 4-3. KPI
- `mart_rr_funnel_daily`: 일 단위 퍼널/전환율
- `mart_rr_funnel_category_daily`: 루트 카테고리별 퍼널
- `mart_rr_cohort_weekly`: 구매 코호트 리텐션
- `mart_rr_crm_targets_daily`: CRM 타겟 세그먼트
  - 당일 장바구니 이탈
  - 최근 7일 고의도 뷰어(무카트/무구매)
  - 반복 구매자

### 4-4. QA
배치 성공과 데이터 품질 보장은 별개이므로, 품질 게이트를 파이프라인에 내장했습니다.

- 이벤트 도메인 체크
- transaction 무결성 체크
- null 체크(핵심 키)
- 핵심 테이블 row count sanity
- KPI 범위 sanity (CVR 0~1)

> QA 결과는 `quality_check_runs`에 기록됩니다.

### 4-5. EXPORT
최종 지표를 CSV/TXT로 생성해 전달 가능한 산출물로 마무리합니다.

- `rr_funnel_daily_<target_date>.csv`
- `rr_cohort_weekly_<target_date>.csv`
- `rr_crm_targets_<target_date>.csv`
- `rr_pipeline_summary_<target_date>.txt`

---

## 5) DAG 운영 설정

- DAG ID: `rr_funnel_daily`
- Schedule: `0 9 * * *` (Asia/Seoul)
- `catchup=False` (대량 자동 백필 방지)
- `max_active_runs=1`
- 수동 백필: `dag_run.conf.target_date` 지원

---

## 6) Verification (실행 검증)

- 성공 run: `manual_backfill_2015-09-18`
- 검증 결과:
  - `compute_kpis` 포함 전체 태스크 success
  - export 파일 생성 확인

산출물 예시:
- `logs/reports/rr_funnel_daily_2015-09-18.csv`
- `logs/reports/rr_cohort_weekly_2015-09-18.csv`
- `logs/reports/rr_crm_targets_2015-09-18.csv`
- `logs/reports/rr_pipeline_summary_2015-09-18.txt`

---

## 7) Troubleshooting (핵심 1건)

### 문제
Airflow 3 환경에서 Jinja 템플릿 `in_timezone` 호출 시 타입 불일치 오류 발생

### 해결
- datetime 호환 템플릿으로 수정
- `dag_run.conf.target_date` 우선 처리로 수동 백필 안정화
- `catchup=False` 적용으로 불필요한 대량 자동 백필 방지
