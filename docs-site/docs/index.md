# 배치 성공보다 중요한 것: **신뢰할 수 있는 KPI**

RetailRocket clickstream으로 퍼널·코호트·CRM 타겟을 산출하는 Airflow 파이프라인입니다. 핵심은 배치 성공이 아니라, 지표 정의·세션 기준·품질 검증을 고정해 같은 데이터에서 같은 KPI가 나오게 만드는 것입니다.

---

## 왜 이 파이프라인이 필요한가

CVR 급락 알림이 오면 보통 캠페인/예산 조정을 먼저 논의합니다. 하지만 세션 기준, 전환 정의, `transaction_id` 무결성이 흔들리면 같은 로그에서도 결론이 달라질 수 있습니다.

- 세션 기준 변화로 CVR 해석이 달라질 수 있음
- `transaction_id` 누락/중복으로 구매·매출 지표 왜곡 가능
- 배치 success만으로는 도메인 오류·결측·중복 전파를 막기 어려움

이 프로젝트의 목표는 위 리스크를 줄이기 위해 지표 정의·세션 기준·품질 검증을 고정하고, QA를 통과한 결과만 운영 산출물로 전달하는 파이프라인을 구축하는 것입니다.

---

## 파이프라인 구조

![Pipeline Architecture](assets/pipeline_architecture.svg)

1. **RAW**: 원본 보존과 추적 기준 확보
2. **STAGING**: 이벤트 타입/시간/속성 정규화
3. **DATA MART**: 세션 규칙을 SQL로 고정
4. **KPI**: Funnel/Cohort/CRM 계산 분리
5. **QA**: 품질 기준 미달 시 후속 단계 차단
6. **EXPORT**: QA 통과 실행에서만 CSV/TXT 생성

---

## QA 5종을 설계한 이유

프로젝트를 진행하면서 “배치는 성공했는데 KPI는 틀릴 수 있는 상황”을 먼저 정리했고, 그 상황을 막기 위한 최소 검증 세트로 QA 5종을 설계했습니다.

| 실제 우려 상황 | 왜 위험한가 | 설계한 QA |
|---|---|---|
| 이벤트 타입 값이 제각각 들어옴 (`view`/`View`/오타) | 이벤트 분류가 깨지면 퍼널 분자/분모 왜곡 | Domain check |
| 구매 이벤트에 `transaction_id`가 비어 있음 | 구매 식별 불가로 구매 지표 신뢰 붕괴 | Transaction integrity |
| 핵심 키(`timestamp_ms`, `visitor_id`, `item_id`, `event_ts`) 결측 | 세션화/조인/집계 단계에 누락 전파 | Null checks |
| STAGING/MART 핵심 테이블 0건 | 수집/적재 이상인데 후속 집계 진행 위험 | Rowcount sanity |
| CVR 0~1 범위 이탈 또는 음수 | 계산식/분모 처리 오류가 운영 지표로 배포 | KPI sanity |

---

## 테스트 케이스 명세

| Test Case | Given (검증 상황) | PASS 기준 | 실패 시 기대 동작 |
|---|---|---|---|
| TC-01 Domain | `raw_rr_events.event_type` 허용값 외 존재 여부 | 결과 0행 | 품질 체크 실패로 DAG 중단, export 차단 |
| TC-02 Integrity | `event_type='transaction' AND transaction_id IS NULL` 존재 여부 | 결과 0행 | 품질 체크 실패, 원천/적재 로직 점검 후 backfill |
| TC-03 Null | 핵심 키 NULL 존재 여부 | 결과 0행 | 품질 체크 실패, 결측 원인 추적 후 재실행 |
| TC-04 Rowcount | `stg/fact` 핵심 테이블 0건 여부 | 결과 0행(=모두 1건 이상) | 품질 체크 실패, 적재/마트 단계 상태 점검 |
| TC-05 KPI Sanity | target_date KPI 값의 음수/범위 이탈 여부 | 결과 0행 | 품질 체크 실패, 분모·분자·계산식 점검 |

`scripts/run_quality_checks.py`는 하나라도 FAIL이면 비정상 종료(`exit 1`)됩니다. 이 때문에 QA 통과 전에는 CSV/TXT export가 실행되지 않습니다.

---

## 실행 증거

대표 검증 실행은 `target_date=2015-06-16` 수동 백필(run)입니다.

![Airflow DAG run success graph](assets/rr_funnel_daily-graph.png)

동일 포맷 산출물(CSV 3종 + summary TXT 1종)을 남겨 날짜 단위 비교 검증이 가능합니다.

![Outputs 2015-06-16](assets/outputs_2015-06-16.png)

핵심 수치(`2015-06-16`):
- Funnel: visitors `4,379`, sessions `4,540`, purchases `67`, `cvr_session_to_purchase=0.0134`
- CRM 분포: `cart_abandoner_today=80`, `high_intent_viewer_7d_no_cart=115`, `repeat_buyer=117`
- QA: `001~005` 모두 `PASS`

---

## 재현 방법

```bash
cp .env.example .env
make up
make init
make run-dag
```

수동 백필 실행:

```json
{"target_date":"2015-06-16"}
```

기대 산출물(4개):

- `logs/reports/rr_funnel_daily_2015-06-16.csv`
- `logs/reports/rr_cohort_weekly_2015-06-16.csv`
- `logs/reports/rr_crm_targets_2015-06-16.csv`
- `logs/reports/rr_pipeline_summary_2015-06-16.txt`

---

## 활용 관점

- **BA/그로스**: 캠페인 조정 전에 정의/세션/누락 이슈를 먼저 점검할 수 있습니다.
- **DQA/운영**: 배치 성공과 KPI 신뢰를 분리해 품질 기준으로 운영할 수 있습니다.

핵심 메시지는 한 가지입니다. 숫자를 만드는 것이 아니라 숫자를 믿을 수 있게 만드는 파이프라인입니다.

---

- Repo: https://github.com/GeonYul2/DA-AIRFLOW_RETAILROCKET
- README: https://github.com/GeonYul2/DA-AIRFLOW_RETAILROCKET/blob/main/README.md
