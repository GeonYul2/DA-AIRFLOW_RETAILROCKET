# RetailRocket Funnel·Cohort·CRM KPI Pipeline + QA
RetailRocket clickstream으로 **퍼널·코호트·CRM 타겟**을 산출하는 Airflow 파이프라인입니다.  
핵심은 배치 성공이 아니라, **지표 정의·세션 기준·품질 검증**을 고정해 같은 데이터에서 같은 KPI가 나오게 만드는 것입니다.

## 1) 문제와 목표
CVR 급락 알림이 오면 보통 캠페인/예산 조정을 먼저 논의합니다.  
하지만 세션 기준, 전환 정의, `transaction_id` 무결성이 흔들리면 같은 로그에서도 결론이 달라질 수 있습니다.

핵심 리스크:
- 세션 기준 변화로 CVR 해석이 달라질 수 있음
- `transaction_id` 누락/중복으로 구매·매출 지표 왜곡 가능
- 배치 success만으로는 도메인 오류·결측·중복 전파를 막기 어려움
- 결과를 실행 형식(타겟 리스트/요약 리포트)으로 정리하지 않으면 후속 액션이 지연될 수 있음

프로젝트 목표는 위 리스크를 줄이기 위해  
**지표 정의·세션 기준·품질 검증을 고정하고, QA를 통과한 결과만 운영 산출물로 전달하는 파이프라인을 구축하는 것**입니다.

## 2) 데이터셋
이 데이터는 clickstream 이벤트가 풍부해 세션화·퍼널·코호트·CRM 과정을 end-to-end로 검증하기 적합합니다.  
공개 데이터라 재현 가능한 형태로 분석 결과를 공유하기 좋습니다.

- 출처: Kaggle RetailRocket eCommerce Dataset  
  https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset
- 로컬 경로: `data/raw/retailrocket/`
- 이벤트 기간: 2015-05-03 ~ 2015-09-18 (KST)

데이터 규모(로컬 기준):

| 파일 | 규모 (행 × 열) | 주요 컬럼 |
|---|---:|---|
| `events.csv` | 2,756,101 × 5 | `timestamp, visitorid, event, itemid, transactionid` |
| `category_tree.csv` | 1,669 × 2 | `categoryid, parentid` |
| `item_properties_part1.csv` | 10,999,999 × 4 | `timestamp, itemid, property, value` |
| `item_properties_part2.csv` | 9,275,903 × 4 | `timestamp, itemid, property, value` |

EDA 참고:
- 요약 문서: [docs/retailrocket_eda.md](docs/retailrocket_eda.md)
- 재생성 스크립트: `python3 scripts/profile_retailrocket_eda.py`

## 3) 파이프라인 설계와 구현
![Pipeline Architecture](docs/assets/pipeline_architecture.svg)

| 단계 | 목적 | 이 단계에서 한 일 |
|---|---|---|
| RAW | 원본 보존과 추적 기준 확보 | CSV 원본을 그대로 적재해 원천 로그를 보존하고, 이후 단계와 분리해 재처리 기준을 고정 |
| STAGING | 전처리 편차 제거 | 이벤트 타입 정규화, 시간 변환(`timestamp_ms → event_ts/event_date`), 아이템 최신 속성 스냅샷, 카테고리 트리 평탄화 |
| DATA MART | 분석 단위 통일 | dim/fact 구조로 분리하고 세션 규칙(30분 inactivity + 날짜 변경)을 SQL로 고정 |
| KPI | 지표 계산 일관성 확보 | Funnel/Cohort/CRM 계산을 별도 테이블로 분리해 분자/분모 정의를 단일화 |
| QA | 품질 기준 선반영 | domain / integrity / null / rowcount / KPI range(0~1) 5개 체크를 실행 조건으로 적용 |
| EXPORT | 실행 가능한 전달물 생성 | QA 통과 시에만 CSV 3종 + summary TXT 1종을 고정 파일명 패턴으로 생성 |

<details>
<summary><strong>워크플로우 전체 상세 보기 (RAW → STAGING → DATA MART → KPI → QA → EXPORT)</strong></summary>

