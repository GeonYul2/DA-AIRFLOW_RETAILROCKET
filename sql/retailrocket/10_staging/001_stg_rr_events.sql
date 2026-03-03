TRUNCATE TABLE stg_rr_events;

INSERT INTO stg_rr_events (
  event_ts,
  event_date,
  visitor_id,
  item_id,
  event_type,
  transaction_id
)
SELECT
  FROM_UNIXTIME(timestamp_ms / 1000.0) AS event_ts,
  DATE(FROM_UNIXTIME(timestamp_ms / 1000.0)) AS event_date,
  visitor_id,
  item_id,
  LOWER(TRIM(event_type)) AS event_type,
  transaction_id
FROM raw_rr_events;
