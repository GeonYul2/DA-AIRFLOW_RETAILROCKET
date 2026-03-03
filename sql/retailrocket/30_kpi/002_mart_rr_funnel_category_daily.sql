DELETE FROM mart_rr_funnel_category_daily
WHERE kpi_date = CAST('{{ target_date }}' AS DATE);

INSERT INTO mart_rr_funnel_category_daily (
  kpi_date,
  root_category_id,
  views,
  addtocarts,
  purchase_events,
  cvr_view_to_cart,
  cvr_cart_to_purchase
)
WITH base AS (
  SELECT
    COALESCE(cat.root_category_id, 0) AS root_category_id,
    e.event_type,
    e.transaction_id
  FROM fact_rr_events e
  LEFT JOIN dim_rr_item i
    ON e.item_id = i.item_id
  LEFT JOIN dim_rr_category cat
    ON i.category_id = cat.category_id
  WHERE e.event_date = CAST('{{ target_date }}' AS DATE)
)
SELECT
  CAST('{{ target_date }}' AS DATE) AS kpi_date,
  root_category_id,
  SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS views,
  SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END) AS addtocarts,
  SUM(CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN 1 ELSE 0 END) AS purchase_events,
  ROUND(
    (
      CAST(SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END) AS DECIMAL(18, 4))
      / NULLIF(SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END), 0)
    ),
    4
  ) AS cvr_view_to_cart,
  ROUND(
    (
      CAST(SUM(CASE WHEN event_type = 'transaction' AND transaction_id IS NOT NULL THEN 1 ELSE 0 END) AS DECIMAL(18, 4))
      / NULLIF(SUM(CASE WHEN event_type = 'addtocart' THEN 1 ELSE 0 END), 0)
    ),
    4
  ) AS cvr_cart_to_purchase
FROM base
GROUP BY root_category_id;
