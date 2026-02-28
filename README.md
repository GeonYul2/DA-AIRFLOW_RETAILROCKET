# DA-AIRFLOW_RETAILROCKET
로그 기반 KPI가 흔들리는 상황에서 지표 정의·세션 규칙·품질 게이트를 고정해 **재현 가능한 지표 운영**을 만든 분석가 중심 프로젝트입니다.

## 현업 시나리오
주간 리포트에서 전환율 급락이 감지되면, 마케팅/상품/운영팀은 즉시 예산과 캠페인 조정을 논의합니다.  
하지만 원인이 실제 수요 변화가 아니라 세션 기준 변경, transaction 무결성 깨짐, 집계 정의 불일치라면 의사결정 자체가 잘못될 수 있습니다.  
이 프로젝트는 “배치가 돌아갔다”가 아니라 “숫자를 믿고 의사결정해도 되는가”를 먼저 검증하도록 설계했습니다.

## 내가 정의한 리스크
- 세션 기준이 불명확하면 같은 로그로도 CVR이 달라져 트렌드 해석이 흔들립니다.
- transaction 무결성이 깨지면 구매/매출성 지표가 조용히 왜곡됩니다.
- 배치 성공 여부만 보면 도메인 오류·결측·중복이 KPI에 전파될 수 있습니다.
- 지표 정의가 팀마다 다르면 같은 숫자도 서로 다르게 해석됩니다.
- 산출물 전달 형식이 없으면 분석 결과가 실행 단계(캠페인/CRM)로 연결되지 않습니다.

## 내가 한 선택 (설계 의사결정)
- 세션 규칙(30분 inactivity + 날짜 변경)을 MART에서 명시적으로 고정했습니다.
- KPI 계산 레이어를 분리해 “정의 책임”과 “변환 책임”의 경계를 고정했습니다.
- QA Gate 5종(도메인/무결성/null/row count/KPI 범위)을 DAG에 내장해 왜곡 전파를 차단했습니다.
- 퍼널/코호트/CRM 결과를 CSV와 요약 TXT로 export해 전달 가능한 산출물로 마무리했습니다.
- `dag_run.conf.target_date` 기반 수동 백필 경로를 열어 재현 가능한 검증을 가능하게 했습니다.

## 그래서 무엇이 달라졌는가 (Impact)
- KPI 재현 가능성과 일관성을 확보해 리포트 신뢰도를 높였습니다.
- 오류를 조기에 탐지해 잘못된 KPI가 의사결정으로 전파되는 위험을 줄였습니다.
- CRM/퍼널/코호트 산출물을 운영팀이 바로 사용할 수 있는 형태로 제공했습니다.

## Who this helps
- **BA/그로스 분석가**: 캠페인 효과 해석 전에 지표 정의/세션 기준부터 검증할 수 있습니다.
- **DQA/데이터 운영 담당자**: 배치 성공 여부가 아닌 KPI 신뢰 기준으로 파이프라인을 운영할 수 있습니다.

---

## Quickstart (재현 가능성 증거)

```bash
cp .env.example .env
make up
make init
make run-dag
make check
```

- `make check` 실행 전, `airflow-apiserver` 컨테이너가 up 상태여야 합니다.
- 로컬 단일 실행 스크립트: `make run-linux`
- 수동 백필: Airflow UI에서 `dag_run.conf.target_date` 지정 (예: `2015-09-18`)

---

## Verification (결과물 증거)

- 성공 run 예시: `manual_backfill_2015-09-18`
- 확인 기준:
  - `compute_kpis` 포함 전체 태스크 success
  - 아래 export 산출물 생성

```text
logs/reports/rr_funnel_daily_2015-09-18.csv
logs/reports/rr_cohort_weekly_2015-09-18.csv
logs/reports/rr_crm_targets_2015-09-18.csv
logs/reports/rr_pipeline_summary_2015-09-18.txt
```

---

## Key Design Decisions
- **왜 30분 세션 기준인가?** 업계에서 일반적으로 쓰는 inactivity 기준으로 사용자 행동 단위를 안정적으로 비교하기 위해.
- **왜 KPI sanity를 0~1로 고정했는가?** 비정상 계산/조인 오류를 즉시 감지하는 최소 안전장치이기 때문.
- **왜 export를 별도 단계로 뒀는가?** 분석 결과를 운영/의사결정 시스템으로 전달 가능한 형태까지 책임지기 위해.

---

## Project Overview (문제-리스크 대응 관점)

