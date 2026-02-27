TRUNCATE TABLE dim_rr_visitor;

INSERT INTO dim_rr_visitor (visitor_id, first_event_ts, first_purchase_ts, first_purchase_date)
SELECT
  visitor_id,
  MIN(event_ts) AS first_event_ts,
  MIN(CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN event_ts END) AS first_purchase_ts,
  MIN(CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN event_date END) AS first_purchase_date
FROM stg_rr_events
GROUP BY visitor_id;