### 1) RAW — 원본을 “훼손 없이” 보존
- **왜 필요한가**: 원본이 바뀌면 원인 추적이 불가능해집니다. 재현 가능한 분석의 출발점은 원본 보존입니다.
- **어떻게 했나**: `events.csv`, `item_properties*.csv`, `category_tree.csv`를 그대로 적재하고 이후 레이어(STAGING/MART)와 분리했습니다.
- **관련 코드**
  - 적재 스크립트: `scripts/load_raw/load_retailrocket.py`
  - 테이블 정의: [`001_create_tables.sql`](sql/retailrocket/00_ddl/001_create_tables.sql)

### 2) STAGING — 분석 전에 “형식”을 먼저 통일
- **왜 필요한가**: 원본 로그는 타입/시간/속성 포맷이 제각각이라 바로 집계하면 팀마다 다른 결과가 나옵니다.
- **어떻게 했나**
  - 이벤트 타입을 허용값(`view/addtocart/transaction`) 기준으로 정규화
  - `timestamp_ms`를 사람이 해석 가능한 `event_ts`, 집계용 `event_date`로 변환
  - item property를 최신 값 기준으로 스냅샷화(조인 안정화)
  - 카테고리 트리를 평탄화해 차원 조인 비용 축소
- **관련 SQL**
  - [`001_stg_rr_events.sql`](sql/retailrocket/10_staging/001_stg_rr_events.sql)
  - [`002_stg_rr_item_snapshot.sql`](sql/retailrocket/10_staging/002_stg_rr_item_snapshot.sql)
  - [`003_stg_rr_category_dim.sql`](sql/retailrocket/10_staging/003_stg_rr_category_dim.sql)

### 3) DATA MART — 분석 단위를 세션/팩트 중심으로 고정
- **왜 필요한가**: 같은 이벤트라도 “세션을 어떻게 자르느냐”에 따라 CVR이 달라집니다.
- **어떻게 했나**
  - visitor별 시간순 정렬 후 세션 경계 규칙을 SQL로 고정
  - 새 세션 시작 조건: (1) 첫 이벤트, (2) 날짜 변경, (3) 이전 이벤트와 30분 초과 간격
  - 세션 ID(`visitor_id-session_index`) 생성 후 세션 단위 집계 테이블 구성
- **관련 SQL**
  - 이벤트 세션화: [`010_fact_rr_events.sql`](sql/retailrocket/20_mart/010_fact_rr_events.sql)
  - 세션 집계: [`020_fact_rr_sessions.sql`](sql/retailrocket/20_mart/020_fact_rr_sessions.sql)

### 4) KPI — “숫자”가 아니라 “정의”를 고정
- **왜 필요한가**: KPI는 값보다 정의가 중요합니다. 분자/분모가 흔들리면 비교 자체가 무의미해집니다.
- **어떻게 했나**
  - **Funnel(일 단위)**: “그 날짜에 생성된 세션 중 어디까지 진행했는가”를 비율로 계산
    - 예) `cvr_session_to_purchase = sessions_with_purchase / sessions`
  - **Cohort(주 단위)**: “첫 구매 주차별 사용자군이 다음 주에도 돌아오는가”를 유지율로 계산
    - 예) `retention_rate = active_visitors / cohort_size`
  - **CRM Targets(일 단위)**: “오늘 액션 가능한 대상”을 규칙 기반 세그먼트로 생성
    - 장바구니 이탈자, 고의도 조회자(7일), 반복구매자
- **관련 SQL**
  - Funnel: [`001_mart_rr_funnel_daily.sql`](sql/retailrocket/30_kpi/001_mart_rr_funnel_daily.sql)
  - Cohort: [`003_mart_rr_cohort_weekly.sql`](sql/retailrocket/30_kpi/003_mart_rr_cohort_weekly.sql)
  - CRM: [`004_mart_rr_crm_targets_daily.sql`](sql/retailrocket/30_kpi/004_mart_rr_crm_targets_daily.sql)

### 5) QA — “배치 성공”이 아니라 “품질 통과”를 게이트로 사용
- **왜 필요한가**: DAG가 성공해도 데이터가 잘못되면 잘못된 의사결정을 자동화하는 셈입니다.
- **어떻게 했나**: 아래 5개 품질 검사를 모두 통과한 경우에만 다음 단계(EXPORT)로 진행합니다.

