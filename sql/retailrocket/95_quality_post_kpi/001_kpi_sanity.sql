SELECT
  'mart_rr_funnel_daily.invalid_values' AS issue,
  kpi_date,
  visitors,
  sessions,
  views,
  addtocarts,
  purchases,
  cvr_session_to_purchase,
  cvr_view_to_cart,
  cvr_cart_to_purchase
FROM mart_rr_funnel_daily
WHERE kpi_date = CAST('{{ target_date }}' AS DATE)
  AND (
    visitors < 0 OR sessions < 0 OR views < 0 OR addtocarts < 0 OR purchases < 0
    OR cvr_session_to_purchase < 0 OR cvr_session_to_purchase > 1
    OR cvr_view_to_cart < 0 OR cvr_view_to_cart > 1
    OR cvr_cart_to_purchase < 0 OR cvr_cart_to_purchase > 1
  );
