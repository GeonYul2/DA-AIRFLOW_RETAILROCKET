-- RetailRocket track (MySQL/MariaDB)

CREATE TABLE IF NOT EXISTS raw_rr_events (
  timestamp_ms   BIGINT,
  visitor_id     BIGINT,
  event_type     VARCHAR(64),
  item_id        BIGINT,
  transaction_id BIGINT
);

CREATE TABLE IF NOT EXISTS raw_rr_item_properties (
  timestamp_ms BIGINT,
  item_id      BIGINT,
  property     VARCHAR(128),
  value        VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS raw_rr_category_tree (
  category_id BIGINT,
  parent_id   BIGINT
);

CREATE TABLE IF NOT EXISTS stg_rr_events (
  event_ts       DATETIME,
  event_date     DATE,
  visitor_id     BIGINT,
  item_id        BIGINT,
  event_type     VARCHAR(64),
  transaction_id BIGINT
);

CREATE TABLE IF NOT EXISTS stg_rr_item_snapshot (
  item_id     BIGINT,
  category_id BIGINT,
  available   INT
);

CREATE TABLE IF NOT EXISTS stg_rr_category_dim (
  category_id      BIGINT,
  parent_id        BIGINT,
  depth            INT,
  root_category_id BIGINT,
  path             VARCHAR(1024)
);

CREATE TABLE IF NOT EXISTS dim_rr_category (
  category_id      BIGINT,
  parent_id        BIGINT,
  depth            INT,
  root_category_id BIGINT,
  path             VARCHAR(1024)
);

CREATE TABLE IF NOT EXISTS dim_rr_item (
  item_id     BIGINT,
  category_id BIGINT,
  available   INT
);

CREATE TABLE IF NOT EXISTS dim_rr_visitor (
  visitor_id          BIGINT,
  first_event_ts      DATETIME,
  first_purchase_ts   DATETIME,
  first_purchase_date DATE
);

CREATE TABLE IF NOT EXISTS fact_rr_events (
  event_ts       DATETIME,
  event_date     DATE,
  visitor_id     BIGINT,
  session_id     VARCHAR(64),
  item_id        BIGINT,
  event_type     VARCHAR(64),
  transaction_id BIGINT
);

CREATE TABLE IF NOT EXISTS fact_rr_sessions (
  session_date      DATE,
  visitor_id        BIGINT,
  session_id        VARCHAR(64),
  session_start_ts  DATETIME,
  session_end_ts    DATETIME,
  views_cnt         INT,
  carts_cnt         INT,
  purchases_cnt     INT,
  has_view          TINYINT,
  has_cart          TINYINT,
  has_purchase      TINYINT
);

CREATE TABLE IF NOT EXISTS mart_rr_funnel_daily (
  kpi_date                DATE PRIMARY KEY,
  visitors                INT,
  sessions                INT,
  views                   INT,
  addtocarts              INT,
  purchases               INT,
  sessions_with_view      INT,
  sessions_with_cart      INT,
  sessions_with_purchase  INT,
  cvr_session_to_purchase DECIMAL(10, 4),
  cvr_view_to_cart        DECIMAL(10, 4),
  cvr_cart_to_purchase    DECIMAL(10, 4)
);

CREATE TABLE IF NOT EXISTS mart_rr_funnel_category_daily (
  kpi_date             DATE,
  root_category_id     BIGINT,
  views                INT,
  addtocarts           INT,
  purchase_events      INT,
  cvr_view_to_cart     DECIMAL(10, 4),
  cvr_cart_to_purchase DECIMAL(10, 4),
  PRIMARY KEY (kpi_date, root_category_id)
);

CREATE TABLE IF NOT EXISTS mart_rr_cohort_weekly (
  cohort_week     DATE,
  week_index      INT,
  cohort_size     INT,
  active_visitors INT,
  retention_rate  DECIMAL(10, 4),
  PRIMARY KEY (cohort_week, week_index)
);

CREATE TABLE IF NOT EXISTS mart_rr_crm_targets_daily (
  kpi_date     DATE,
  visitor_id   BIGINT,
  segment_name VARCHAR(128),
  evidence     TEXT,
  PRIMARY KEY (kpi_date, visitor_id, segment_name)
);

CREATE TABLE IF NOT EXISTS quality_check_runs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  checked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  dag_run_id VARCHAR(255),
  target_date DATE NOT NULL,
  check_name VARCHAR(255) NOT NULL,
  status VARCHAR(16) NOT NULL,
  result_row_count INT NOT NULL,
  sample_rows LONGTEXT
);