| 체크 | 무엇을 막는가 | 실패 조건 | SQL |
|---|---|---|---|
| Domain check | 허용되지 않은 이벤트 타입 유입 | 허용값 외 이벤트 존재 | [`001_domain_checks.sql`](sql/retailrocket/90_quality/001_domain_checks.sql) |
| Transaction integrity | 구매 이벤트 식별 불가 | `transaction_id` NULL 존재 | [`002_transaction_integrity.sql`](sql/retailrocket/90_quality/002_transaction_integrity.sql) |
| Null checks | 핵심 키 결측으로 인한 조인/집계 왜곡 | 핵심 키 NULL 존재 | [`003_null_checks.sql`](sql/retailrocket/90_quality/003_null_checks.sql) |
| Rowcount sanity | 빈 테이블 기반 잘못된 계산 | 핵심 테이블 0건 존재 | [`004_rowcount_sanity.sql`](sql/retailrocket/90_quality/004_rowcount_sanity.sql) |
| KPI sanity | 비정상 KPI 수치 배포 | 음수 값 또는 CVR 범위(0~1) 이탈 | [`005_kpi_sanity.sql`](sql/retailrocket/90_quality/005_kpi_sanity.sql) |

### 6) EXPORT — 운영팀이 바로 쓸 수 있는 형태로 마감
- **왜 필요한가**: 분석 결과를 실행 포맷으로 전달하지 않으면 후속 액션이 지연됩니다.
- **어떻게 했나**
  - QA 5종 통과 실행에서만 CSV/TXT를 생성
  - 파일명 규칙 고정(`rr_funnel_daily_*`, `rr_cohort_weekly_*`, `rr_crm_targets_*`, `rr_pipeline_summary_*`)
- **관련 스크립트**
  - [`export_rr_funnel_csv.py`](scripts/export_rr_funnel_csv.py)
  - [`export_rr_cohort_csv.py`](scripts/export_rr_cohort_csv.py)
  - [`export_rr_crm_targets_csv.py`](scripts/export_rr_crm_targets_csv.py)
  - [`write_rr_pipeline_summary.py`](scripts/write_rr_pipeline_summary.py)

</details>

## 4) 결과와 산출물
대표 재현 실행: `target_date=2015-06-16`

결과 요약:
- QA 통과 실행에서만 export 생성
- 실행 1회마다 동일 포맷 산출물 자동 생성
- KPI 계산 로직과 품질 검증 로직 분리로 원인 추적 단순화

산출물(샘플):

| 파일 | 샘플 크기 | 용도 |
|---|---:|---|
| `rr_funnel_daily_2015-06-16.csv` | 1행 | 일자 퍼널·CVR 해석 |
| `rr_cohort_weekly_2015-06-16.csv` | 6행 | 주차별 유지율 확인 |
| `rr_crm_targets_2015-06-16.csv` | 312행 | CRM 실행 타겟 전달 |
| `rr_pipeline_summary_2015-06-16.txt` | 20줄 | 실행/품질 요약 검수 |

핵심 수치(2015-06-16):
- Funnel: visitors `4,379`, sessions `4,540`, purchases `67`, `cvr_session_to_purchase=0.0134`
- CRM 분포: `cart_abandoner_today=80`, `high_intent_viewer_7d_no_cart=115`, `repeat_buyer=117`
- QA: `001~005` 모두 `PASS`

산출물 경로:
- 런타임 출력: `logs/reports/`
- 포트폴리오 샘플: `docs/samples/outputs/`

## 5) 활용 관점
- **BA/그로스**: 캠페인 조정 전에 정의/세션/누락을 먼저 점검할 수 있습니다.
- **DQA/운영**: 배치 성공과 KPI 신뢰를 분리해 품질 기준으로 운영할 수 있습니다.

링크:
- Project Page: https://geonyul2.github.io/DA-AIRFLOW_RETAILROCKET/
- GitHub Repo: https://github.com/GeonYul2/DA-AIRFLOW_RETAILROCKET
- README: https://github.com/GeonYul2/DA-AIRFLOW_RETAILROCKET/blob/main/README.md
