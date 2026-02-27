-- RetailRocket track (Postgres-first)

CREATE TABLE IF NOT EXISTS raw_rr_events (
  timestamp_ms   BIGINT,
  visitor_id     BIGINT,
  event_type     TEXT,
  item_id        BIGINT,
  transaction_id BIGINT
);

CREATE TABLE IF NOT EXISTS raw_rr_item_properties (
  timestamp_ms BIGINT,
  item_id      BIGINT,
  property     TEXT,
  value        TEXT
);

CREATE TABLE IF NOT EXISTS raw_rr_category_tree (
  category_id BIGINT,
  parent_id   BIGINT
);

CREATE TABLE IF NOT EXISTS stg_rr_events (
  event_ts       TIMESTAMP,
  event_date     DATE,
  visitor_id     BIGINT,
  item_id        BIGINT,
  event_type     TEXT,
  transaction_id BIGINT
);

CREATE TABLE IF NOT EXISTS stg_rr_item_snapshot (
  item_id     BIGINT,
  category_id BIGINT,
  available   INTEGER
);

CREATE TABLE IF NOT EXISTS stg_rr_category_dim (
  category_id      BIGINT,
  parent_id        BIGINT,
  depth            INTEGER,
  root_category_id BIGINT,
  path             TEXT
);

CREATE TABLE IF NOT EXISTS dim_rr_category (
  category_id      BIGINT,
  parent_id        BIGINT,
  depth            INTEGER,
  root_category_id BIGINT,
  path             TEXT
);

CREATE TABLE IF NOT EXISTS dim_rr_item (
  item_id     BIGINT,
  category_id BIGINT,
  available   INTEGER
);

CREATE TABLE IF NOT EXISTS dim_rr_visitor (
  visitor_id          BIGINT,
  first_event_ts      TIMESTAMP,
  first_purchase_ts   TIMESTAMP,
  first_purchase_date DATE
);

CREATE TABLE IF NOT EXISTS fact_rr_events (
  event_ts       TIMESTAMP,
  event_date     DATE,
  visitor_id     BIGINT,
  session_id     TEXT,
  item_id        BIGINT,
  event_type     TEXT,
  transaction_id BIGINT
);

CREATE TABLE IF NOT EXISTS fact_rr_sessions (
  session_date       DATE,
  visitor_id         BIGINT,
  session_id         TEXT,
  session_start_ts   TIMESTAMP,
  session_end_ts     TIMESTAMP,
  views_cnt          INTEGER,
  carts_cnt          INTEGER,
  purchases_cnt      INTEGER,
  has_view           INTEGER,
  has_cart           INTEGER,
  has_purchase       INTEGER
);

CREATE TABLE IF NOT EXISTS mart_rr_funnel_daily (
  kpi_date                DATE PRIMARY KEY,
  visitors                INTEGER,
  sessions                INTEGER,
  views                   INTEGER,
  addtocarts              INTEGER,
  purchases               INTEGER,
  sessions_with_view      INTEGER,
  sessions_with_cart      INTEGER,
  sessions_with_purchase  INTEGER,
  cvr_session_to_purchase NUMERIC(10, 4),
  cvr_view_to_cart        NUMERIC(10, 4),
  cvr_cart_to_purchase    NUMERIC(10, 4)
);

CREATE TABLE IF NOT EXISTS mart_rr_funnel_category_daily (
  kpi_date             DATE,
  root_category_id     BIGINT,
  views                INTEGER,
  addtocarts           INTEGER,
  purchase_events      INTEGER,
  cvr_view_to_cart     NUMERIC(10, 4),
  cvr_cart_to_purchase NUMERIC(10, 4),
  PRIMARY KEY (kpi_date, root_category_id)
);

CREATE TABLE IF NOT EXISTS mart_rr_cohort_weekly (
  cohort_week     DATE,
  week_index      INTEGER,
  cohort_size     INTEGER,
  active_visitors INTEGER,
  retention_rate  NUMERIC(10, 4),
  PRIMARY KEY (cohort_week, week_index)
);

CREATE TABLE IF NOT EXISTS mart_rr_crm_targets_daily (
  kpi_date     DATE,
  visitor_id   BIGINT,
  segment_name TEXT,
  evidence     TEXT,
  PRIMARY KEY (kpi_date, visitor_id, segment_name)
);

CREATE TABLE IF NOT EXISTS quality_check_runs (
  id BIGSERIAL PRIMARY KEY,
  checked_at TIMESTAMP NOT NULL DEFAULT NOW(),
  dag_run_id TEXT,
  target_date DATE NOT NULL,
  check_name TEXT NOT NULL,
  status TEXT NOT NULL,
  result_row_count INTEGER NOT NULL,
  sample_rows TEXT
);
