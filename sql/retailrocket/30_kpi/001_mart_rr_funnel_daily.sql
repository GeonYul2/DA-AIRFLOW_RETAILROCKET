DELETE FROM mart_rr_funnel_daily
WHERE kpi_date = CAST('{{ target_date }}' AS DATE);

INSERT INTO mart_rr_funnel_daily (
  kpi_date,
  visitors,
  sessions,
  views,
  addtocarts,
  purchases,
  sessions_with_view,
  sessions_with_cart,
  sessions_with_purchase,
  cvr_session_to_purchase,
  cvr_view_to_cart,
  cvr_cart_to_purchase
)
WITH e AS (
  SELECT *
  FROM fact_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
),
s AS (
  SELECT *
  FROM fact_rr_sessions
  WHERE session_date = CAST('{{ target_date }}' AS DATE)
),
agg_events AS (
  SELECT
    COUNT(DISTINCT visitor_id) AS visitors,
    SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS views,
    SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END) AS addtocarts,
    COUNT(DISTINCT CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN transaction_id END) AS purchases
  FROM e
),
agg_sessions AS (
  SELECT
    COUNT(*) AS sessions,
    SUM(CASE WHEN has_view = 1 THEN 1 ELSE 0 END) AS sessions_with_view,
    SUM(CASE WHEN has_cart = 1 THEN 1 ELSE 0 END) AS sessions_with_cart,
    SUM(CASE WHEN has_purchase = 1 THEN 1 ELSE 0 END) AS sessions_with_purchase
  FROM s
)
SELECT
  CAST('{{ target_date }}' AS DATE) AS kpi_date,
  ev.visitors,
  se.sessions,
  ev.views,
  ev.addtocarts,
  ev.purchases,
  se.sessions_with_view,
  se.sessions_with_cart,
  se.sessions_with_purchase,
  ROUND((CAST(se.sessions_with_purchase AS DECIMAL(18, 4)) / NULLIF(se.sessions, 0)), 4) AS cvr_session_to_purchase,
  ROUND((CAST(se.sessions_with_cart AS DECIMAL(18, 4)) / NULLIF(se.sessions_with_view, 0)), 4) AS cvr_view_to_cart,
  ROUND((CAST(se.sessions_with_purchase AS DECIMAL(18, 4)) / NULLIF(se.sessions_with_cart, 0)), 4) AS cvr_cart_to_purchase
FROM agg_events ev
CROSS JOIN agg_sessions se;
