WITH scoped AS (
  SELECT *
  FROM raw_rr_events
  WHERE timestamp_ms IS NULL
     OR CAST(FROM_UNIXTIME(timestamp_ms / 1000.0) AS DATE) = CAST('{{ target_date }}' AS DATE)
), checks AS (
  SELECT
    'raw_rr_events.event_type_null_or_blank' AS issue,
    CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM scoped
  WHERE event_type IS NULL OR TRIM(event_type) = ''

  UNION ALL

  SELECT
    'raw_rr_events.event_type_invalid_domain' AS issue,
    CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM scoped
  WHERE event_type IS NOT NULL
    AND TRIM(event_type) <> ''
    AND LOWER(TRIM(event_type)) NOT IN ('view', 'addtocart', 'transaction')

  UNION ALL

  SELECT
    'raw_rr_events.timestamp_ms_invalid_non_positive' AS issue,
    CAST(COUNT(*) AS SIGNED) AS bad_rows
  FROM scoped
  WHERE timestamp_ms IS NOT NULL
    AND timestamp_ms <= 0
)
SELECT issue, bad_rows
FROM checks
WHERE bad_rows > 0;
