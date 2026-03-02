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
  WHERE kpi_date = '{{ target_date }}'::DATE
), src_events AS (
  SELECT
    SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END)::BIGINT AS views,
    SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END)::BIGINT AS addtocarts,
    COUNT(DISTINCT CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN transaction_id END)::BIGINT AS purchases
  FROM fact_rr_events
  WHERE event_date = '{{ target_date }}'::DATE
), src_sessions AS (
  SELECT
    COUNT(*)::BIGINT AS sessions,
    SUM(CASE WHEN has_view = 1 THEN 1 ELSE 0 END)::BIGINT AS sessions_with_view,
    SUM(CASE WHEN has_cart = 1 THEN 1 ELSE 0 END)::BIGINT AS sessions_with_cart,
    SUM(CASE WHEN has_purchase = 1 THEN 1 ELSE 0 END)::BIGINT AS sessions_with_purchase
  FROM fact_rr_sessions
  WHERE session_date = '{{ target_date }}'::DATE
)
SELECT
  'mart_rr_funnel_daily.missing_target_date_row' AS issue,
  '{{ target_date }}'::DATE AS kpi_date,
  NULL::BIGINT AS kpi_sessions,
  NULL::BIGINT AS src_sessions,
  NULL::BIGINT AS kpi_views,
  NULL::BIGINT AS src_views,
  NULL::BIGINT AS kpi_addtocarts,
  NULL::BIGINT AS src_addtocarts,
  NULL::BIGINT AS kpi_purchases,
  NULL::BIGINT AS src_purchases
WHERE NOT EXISTS (SELECT 1 FROM kpi)

UNION ALL

SELECT
  'mart_rr_funnel_daily.source_reconciliation_mismatch' AS issue,
  k.kpi_date,
  k.sessions::BIGINT AS kpi_sessions,
  s.sessions AS src_sessions,
  k.views::BIGINT AS kpi_views,
  e.views AS src_views,
  k.addtocarts::BIGINT AS kpi_addtocarts,
  e.addtocarts AS src_addtocarts,
  k.purchases::BIGINT AS kpi_purchases,
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
  k.sessions::BIGINT AS kpi_sessions,
  s.sessions AS src_sessions,
  k.views::BIGINT AS kpi_views,
  e.views AS src_views,
  k.addtocarts::BIGINT AS kpi_addtocarts,
  e.addtocarts AS src_addtocarts,
  k.purchases::BIGINT AS kpi_purchases,
  e.purchases AS src_purchases
FROM kpi k
CROSS JOIN src_events e
CROSS JOIN src_sessions s
WHERE NOT (k.purchases <= k.addtocarts AND k.addtocarts <= k.views)
   OR NOT (k.sessions_with_purchase <= k.sessions_with_cart
           AND k.sessions_with_cart <= k.sessions_with_view
           AND k.sessions_with_view <= k.sessions);
