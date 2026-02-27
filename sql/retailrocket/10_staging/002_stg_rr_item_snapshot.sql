TRUNCATE TABLE stg_rr_item_snapshot;

WITH ranked AS (
  SELECT
    item_id,
    property,
    value,
    timestamp_ms,
    ROW_NUMBER() OVER (
      PARTITION BY item_id, property
      ORDER BY timestamp_ms DESC
    ) AS rn
  FROM raw_rr_item_properties
  WHERE property IN ('categoryid', 'available')
)
INSERT INTO stg_rr_item_snapshot (item_id, category_id, available)
SELECT
  item_id,
  MAX(CASE WHEN property = 'categoryid' AND rn = 1 THEN NULLIF(value, '')::BIGINT END) AS category_id,
  MAX(CASE WHEN property = 'available' AND rn = 1 THEN NULLIF(value, '')::INTEGER END) AS available
FROM ranked
GROUP BY item_id;
