WITH kpi AS (
  SELECT
    kpi_date,
    sessions,
    views,
    addtocarts,
    purchases,
    sessions_with_view,
    sessions_with_cart,
    sessions_with_purchase
  FROM mart_rr_funnel_daily
  WHERE kpi_date = CAST('{{ target_date }}' AS DATE)
), src_events AS (
  SELECT
    CAST(SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS SIGNED) AS views,
    CAST(SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END) AS SIGNED) AS addtocarts,
    CAST(COUNT(DISTINCT CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN transaction_id END) AS SIGNED) AS purchases
  FROM fact_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
), src_sessions AS (
  SELECT
    CAST(COUNT(*) AS SIGNED) AS sessions,
    CAST(SUM(CASE WHEN has_view = 1 THEN 1 ELSE 0 END) AS SIGNED) AS sessions_with_view,
    CAST(SUM(CASE WHEN has_cart = 1 THEN 1 ELSE 0 END) AS SIGNED) AS sessions_with_cart,
    CAST(SUM(CASE WHEN has_purchase = 1 THEN 1 ELSE 0 END) AS SIGNED) AS sessions_with_purchase
  FROM fact_rr_sessions
  WHERE session_date = CAST('{{ target_date }}' AS DATE)
)
SELECT
  'mart_rr_funnel_daily.missing_target_date_row' AS issue,
  CAST('{{ target_date }}' AS DATE) AS kpi_date,
  CAST(NULL AS SIGNED) AS kpi_sessions,
  CAST(NULL AS SIGNED) AS src_sessions,
  CAST(NULL AS SIGNED) AS kpi_views,
  CAST(NULL AS SIGNED) AS src_views,
  CAST(NULL AS SIGNED) AS kpi_addtocarts,
  CAST(NULL AS SIGNED) AS src_addtocarts,
  CAST(NULL AS SIGNED) AS kpi_purchases,
  CAST(NULL AS SIGNED) AS src_purchases
WHERE NOT EXISTS (SELECT 1 FROM kpi)

UNION ALL

SELECT
  'mart_rr_funnel_daily.source_reconciliation_mismatch' AS issue,
  k.kpi_date,
  CAST(k.sessions AS SIGNED) AS kpi_sessions,
  s.sessions AS src_sessions,
  CAST(k.views AS SIGNED) AS kpi_views,
  e.views AS src_views,
  CAST(k.addtocarts AS SIGNED) AS kpi_addtocarts,
  e.addtocarts AS src_addtocarts,
  CAST(k.purchases AS SIGNED) AS kpi_purchases,
  e.purchases AS src_purchases
FROM kpi k
CROSS JOIN src_events e
CROSS JOIN src_sessions s
WHERE k.sessions <> s.sessions
   OR k.views <> e.views
   OR k.addtocarts <> e.addtocarts
   OR k.purchases <> e.purchases
   OR k.sessions_with_view <> s.sessions_with_view
   OR k.sessions_with_cart <> s.sessions_with_cart
   OR k.sessions_with_purchase <> s.sessions_with_purchase

UNION ALL

SELECT
  'mart_rr_funnel_daily.monotonicity_violation' AS issue,
  k.kpi_date,
  CAST(k.sessions AS SIGNED) AS kpi_sessions,
  s.sessions AS src_sessions,
  CAST(k.views AS SIGNED) AS kpi_views,
  e.views AS src_views,
  CAST(k.addtocarts AS SIGNED) AS kpi_addtocarts,
  e.addtocarts AS src_addtocarts,
  CAST(k.purchases AS SIGNED) AS kpi_purchases,
  e.purchases AS src_purchases
FROM kpi k
CROSS JOIN src_events e
CROSS JOIN src_sessions s
WHERE NOT (k.purchases <= k.addtocarts AND k.addtocarts <= k.views)
   OR NOT (k.sessions_with_purchase <= k.sessions_with_cart
           AND k.sessions_with_cart <= k.sessions_with_view
           AND k.sessions_with_view <= k.sessions);
