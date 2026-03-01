# 배치 성공이 아니라 KPI 신뢰를 보장하는 Airflow 파이프라인

RetailRocket clickstream으로 **퍼널·코호트·CRM 타겟**을 산출합니다.  
핵심은 “산출”이 아니라, **지표 정의·세션 기준·품질 검증**을 고정해 같은 데이터에서 같은 KPI가 나오게 만드는 것입니다.

**대표 재현(run):** `target_date=2015-06-16` manual backfill

---

## Why this exists

CVR 급락 알림이 오면 보통 캠페인/예산부터 건드립니다.  
하지만 세션 기준이 바뀌었거나, 전환 정의가 달라졌거나, `transaction_id` 누락이 있으면 **같은 로그에서도 결론이 달라질 수 있습니다.**  
이 프로젝트는 배치 성공보다 먼저 **“의사결정에 써도 되는 KPI인가”**를 확인하도록 설계했습니다.

---

## What you get

- **Outputs:** Funnel / Cohort / CRM Targets
- **Export:** CSV 3종 + summary TXT 1종(운영 전달물)
- **QA gates (5):** domain / integrity / null / rowcount / KPI range(0~1)
- **Reproducible run:** `target_date`로 과거 날짜 재계산(backfill)

---

## How it works

![Pipeline Architecture](assets/pipeline_architecture.svg)

- **RAW**: 원본 보존(추적 가능성 확보)
- **STAGING**: 타입/포맷 표준화(전처리 편차 감소)
- **DATA MART**: dim/fact + 세션화(분석 grain 통일)
- **KPI**: 퍼널·코호트·CRM 계산 테이블 분리(정의 단일화)
- **QA**: 품질 기준 통과 여부를 실행 조건으로 적용
- **EXPORT**: 운영 전달용 고정 포맷 생성

---

## Proof

### 1) 실제로 돌려보면
manual backfill run에서 모든 태스크가 성공합니다.

![Airflow run success](assets/airflow_run_success.png)

### 2) 무엇이 남나
동일 포맷의 산출물 4개(CSV 3 + TXT 1)가 생성됩니다. (샘플: 2015-06-16)

![Outputs 2015-06-16](assets/outputs_2015-06-16.png)

---

## So what

- **BA/그로스**: KPI 급락 시 “캠페인 조정” 전에 **정의/세션/누락**을 먼저 점검할 수 있습니다.  
- **DQA/운영**: 배치 성공과 KPI 신뢰를 분리해, **품질 기준으로 파이프라인을 운영**할 수 있습니다.

**Next**  
실서비스라면 실패 알림(Slack), 품질 대시보드, dbt/GE 테스트 연계로 확장할 수 있습니다.

---

## Links

- [Source Code](../../)
- [Metrics](metrics.md)
- [Runbook](runbook.md)
