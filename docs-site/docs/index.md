# DA-AIRFLOW_RETAILROCKET

RetailRocket clickstream으로 **퍼널·코호트·CRM 타겟**을 산출한 Airflow 파이프라인입니다.  
지표 정의, 세션 기준, QA 기준을 고정해 같은 데이터에서 같은 KPI가 나오도록 설계했습니다.  
결과는 운영 전달용 **CSV 3종 + summary TXT 1종**으로 생성됩니다.

[Source Code](https://github.com/GeonYul2/DA-AIRFLOW_RETAILROCKET) · [Metrics](metrics.md) · [Runbook](runbook.md)

## 현업 시나리오
CVR 급락 알림이 오면 보통 캠페인/예산 조정부터 검토합니다.  
하지만 세션 기준 변경, 전환 정의 차이, `transaction_id` 누락이 있으면 같은 로그에서도 결론이 달라집니다.  
이 프로젝트는 이 오판 가능성을 줄이기 위해 기준 고정과 QA 통과를 선행 조건으로 둡니다.

## 내가 한 선택
- 세션 기준을 분석 테이블 단계에서 통일(30분 비활동 + 날짜 변경)
- 지표 정의(분자/분모)와 전처리/세션화 책임 분리
- QA 5종(도메인/무결성/null/row count/KPI 범위) 고정
- 운영 전달물 포맷을 export 4종으로 고정(CSV 3 + TXT 1)
- `target_date` 지정 백필로 과거 날짜 재계산(재현/검증)

## 결과
- QA를 통과한 run에서만 산출물이 생성됩니다.
- 실행 1회마다 동일한 포맷의 결과 파일이 생성됩니다.
- 지표 계산 로직과 품질 검증 로직을 분리해 원인 추적이 쉬워졌습니다.

## Evidence

### Run evidence
*manual backfill run, all tasks success*

![Airflow DAG Run Success](assets/airflow_run_success.png)

### Output evidence
*CSV 3종 + summary TXT 생성(2015-06-16)*

![Outputs 2015-06-16](assets/outputs_2015-06-16.png)