| 레이어 | 왜 필요한가 (리스크 대응) | 대표 산출 |
|---|---|---|
| 🟦 RAW | 원본 로그 보존 및 추적 가능성 확보 | `raw_rr_*` |
| 🟩 STAGING | 타입/포맷을 고정해 반복 변환과 정의 흔들림 방지 | `stg_rr_events`, `stg_rr_item_snapshot`, `stg_rr_category_dim` |
| 🟨 MART | 세션/차원/사실 모델을 고정해 의사결정 단위를 일관화 | `dim_rr_*`, `fact_rr_*` |
| 🟥 KPI | 퍼널/코호트/CRM 지표 정의를 계산 레이어에서 명시화 | `mart_rr_funnel_daily` 등 |
| 🟪 QA | 배치 성공과 별개로 KPI 왜곡을 사전 차단 | `quality_check_runs` |
| 🟦 EXPORT | 의사결정자가 바로 사용할 전달물 생성 | CSV 3종 + summary TXT |

---

## Architecture Diagram

![Pipeline Architecture](docs/assets/pipeline_architecture.svg)

---

## Dataset (RAW)

- 출처: Kaggle RetailRocket eCommerce Dataset  
  https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset
- 로컬 경로: `data/raw/retailrocket/`
- 이벤트 기간: 2015-05-03 ~ 2015-09-18 (KST)

원본 파일:
- `events.csv` — `timestamp, visitorid, event, itemid, transactionid`
- `category_tree.csv` — `categoryid, parentid`
- `item_properties_part1.csv`, `item_properties_part2.csv` — `timestamp, itemid, property, value`

데이터 규모 (로컬 기준):
- `events.csv`: 2,756,101행 (header 제외)
- `category_tree.csv`: 1,669행
- `item_properties_part1.csv`: 10,999,999행
- `item_properties_part2.csv`: 9,275,903행

해석 유의점:
- 데이터는 익명화/해시 처리되어 있어 텍스트 의미 해석보다 행동 로그 구조(세션/퍼널/전환) 분석에 적합합니다.

---

## Data Modeling (레이어별 근거)

### STAGING
- 리스크: 원본(ms timestamp, 문자열 이벤트) 기반 분석 시 변환 로직이 팀/쿼리마다 달라질 수 있음
- 대응: 변환 로직을 STAGING에 집중해 하위 레이어 재현성을 확보
- 산출:
  - `stg_rr_events`: `event_type` 정규화 + `timestamp_ms → event_ts/event_date`
  - `stg_rr_item_snapshot`: `categoryid`, `available` 최신값 스냅샷
  - `stg_rr_category_dim`: 재귀 CTE 기반 카테고리 트리

### MART
- 리스크: 세션 단위/행동 단위가 불안정하면 KPI 해석이 흔들림
- 대응: dim/fact 분리 + 명시적 sessionization 룰 고정
- 산출:
  - Dimensions: `dim_rr_category`, `dim_rr_item`, `dim_rr_visitor`
  - Facts: `fact_rr_events`, `fact_rr_sessions`

Sessionization Rule:
1. 동일 `visitor_id` 기준 첫 이벤트
2. 날짜 변경
3. 이전 이벤트 대비 30분 초과 inactivity

### KPI
- 리스크: 지표 정의가 SQL 곳곳에 흩어지면 변경 영향 추적이 어려움
- 대응: KPI 레이어를 분리해 정의의 단일 책임 지점 확보
- 산출:
  - `mart_rr_funnel_daily`
  - `mart_rr_funnel_category_daily`
  - `mart_rr_cohort_weekly`
  - `mart_rr_crm_targets_daily`

### QA
- 리스크: 배치 success만으로는 지표 신뢰를 보장할 수 없음
- 대응: 품질 게이트 내장
- 체크:
  - 이벤트 도메인
  - transaction 무결성
  - null 체크(핵심 키)
  - 핵심 테이블 row count sanity
  - KPI 범위 sanity (CVR 0~1)

### EXPORT
- 리스크: 분석 결과가 전달물로 끝나지 않으면 실행 단계와 단절됨
- 대응: CSV/TXT export를 표준 산출물로 고정

---

## DAG 운영 설정

- DAG ID: `rr_funnel_daily`
- Schedule: `0 9 * * *` (Asia/Seoul)
- `catchup=False`
- `max_active_runs=1`
- 수동 백필: `dag_run.conf.target_date` 지원

---

## Project Page (GitHub Pages)

- 문서 랜딩: `https://<your-github-username>.github.io/da-airflow-retailrocket/`
- 문서 설정/위치: `docs-site/mkdocs.yml`, `docs-site/docs/`
- 배포 전 확인: `Settings > Pages > Build and deployment > Source = GitHub Actions`

---

## Troubleshooting (핵심 1건)

문제:
- Airflow 3 환경에서 Jinja 템플릿 `in_timezone` 호출 시 타입 불일치 오류

해결:
- datetime 호환 템플릿으로 수정
- `dag_run.conf.target_date` 우선 처리
- `catchup=False`로 불필요한 대량 자동 백필 방지
