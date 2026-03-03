TRUNCATE TABLE mart_rr_cohort_weekly;

INSERT INTO mart_rr_cohort_weekly (cohort_week, week_index, cohort_size, active_visitors, retention_rate)
WITH params AS (
  SELECT CAST('{{ target_date }}' AS DATE) AS as_of_date
),
purchases AS (
  SELECT
    visitor_id,
    event_ts,
    DATE_SUB(DATE(event_ts), INTERVAL WEEKDAY(event_ts) DAY) AS week_start
  FROM fact_rr_events, params
  WHERE event_type = 'transaction'
    AND transaction_id IS NOT NULL
    AND event_date <= params.as_of_date
),
cohort AS (
  SELECT
    visitor_id,
    MIN(week_start) AS cohort_week
  FROM purchases
  GROUP BY visitor_id
),
cohort_size AS (
  SELECT
    cohort_week,
    COUNT(*) AS cohort_size
  FROM cohort
  GROUP BY cohort_week
),
activity AS (
  SELECT
    c.cohort_week,
    p.week_start,
    COUNT(DISTINCT p.visitor_id) AS active_visitors
  FROM cohort c
  JOIN purchases p
    ON c.visitor_id = p.visitor_id
  GROUP BY c.cohort_week, p.week_start
)
SELECT
  a.cohort_week,
  TIMESTAMPDIFF(WEEK, a.cohort_week, a.week_start) AS week_index,
  s.cohort_size,
  a.active_visitors,
  ROUND((CAST(a.active_visitors AS DECIMAL(18, 4)) / NULLIF(s.cohort_size, 0)), 4) AS retention_rate
FROM activity a
JOIN cohort_size s
  ON a.cohort_week = s.cohort_week
ORDER BY a.cohort_week, week_index;
