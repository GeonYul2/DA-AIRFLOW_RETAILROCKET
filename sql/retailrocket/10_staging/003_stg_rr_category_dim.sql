TRUNCATE TABLE stg_rr_category_dim;

WITH RECURSIVE roots AS (
  SELECT c.category_id, c.parent_id
  FROM raw_rr_category_tree c
  LEFT JOIN raw_rr_category_tree p ON c.parent_id = p.category_id
  WHERE c.parent_id IS NULL OR p.category_id IS NULL
),
tree AS (
  SELECT
    r.category_id,
    r.parent_id,
    0 AS depth,
    r.category_id::TEXT AS path,
    r.category_id AS root_category_id
  FROM roots r

  UNION ALL

  SELECT
    c.category_id,
    c.parent_id,
    t.depth + 1 AS depth,
    (t.path || '>' || c.category_id::TEXT) AS path,
    t.root_category_id
  FROM raw_rr_category_tree c
  JOIN tree t ON c.parent_id = t.category_id
)
INSERT INTO stg_rr_category_dim (category_id, parent_id, depth, root_category_id, path)
SELECT
  category_id,
  parent_id,
  depth,
  root_category_id,
  path
FROM tree;
