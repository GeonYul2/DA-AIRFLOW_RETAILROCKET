SELECT
  'raw_rr_events.invalid_event_type' AS issue,
  event_type,
  COUNT(*) AS bad_rows
FROM raw_rr_events
WHERE event_type IS NOT NULL
  AND LOWER(TRIM(event_type)) NOT IN ('view', 'addtocart', 'transaction')
GROUP BY event_type
HAVING COUNT(*) > 0;
