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

고정한 기준:
- 세션: 30분 inactivity + 날짜 변경
- 지표: 분자/분모 정의 고정
- 품질: QA 5종 통과 후 export
- 재현: `target_date` backfill

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

Pages 배포: Deploy from a branch (`docs/`).
