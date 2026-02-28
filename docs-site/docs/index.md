# DA-AIRFLOW_RETAILROCKET

Apache Airflow 기반 RetailRocket clickstream 분석 파이프라인입니다.

## 프로젝트 요약

- **문제**: 배치 성공만으로는 지표 신뢰를 보장할 수 없음
- **해결**: RAW → STAGING → MART → KPI → QA → EXPORT 계층형 데이터 파이프라인 구축
- **핵심 산출물**: Funnel, Cohort, CRM 대상 CSV + 파이프라인 요약 TXT

## 아키텍처

![Pipeline Architecture](assets/pipeline_architecture.svg)

## 빠른 시작

```bash
cp .env.example .env
make up
make init
make run-dag
make check
```
