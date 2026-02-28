# Metrics

## Funnel KPI

- 테이블: `mart_rr_funnel_daily`
- 기준: 일 단위 세션/이벤트 기반 전환 흐름
- 대표 지표:
  - 방문(views)
  - 장바구니(add-to-cart)
  - 구매(transactions)
  - 전환율(CVR)

## Cohort KPI

- 테이블: `mart_rr_cohort_weekly`
- 기준: 구매 코호트(첫 구매 주차) 잔존/재구매 추적
- 대표 지표:
  - 코호트 크기
  - 코호트 주차별 활성 사용자
  - retention ratio

## CRM KPI

- 테이블: `mart_rr_crm_targets_daily`
- 세그먼트:
  - `cart_abandoner_today`
  - `high_intent_viewer_7d_no_cart`
  - `repeat_buyer`

## QA Gate (신뢰성)

- 이벤트 도메인 체크
- transaction 무결성 체크
- null 체크(핵심 키)
- row count sanity
- KPI 범위 sanity (CVR 0~1)
