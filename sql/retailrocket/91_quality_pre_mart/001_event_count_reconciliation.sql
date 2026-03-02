WITH raw_cnt AS (
  SELECT COUNT(*)::BIGINT AS cnt
  FROM raw_rr_events
  WHERE timestamp_ms IS NOT NULL
    AND timestamp_ms > 0
    AND to_timestamp(timestamp_ms / 1000.0)::DATE = '{{ target_date }}'::DATE
), stg_cnt AS (
  SELECT COUNT(*)::BIGINT AS cnt
  FROM stg_rr_events
  WHERE event_date = '{{ target_date }}'::DATE
), fact_cnt AS (
  SELECT COUNT(*)::BIGINT AS cnt
  FROM fact_rr_events
  WHERE event_date = '{{ target_date }}'::DATE
)
SELECT
  'event_count_reconciliation.raw_stg_fact_mismatch' AS issue,
  r.cnt AS raw_cnt,
  s.cnt AS stg_cnt,
  f.cnt AS fact_cnt
FROM raw_cnt r
CROSS JOIN stg_cnt s
CROSS JOIN fact_cnt f
WHERE NOT (r.cnt = s.cnt AND s.cnt = f.cnt);
