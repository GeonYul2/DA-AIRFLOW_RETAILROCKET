TRUNCATE TABLE dim_rr_item;

INSERT INTO dim_rr_item (item_id, category_id, available)
SELECT
  item_id,
  category_id,
  available
FROM stg_rr_item_snapshot;
