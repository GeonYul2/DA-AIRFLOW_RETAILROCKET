DELETE FROM mart_rr_crm_targets_daily
WHERE kpi_date = CAST('{{ target_date }}' AS DATE);

INSERT INTO mart_rr_crm_targets_daily (kpi_date, visitor_id, segment_name, evidence)
WITH cart AS (
  SELECT
    visitor_id,
    MAX(event_ts) AS last_cart_ts,
    COUNT(*) AS cart_events
  FROM fact_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND event_type = 'addtocart'
  GROUP BY visitor_id
),
purchase AS (
  SELECT DISTINCT visitor_id
  FROM fact_rr_events
  WHERE event_date = CAST('{{ target_date }}' AS DATE)
    AND event_type = 'transaction'
    AND transaction_id IS NOT NULL
),
abandon AS (
  SELECT
    c.visitor_id,
    c.last_cart_ts,
    c.cart_events
  FROM cart c
  LEFT JOIN purchase p
    ON c.visitor_id = p.visitor_id
  WHERE p.visitor_id IS NULL
)
SELECT
  CAST('{{ target_date }}' AS DATE) AS kpi_date,
  visitor_id,
  'cart_abandoner_today' AS segment_name,
  CONCAT('last_cart_ts=', CAST(last_cart_ts AS CHAR), ', cart_events=', CAST(cart_events AS CHAR)) AS evidence
FROM abandon
ORDER BY cart_events DESC, last_cart_ts DESC
LIMIT 5000;

INSERT INTO mart_rr_crm_targets_daily (kpi_date, visitor_id, segment_name, evidence)
WITH params AS (
  SELECT
    CAST('{{ target_date }}' AS DATE) AS as_of_date,
    DATE_SUB(CAST('{{ target_date }}' AS DATE), INTERVAL 6 DAY) AS start_date
),
views AS (
  SELECT
    e.visitor_id,
    COUNT(*) AS view_events
  FROM fact_rr_events e, params
  WHERE e.event_date BETWEEN params.start_date AND params.as_of_date
    AND e.event_type = 'view'
  GROUP BY e.visitor_id
),
carts AS (
  SELECT DISTINCT e.visitor_id
  FROM fact_rr_events e, params
  WHERE e.event_date BETWEEN params.start_date AND params.as_of_date
    AND e.event_type = 'addtocart'
),
purchases AS (
  SELECT DISTINCT e.visitor_id
  FROM fact_rr_events e, params
  WHERE e.event_date BETWEEN params.start_date AND params.as_of_date
    AND e.event_type = 'transaction'
    AND e.transaction_id IS NOT NULL
),
candidates AS (
  SELECT
    v.visitor_id,
    v.view_events
  FROM views v
  LEFT JOIN carts c ON v.visitor_id = c.visitor_id
  LEFT JOIN purchases p ON v.visitor_id = p.visitor_id
  WHERE v.view_events >= 20
    AND c.visitor_id IS NULL
    AND p.visitor_id IS NULL
)
SELECT
  CAST('{{ target_date }}' AS DATE) AS kpi_date,
  visitor_id,
  'high_intent_viewer_7d_no_cart' AS segment_name,
  CONCAT('view_events_7d=', CAST(view_events AS CHAR)) AS evidence
FROM candidates
ORDER BY view_events DESC
LIMIT 5000;

INSERT INTO mart_rr_crm_targets_daily (kpi_date, visitor_id, segment_name, evidence)
WITH tx AS (
  SELECT
    visitor_id,
    COUNT(DISTINCT transaction_id) AS tx_cnt,
    MAX(event_ts) AS last_purchase_ts
  FROM fact_rr_events
  WHERE event_date <= CAST('{{ target_date }}' AS DATE)
    AND event_type = 'transaction'
    AND transaction_id IS NOT NULL
  GROUP BY visitor_id
  HAVING COUNT(DISTINCT transaction_id) >= 2
)
SELECT
  CAST('{{ target_date }}' AS DATE) AS kpi_date,
  visitor_id,
  'repeat_buyer' AS segment_name,
  CONCAT('tx_cnt=', CAST(tx_cnt AS CHAR), ', last_purchase_ts=', CAST(last_purchase_ts AS CHAR)) AS evidence
FROM tx
ORDER BY tx_cnt DESC, last_purchase_ts DESC
LIMIT 5000;
