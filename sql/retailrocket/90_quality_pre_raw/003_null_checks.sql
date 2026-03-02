WITH scoped AS (
  SELECT *
  FROM raw_rr_events
  WHERE timestamp_ms IS NULL
     OR to_timestamp(timestamp_ms / 1000.0)::DATE = '{{ target_date }}'::DATE
), checks AS (
  SELECT 'raw_rr_events.timestamp_ms_null' AS issue, COUNT(*)::BIGINT AS bad_rows
  FROM scoped
  WHERE timestamp_ms IS NULL

  UNION ALL

  SELECT 'raw_rr_events.visitor_id_null' AS issue, COUNT(*)::BIGINT AS bad_rows
  FROM scoped
  WHERE visitor_id IS NULL

  UNION ALL

  SELECT 'raw_rr_events.event_type_null' AS issue, COUNT(*)::BIGINT AS bad_rows
  FROM scoped
  WHERE event_type IS NULL

  UNION ALL

  SELECT 'raw_rr_events.item_id_null' AS issue, COUNT(*)::BIGINT AS bad_rows
  FROM scoped
  WHERE item_id IS NULL
)
SELECT issue, bad_rows
FROM checks
WHERE bad_rows > 0;
