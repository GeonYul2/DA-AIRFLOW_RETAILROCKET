WITH checks AS (
  SELECT 'stg_rr_events.event_ts_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM stg_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND event_ts IS NULL

  UNION ALL

  SELECT 'stg_rr_events.visitor_id_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM stg_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND visitor_id IS NULL

  UNION ALL

  SELECT 'stg_rr_events.item_id_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM stg_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND item_id IS NULL

  UNION ALL

  SELECT 'stg_rr_events.event_type_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM stg_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND event_type IS NULL

  UNION ALL

  SELECT 'fact_rr_events.event_ts_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM fact_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND event_ts IS NULL

  UNION ALL

  SELECT 'fact_rr_events.session_id_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM fact_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND session_id IS NULL

  UNION ALL

  SELECT 'fact_rr_events.visitor_id_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM fact_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND visitor_id IS NULL

  UNION ALL

  SELECT 'fact_rr_sessions.session_id_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM fact_rr_sessions
  WHERE session_date = CAST('{{ target_date }}' AS DATE)
    AND session_id IS NULL

  UNION ALL

  SELECT 'fact_rr_sessions.session_start_ts_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM fact_rr_sessions
  WHERE session_date = CAST('{{ target_date }}' AS DATE)
    AND session_start_ts IS NULL

  UNION ALL

  SELECT 'fact_rr_sessions.session_end_ts_null' AS issue, CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM fact_rr_sessions
  WHERE session_date = CAST('{{ target_date }}' AS DATE)
    AND session_end_ts IS NULL
)
SELECT issue, bad_rows
FROM checks
WHERE bad_rows > 0;
