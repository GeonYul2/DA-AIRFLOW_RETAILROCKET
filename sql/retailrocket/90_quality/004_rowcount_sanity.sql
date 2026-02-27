SELECT 'stg_rr_events.empty' AS issue, COUNT(*) AS rows
FROM stg_rr_events
HAVING COUNT(*) = 0

UNION ALL

SELECT 'fact_rr_events.empty' AS issue, COUNT(*) AS rows
FROM fact_rr_events
HAVING COUNT(*) = 0

UNION ALL

SELECT 'fact_rr_sessions.empty' AS issue, COUNT(*) AS rows
FROM fact_rr_sessions
HAVING COUNT(*) = 0;
