# 배치 성공보다 중요한 것: **신뢰할 수 있는 KPI**

> Airflow로 `RAW → STAGING → MART → KPI → QA → EXPORT`를 자동화해,  
> **같은 로그를 다시 실행하면 같은 KPI가 나오도록** 만든 데이터 품질 중심 파이프라인입니다.

- Repo: https://github.com/GeonYul2/DA-AIRFLOW_RETAILROCKET
- README: https://github.com/GeonYul2/DA-AIRFLOW_RETAILROCKET/blob/main/README.md

---

## 1) 왜 만들었나

실무에서는 배치 성공보다 아래 문제가 KPI 신뢰를 더 자주 깨뜨립니다.

- 세션 기준이 팀마다 달라 같은 로그에서도 CVR이 달라짐
- 전환 이벤트 정의가 바뀌어 분자/분모 해석이 흔들림
- `transaction_id` 누락/결측이 누적되어 구매 지표가 왜곡됨

그래서 이 프로젝트는 집계 자체보다,  
**“이 숫자를 의사결정에 써도 되는가”를 자동 검증하는 구조**를 목표로 했습니다.

---

## 2) 아키텍처

![Pipeline Architecture](assets/pipeline_architecture.svg)

1. **RAW**: 원본 보존 (추적 가능성)
2. **STAGING**: 타입/포맷 정규화
3. **MART**: 세션화 + 분석 단위 고정
4. **KPI**: 퍼널/코호트/CRM 계산
5. **QA**: 품질 기준 미달 시 차단
6. **EXPORT**: 통과 결과만 CSV/TXT 생성

---

## 3) QA 5종을 설계한 이유

QA 개수를 늘리는 게 목적이 아니라, **의사결정을 망치는 실패 모드**를 최소 세트로 막는 게 목적이었습니다.

| 실제 우려 상황 | 왜 위험한가 | 설계한 QA |
|---|---|---|
| 이벤트 타입 값이 제각각 유입 | 퍼널 분류 왜곡 | Domain check |
| 구매 이벤트 `transaction_id` 누락 | 구매 식별 불가 | Transaction integrity |
| 핵심 키 결측 | 세션/조인/집계 왜곡 전파 | Null checks |
| 핵심 테이블 0건 | 수집/적재 이상인데 집계 진행 | Rowcount sanity |
| KPI 범위 이탈/음수 | 계산 로직 오류가 운영 반영 | KPI sanity |

---

## 4) 테스트 케이스 명세

| Test Case | Given | PASS 기준 | 실패 시 동작 |
|---|---|---|---|
| TC-01 Domain | `event_type` 허용값 외 존재 여부 | 결과 0행 | 품질 체크 실패, DAG 중단 |
| TC-02 Integrity | `transaction` 이벤트의 `transaction_id IS NULL` | 결과 0행 | 품질 체크 실패, 원인 점검 후 backfill |
| TC-03 Null | 핵심 키 NULL 존재 여부 | 결과 0행 | 품질 체크 실패, 결측 원인 추적 |
| TC-04 Rowcount | 핵심 테이블 0건 여부 | 결과 0행 | 품질 체크 실패, 적재 단계 점검 |
| TC-05 KPI Sanity | CVR 0~1 범위/음수 이탈 여부 | 결과 0행 | 품질 체크 실패, 계산식 점검 |

> 구현상 `run_quality_checks.py`에서 하나라도 FAIL이면 `exit 1`로 종료되어,  
> QA 통과 전에는 export 단계가 실행되지 않습니다.

---

## 5) 실행 증거 (Proof)

### 5-1. 백필 실행 성공

대표 검증 실행: `target_date=2015-06-16`

![Airflow DAG run success graph](assets/rr_funnel_daily-graph.png)

### 5-2. 결과물 일관성

동일 포맷 산출물(CSV 3종 + summary TXT 1종)을 남겨 날짜 단위 비교 검증이 가능합니다.

![Outputs 2015-06-16](assets/outputs_2015-06-16.png)

---

## 6) 재현 방법 (Quick Run)

```bash
cp .env.example .env
make up
make init
make run-dag
```

수동 백필 실행 시:

```json
{"target_date":"2015-06-16"}
```

기대 산출물:

- `logs/reports/rr_funnel_daily_2015-06-16.csv`
- `logs/reports/rr_cohort_weekly_2015-06-16.csv`
- `logs/reports/rr_crm_targets_2015-06-16.csv`
- `logs/reports/rr_pipeline_summary_2015-06-16.txt`

---

## 7) 실무 활용 포인트

- **분석/그로스**: KPI 급락 시 캠페인 조정보다 정의/결측 이슈를 먼저 점검
- **DQA/운영**: 배치 성공과 지표 신뢰를 분리해 품질 기준 중심 운영

핵심 메시지:  
**“숫자를 만드는 파이프라인”이 아니라 “숫자를 믿을 수 있게 만드는 파이프라인.”**
