TRUNCATE TABLE fact_rr_sessions;

INSERT INTO fact_rr_sessions (
  session_date,
  visitor_id,
  session_id,
  session_start_ts,
  session_end_ts,
  views_cnt,
  carts_cnt,
  purchases_cnt,
  has_view,
  has_cart,
  has_purchase
)
SELECT
  MIN(event_date) AS session_date,
  visitor_id,
  session_id,
  MIN(event_ts) AS session_start_ts,
  MAX(event_ts) AS session_end_ts,
  SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS views_cnt,
  SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END) AS carts_cnt,
  COUNT(DISTINCT CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN transaction_id END) AS purchases_cnt,
  CASE WHEN SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS has_view,
  CASE WHEN SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS has_cart,
  CASE WHEN SUM(CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS has_purchase
FROM fact_rr_events
GROUP BY visitor_id, session_id;
