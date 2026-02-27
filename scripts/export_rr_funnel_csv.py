#!/usr/bin/env python
import argparse
import csv
from pathlib import Path

from scripts.utils.db import get_connection


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-date", required=True)
    parser.add_argument("--output-path", required=True)
    args = parser.parse_args()

    output_path = Path(args.output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    query = """
      SELECT
        kpi_date, visitors, sessions, views, addtocarts, purchases,
        sessions_with_view, sessions_with_cart, sessions_with_purchase,
        cvr_session_to_purchase, cvr_view_to_cart, cvr_cart_to_purchase
      FROM mart_rr_funnel_daily
      WHERE kpi_date = %s
    """

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, (args.target_date,))
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description]

    if not rows:
        raise SystemExit(f"No mart_rr_funnel_daily row found for target_date={args.target_date}")

    with output_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)

    print(f"Exported {len(rows)} row(s) to {output_path}")


if __name__ == "__main__":
    main()
