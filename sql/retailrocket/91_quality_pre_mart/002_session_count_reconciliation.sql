WITH session_cnt AS (
  SELECT COUNT(*)::BIGINT AS cnt
  FROM fact_rr_sessions
  WHERE session_date = '{{ target_date }}'::DATE
), event_session_cnt AS (
  SELECT COUNT(DISTINCT session_id)::BIGINT AS cnt
  FROM fact_rr_events
  WHERE event_date = '{{ target_date }}'::DATE
)
SELECT
  'session_count_reconciliation.fact_sessions_vs_event_sessions_mismatch' AS issue,
  s.cnt AS fact_sessions_cnt,
  e.cnt AS fact_events_distinct_session_cnt
FROM session_cnt s
CROSS JOIN event_session_cnt e
WHERE s.cnt <> e.cnt;
