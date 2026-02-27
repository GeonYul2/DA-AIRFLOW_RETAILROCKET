# DA-AIRFLOW_RETAILROCKET
**Apache Airflow 기반 RetailRocket clickstream 분석 파이프라인 포트폴리오**

`rr_funnel_daily` DAG로 **RAW → STAGING → MART → KPI → QA → EXPORT**를 구성해  
실데이터 기준으로 퍼널/코호트/CRM 타겟 산출까지 연결했습니다.

---

## 한눈에 보는 파이프라인 (아이콘 요약)

| 단계 | 목적 | 핵심 산출 |
|---|---|---|
| 🟦 RAW | 원본 이벤트/속성 로그 적재 | `raw_rr_*` |
| 🟩 STAGING | 타입/포맷 정규화, 분석 가능한 형태로 표준화 | `stg_rr_events`, `stg_rr_item_snapshot`, `stg_rr_category_dim` |
| 🟨 MART | 차원/사실 모델 + 세션화(sessionization) | `dim_rr_*`, `fact_rr_*` |
| 🟥 KPI | 퍼널/코호트/CRM 지표 제품화 | `mart_rr_funnel_daily` 등 |
| 🟪 QA | 도메인/널/무결성/범위 검증 | `quality_check_runs` |
| 🟦 EXPORT | 외부 활용 가능한 결과물 생성 | CSV 3종 + summary TXT |

---

## 아키텍처 다이어그램

![Pipeline Architecture](docs/assets/pipeline_architecture.svg)

---

## 데이터셋 정보

- 출처: Kaggle RetailRocket  
  https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset
- 이벤트 기간: **2015-05-03 ~ 2015-09-18 (KST)**
- 파일 구조:
  - `events.csv`
  - `category_tree.csv`
  - `item_properties_part1.csv`, `item_properties_part2.csv`

### Raw 규모(로컬 기준)
- `events.csv`: 2,756,101 rows (header 제외)
- `category_tree.csv`: 1,669 rows
- `item_properties_part1.csv`: 10,999,999 rows
- `item_properties_part2.csv`: 9,275,903 rows

### 해석 시 주의사항
- 데이터는 익명화/해시 처리되어 있으며 `categoryid`, `available`를 제외한 속성값 대부분은 해시입니다.
- 따라서 본 프로젝트는 상품 텍스트 해석보다 **행동 로그 구조(세션/퍼널/전환)**에 집중합니다.

---

## 레이어 설계 의도

### STAGING
- 원본 로그(ms timestamp, 문자열 이벤트)를 분석 친화적으로 1회 정규화
- `event_type` canonicalization, timestamp 변환, 카테고리 트리 구성, 속성 최신 스냅샷 추출

### MART
#### 1) Dimensions
- `dim_rr_category`
- `dim_rr_item`
- `dim_rr_visitor`

#### 2) Facts
- `fact_rr_events`: 이벤트에 `session_id` 부여
- `fact_rr_sessions`: 세션 단위 집계 (`views/carts/purchases + flags`)

#### 3) Sessionization Rule (핵심)
동일 `visitor_id` 기준으로 새 세션 시작 조건:
1. 첫 이벤트
2. 날짜 변경
3. 이전 이벤트 대비 **30분 초과 inactivity**

세션 ID: `visitor_id-session_index`

### KPI
- `mart_rr_funnel_daily`: 일 단위 퍼널/전환율
- `mart_rr_funnel_category_daily`: 카테고리별 퍼널
- `mart_rr_cohort_weekly`: 구매 코호트 리텐션
- `mart_rr_crm_targets_daily`: CRM 타겟 세그먼트

### QA
- 배치 성공과 별개로 데이터 신뢰성 검증
- 도메인/널/무결성/row count/KPI 범위 sanity check

### EXPORT
- 최종 지표를 CSV/TXT로 생성하여 전달 가능한 데이터 산출물로 마무리

---

## 실행 검증 기록

- DAG: `rr_funnel_daily`
- 수동 백필 성공 run: `manual_backfill_2015-09-18`
- 확인 포인트:
  - `compute_kpis` 포함 전체 태스크 success
  - export 파일 생성 완료

### 생성 산출물 예시
- `logs/reports/rr_funnel_daily_2015-09-18.csv`
- `logs/reports/rr_cohort_weekly_2015-09-18.csv`
- `logs/reports/rr_crm_targets_2015-09-18.csv`
- `logs/reports/rr_pipeline_summary_2015-09-18.txt`

---

## 트러블슈팅 (핵심 1건)

- 이슈: Jinja 템플릿에서 `in_timezone` 호출 시 Airflow3 환경에서 타입 불일치 오류
- 조치:
  - 템플릿을 datetime 호환 방식으로 수정
  - `dag_run.conf.target_date` 우선 처리(수동 백필 안정화)
  - `catchup=False` 설정으로 불필요한 대량 자동 백필 방지

