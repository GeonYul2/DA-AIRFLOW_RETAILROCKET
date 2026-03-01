# RetailRocket Dataset EDA (요약)

> 생성 시각: 2026-03-01 07:26 UTC  
> 생성 스크립트: `python3 scripts/profile_retailrocket_eda.py`

## 왜 이 요약이 필요한가
- 퍼널 분석 전, 데이터의 기본 구조(이벤트 타입/기간/규모)를 먼저 확인합니다.
- 카테고리 트리 구조(노드/루트/리프)를 확인해 카테고리 단위 지표 해석 가능성을 점검합니다.

## 1) Events 기본 통계 (`events.csv`)

| 항목 | 값 |
|---|---:|
| 전체 이벤트 행 수 | 2,756,101 |
| 고유 방문자 수 | 1,407,580 |
| 고유 아이템 수 | 235,061 |
| 기간(UTC date) | 2015-05-03 ~ 2015-09-18 |
| 활성 일수 | 139 |
| 일별 이벤트 중앙값 | 20,621 |
| 최소 일별 이벤트 | 2015-09-18 (1,528) |
| 최대 일별 이벤트 | 2015-07-26 (32,703) |

### 이벤트 타입 분포

| event | count | share |
|---|---:|---:|
| view | 2,664,312 | 96.67% |
| addtocart | 69,332 | 2.52% |
| transaction | 22,457 | 0.81% |

### 퍼널 관찰값 (이벤트 비율 기준)
- addtocart / view = **0.0260**
- transaction / addtocart = **0.3239**
- transaction 이벤트 중 `transaction_id` 누락 건수 = **0**

> 주의: 위 비율은 "세션 전환율"이 아니라 이벤트 수 기준입니다.  
> 세션 기반 CVR은 `fact_rr_sessions`와 `mart_rr_funnel_daily`에서 계산합니다.

## 2) Category Tree 기본 통계 (`category_tree.csv`)

| 항목 | 값 |
|---|---:|
| 카테고리 노드 수 | 1,669 |
| 루트 카테고리 수(`parentid` 비어있음) | 25 |
| 리프 카테고리 수(자식 없음) | 1,307 |

## 3) EDA 결과를 모델링에 연결한 방식
- 퍼널 단계는 원천 이벤트의 `view → addtocart → transaction` 구조를 그대로 사용했습니다.
- 카테고리 분석은 트리 구조를 평탄화한 `stg_rr_category_dim`과 `dim_rr_category`를 사용합니다.
- 전환율은 세션화 후 KPI 테이블에서 계산해 정의 불일치를 줄였습니다.
