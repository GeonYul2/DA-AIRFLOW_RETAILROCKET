#!/usr/bin/env python
import argparse
import csv
from pathlib import Path

from scripts.utils.db import get_connection


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-path", required=True)
    args = parser.parse_args()

    output_path = Path(args.output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    query = """
      SELECT cohort_week, week_index, cohort_size, active_visitors, retention_rate
      FROM mart_rr_cohort_weekly
      ORDER BY cohort_week, week_index
    """

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query)
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description]

    if not rows:
        raise SystemExit("No rows found in mart_rr_cohort_weekly (did you run 003_mart_rr_cohort_weekly.sql?)")

    with output_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)

    print(f"Exported {len(rows)} row(s) to {output_path}")


if __name__ == "__main__":
    main()
