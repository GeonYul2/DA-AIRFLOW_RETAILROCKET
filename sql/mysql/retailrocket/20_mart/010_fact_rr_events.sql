TRUNCATE TABLE fact_rr_events;

INSERT INTO fact_rr_events (
  event_ts,
  event_date,
  visitor_id,
  session_id,
  item_id,
  event_type,
  transaction_id
)
WITH ordered AS (
  SELECT
    e.event_ts,
    e.event_date,
    e.visitor_id,
    e.item_id,
    e.event_type,
    e.transaction_id,
    LAG(e.event_ts) OVER (PARTITION BY e.visitor_id ORDER BY e.event_ts, e.item_id, e.event_type) AS prev_ts,
    LAG(e.event_date) OVER (PARTITION BY e.visitor_id ORDER BY e.event_ts, e.item_id, e.event_type) AS prev_date
  FROM stg_rr_events e
),
flagged AS (
  SELECT
    *,
    CASE
      WHEN prev_ts IS NULL THEN 1
      WHEN event_date <> prev_date THEN 1
      WHEN TIMESTAMPDIFF(MINUTE, prev_ts, event_ts) > 30 THEN 1
      ELSE 0
    END AS new_sess
  FROM ordered
),
sessionized AS (
  SELECT
    *,
    SUM(new_sess) OVER (
      PARTITION BY visitor_id
      ORDER BY event_ts, item_id, event_type
      ROWS UNBOUNDED PRECEDING
    ) AS session_index
  FROM flagged
)
SELECT
  event_ts,
  event_date,
  visitor_id,
  CONCAT(CAST(visitor_id AS CHAR), '-', CAST(session_index AS CHAR)) AS session_id,
  item_id,
  event_type,
  transaction_id
FROM sessionized;
