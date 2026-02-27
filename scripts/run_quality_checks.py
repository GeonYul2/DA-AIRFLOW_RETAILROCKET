#!/usr/bin/env python
import argparse
import json
import os
from datetime import datetime
from pathlib import Path

from scripts.utils.db import get_connection, render_sql


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-date", required=True)
    parser.add_argument("--dir", default="sql/90_quality")
    parser.add_argument("--run-id")
    args = parser.parse_args()

    run_id = args.run_id or os.getenv("AIRFLOW_CTX_DAG_RUN_ID") or f"manual_{datetime.utcnow().isoformat()}"
    variables = {"target_date": args.target_date}
    sql_files = sorted(Path(args.dir).glob("*.sql"))

    if not sql_files:
        raise SystemExit(f"No SQL files found in {args.dir}")

    failures = []
    logs = []

    with get_connection() as conn:
        with conn.cursor() as cur:
            for sql_file in sql_files:
                sql = render_sql(sql_file.read_text(encoding="utf-8"), variables)
                cur.execute(sql)
                rows = cur.fetchall()
                status = "FAIL" if rows else "PASS"
                sample = json.dumps(rows[:10], default=str, ensure_ascii=False) if rows else None
                logs.append((run_id, args.target_date, sql_file.name, status, len(rows), sample))

                if rows:
                    failures.append((sql_file.name, rows[:10]))
                print(f"[CHECK] {sql_file.name}: {status}")

            cur.executemany(
                """
                INSERT INTO quality_check_runs (
                    dag_run_id,
                    target_date,
                    check_name,
                    status,
                    result_row_count,
                    sample_rows
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                logs,
            )
        conn.commit()

    if failures:
        for name, rows in failures:
            print(f"\n{name} failed:")
            for row in rows:
                print(f"  {row}")
        raise SystemExit(1)

    print("All quality checks passed")


if __name__ == "__main__":
    main()
