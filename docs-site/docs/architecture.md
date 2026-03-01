# Architecture

![Pipeline Architecture](assets/pipeline_architecture.svg)

## 리스크 대응 관점 요약
- **RAW**: 원본 로그를 그대로 보존해 추적 가능성을 확보합니다.
- **STAGING**: 타입/포맷을 표준화해 전처리 편차를 줄입니다.
- **DATA MART**: dim/fact + 세션화를 고정해 분석 grain을 통일합니다.
- **KPI**: 퍼널·코호트·CRM 정의를 계산 테이블로 분리합니다.
- **QA**: 도메인/무결성/null/rowcount/KPI 범위 검증으로 왜곡 전파를 차단합니다.
- **EXPORT**: CSV 3종 + summary TXT를 고정 포맷으로 생성해 운영 전달을 단순화합니다.
