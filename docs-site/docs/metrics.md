# Metrics

## Funnel
- **Definition**: `mart_rr_funnel_daily`에서 일자별 방문·세션·장바구니·구매와 CVR을 계산합니다.
- **Why it matters**: 전환 병목을 빠르게 찾을 수 있습니다.
- **Common pitfall**: 세션 기준이 바뀌면 같은 로그여도 CVR이 달라집니다.

## Cohort
- **Definition**: `mart_rr_cohort_weekly`에서 첫 구매 주차 기준으로 주차별 유지율을 계산합니다.
- **Why it matters**: 신규 유입 이후 재방문/재구매 패턴을 추적할 수 있습니다.
- **Common pitfall**: 분모(cohort_size) 정의가 바뀌면 유지율 비교가 깨집니다.

## CRM Targets
- **Definition**: `mart_rr_crm_targets_daily`에서 실행 세그먼트를 생성합니다.
- **Why it matters**: 분석 결과를 캠페인/CRM 실행 리스트로 바로 연결할 수 있습니다.
- **Common pitfall**: `transaction_id` 누락/중복이 있으면 타겟 분류가 흔들립니다.

## When KPI can change
- 세션 기준 변경
- 전환 정의(분자/분모) 변경
- `transaction_id` 누락/중복
