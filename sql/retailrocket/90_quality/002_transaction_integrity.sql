SELECT
  'raw_rr_events.transaction_missing_transaction_id' AS issue,
  COUNT(*) AS bad_rows
FROM raw_rr_events
WHERE LOWER(TRIM(event_type)) = 'transaction'
  AND transaction_id IS NULL
HAVING COUNT(*) > 0;
