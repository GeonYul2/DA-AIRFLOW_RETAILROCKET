TRUNCATE TABLE mart_rr_cohort_weekly;

WITH params AS (
  SELECT '{{ target_date }}'::DATE AS as_of_date
),
purchases AS (
  SELECT
    visitor_id,
    event_ts,
    DATE_TRUNC('week', event_ts)::DATE AS week_start
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
INSERT INTO mart_rr_cohort_weekly (cohort_week, week_index, cohort_size, active_visitors, retention_rate)
SELECT
  a.cohort_week,
  ((a.week_start - a.cohort_week) / 7) AS week_index,
  s.cohort_size,
  a.active_visitors,
  ROUND((a.active_visitors::NUMERIC / NULLIF(s.cohort_size, 0)), 4) AS retention_rate
FROM activity a
JOIN cohort_size s
  ON a.cohort_week = s.cohort_week
ORDER BY a.cohort_week, week_index;
