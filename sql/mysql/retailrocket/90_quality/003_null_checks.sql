SELECT 'raw_rr_events.timestamp_ms_null' AS issue, COUNT(*) AS bad_rows
FROM raw_rr_events
WHERE timestamp_ms IS NULL
HAVING COUNT(*) > 0

UNION ALL

SELECT 'raw_rr_events.visitor_id_null' AS issue, COUNT(*) AS bad_rows
FROM raw_rr_events
WHERE visitor_id IS NULL
HAVING COUNT(*) > 0

UNION ALL

SELECT 'raw_rr_events.item_id_null' AS issue, COUNT(*) AS bad_rows
FROM raw_rr_events
WHERE item_id IS NULL
HAVING COUNT(*) > 0

UNION ALL

SELECT 'stg_rr_events.event_ts_null' AS issue, COUNT(*) AS bad_rows
FROM stg_rr_events
WHERE event_ts IS NULL
HAVING COUNT(*) > 0;
