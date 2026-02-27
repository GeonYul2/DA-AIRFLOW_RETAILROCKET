#!/usr/bin/env python
import argparse
from pathlib import Path

from scripts.utils.db import get_connection


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-date", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--output-path", required=True)
    args = parser.parse_args()

    output_path = Path(args.output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT kpi_date, visitors, sessions, views, addtocarts, purchases,
                       cvr_session_to_purchase, cvr_view_to_cart, cvr_cart_to_purchase
                FROM mart_rr_funnel_daily
                WHERE kpi_date = %s
                """,
                (args.target_date,),
            )
            daily_row = cur.fetchone()

            cur.execute(
                """
                SELECT check_name, status, result_row_count
                FROM quality_check_runs
                WHERE dag_run_id = %s AND target_date = %s
                ORDER BY id
                """,
                (args.run_id, args.target_date),
            )
            checks = cur.fetchall()

    if not daily_row:
        raise SystemExit(f"No mart_rr_funnel_daily row for target_date={args.target_date}")

    summary_lines = [
        f"run_id={args.run_id}",
        f"target_date={args.target_date}",
        "",
        "[rr_funnel_daily]",
        f"kpi_date={daily_row[0]}",
        f"visitors={daily_row[1]}",
        f"sessions={daily_row[2]}",
        f"views={daily_row[3]}",
        f"addtocarts={daily_row[4]}",
        f"purchases={daily_row[5]}",
        f"cvr_session_to_purchase={daily_row[6]}",
        f"cvr_view_to_cart={daily_row[7]}",
        f"cvr_cart_to_purchase={daily_row[8]}",
        "",
        "[quality_checks]",
    ]

    if not checks:
        summary_lines.append("no_quality_records_found=true")
    else:
        for name, status, cnt in checks:
            summary_lines.append(f"{name}={status} (rows={cnt})")

    output_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    print(f"RR pipeline summary written to {output_path}")


if __name__ == "__main__":
    main()
