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
      SELECT kpi_date, visitor_id, segment_name, evidence
      FROM mart_rr_crm_targets_daily
      WHERE kpi_date = %s
      ORDER BY segment_name, visitor_id
    """

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, (args.target_date,))
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description]

    if not rows:
        raise SystemExit(f"No rows found in mart_rr_crm_targets_daily for target_date={args.target_date}")

    with output_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)

    print(f"Exported {len(rows)} row(s) to {output_path}")


if __name__ == "__main__":
    main()
