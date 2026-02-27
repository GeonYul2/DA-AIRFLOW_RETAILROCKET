TRUNCATE TABLE dim_rr_category;

INSERT INTO dim_rr_category (category_id, parent_id, depth, root_category_id, path)
SELECT
  category_id,
  parent_id,
  depth,
  root_category_id,
  path
FROM stg_rr_category_dim;
