WITH scoped AS (
  SELECT *
  FROM raw_rr_events
  WHERE timestamp_ms IS NOT NULL
    AND timestamp_ms > 0
    AND CAST(FROM_UNIXTIME(timestamp_ms / 1000.0) AS DATE) = CAST('{{ target_date }}' AS DATE)
), checks AS (
  SELECT
    'raw_rr_events.transaction_missing_transaction_id' AS issue,
    CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM scoped
  WHERE LOWER(TRIM(COALESCE(event_type, ''))) = 'transaction'
    AND transaction_id IS NULL

  UNION ALL

  SELECT
    'raw_rr_events.non_transaction_has_transaction_id' AS issue,
    CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM scoped
  WHERE LOWER(TRIM(COALESCE(event_type, ''))) <> 'transaction'
    AND transaction_id IS NOT NULL

  UNION ALL

  SELECT
    'raw_rr_events.transaction_id_multi_visitor' AS issue,
    CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM (
    SELECT transaction_id
    FROM scoped
    WHERE transaction_id IS NOT NULL
    GROUP BY transaction_id
    HAVING COUNT(DISTINCT visitor_id) > 1
  ) t
)
SELECT issue, bad_rows
FROM checks
WHERE bad_rows > 0;
