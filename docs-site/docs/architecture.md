# Architecture

## 레이어 설계

1. **RAW**: 원본 로그 적재 (`raw_rr_*`)
2. **STAGING**: 타입/포맷 정규화 (`stg_rr_*`)
3. **MART**: 차원/사실 모델 + 세션화 (`dim_rr_*`, `fact_rr_*`)
4. **KPI**: 퍼널/코호트/CRM 지표 계산 (`mart_rr_*`)
5. **QA**: 품질 게이트 5종 검증 (`quality_check_runs`)
6. **EXPORT**: 전달용 CSV/TXT 산출물 생성

## 데이터 흐름

```text
raw files
  -> load_raw
  -> staging SQL
  -> mart SQL
  -> kpi SQL
  -> quality checks
  -> export scripts
```

## DAG 흐름

`check_raw_freshness -> load_raw_rr -> build_staging -> build_mart -> compute_kpis -> run_quality_checks -> export_funnel -> export_cohort -> export_crm -> write_summary`
