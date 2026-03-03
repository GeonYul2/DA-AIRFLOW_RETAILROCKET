TRUNCATE TABLE stg_rr_item_snapshot;

INSERT INTO stg_rr_item_snapshot (item_id, category_id, available)
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
SELECT
  item_id,
  MAX(CASE WHEN property = 'categoryid' AND rn = 1 THEN CAST(NULLIF(value, '') AS SIGNED) END) AS category_id,
  MAX(CASE WHEN property = 'available' AND rn = 1 THEN CAST(NULLIF(value, '') AS SIGNED) END) AS available
FROM ranked
GROUP BY item_id;
