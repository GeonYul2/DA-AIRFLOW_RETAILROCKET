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
  to_timestamp(timestamp_ms / 1000.0)::timestamp AS event_ts,
  to_timestamp(timestamp_ms / 1000.0)::date      AS event_date,
  visitor_id,
  item_id,
  LOWER(TRIM(event_type))                        AS event_type,
  transaction_id
FROM raw_rr_events;
