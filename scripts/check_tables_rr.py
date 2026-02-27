#!/usr/bin/env python
from scripts.utils.db import get_connection, get_db_type

REQUIRED_TABLES = [
    "raw_rr_events",
    "raw_rr_item_properties",
    "raw_rr_category_tree",
    "stg_rr_events",
    "stg_rr_item_snapshot",
    "stg_rr_category_dim",
    "dim_rr_category",
    "dim_rr_item",
    "dim_rr_visitor",
    "fact_rr_events",
    "fact_rr_sessions",
    "mart_rr_funnel_daily",
    "mart_rr_funnel_category_daily",
    "mart_rr_cohort_weekly",
    "mart_rr_crm_targets_daily",
    "quality_check_runs",
]


def main():
    db_type = get_db_type()
    with get_connection() as conn:
        with conn.cursor() as cur:
            if db_type == "postgres":
                cur.execute(
                    """
                    SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                    """
                )
            else:
                cur.execute(
                    """
                    SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = DATABASE()
                    """
                )
            existing = {row[0] for row in cur.fetchall()}

    missing = [t for t in REQUIRED_TABLES if t not in existing]
    if missing:
        print("Missing RR tables:")
        for t in missing:
            print(f" - {t}")
        raise SystemExit(1)

    print("All RR required tables exist")


if __name__ == "__main__":
    main()
