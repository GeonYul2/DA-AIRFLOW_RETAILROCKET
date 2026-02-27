#!/usr/bin/env python
import argparse
import time
from pathlib import Path

from scripts.utils.db import get_connection, list_sql_files, render_sql


def split_sql_statements(sql: str) -> list[str]:
    return [stmt.strip() for stmt in sql.split(";") if stmt.strip()]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir")
    parser.add_argument("--file")
    parser.add_argument("--target-date", dest="target_date")
    args = parser.parse_args()

    if bool(args.dir) == bool(args.file):
        raise SystemExit("Provide exactly one of --dir or --file")

    variables = {}
    if args.target_date:
        variables["target_date"] = args.target_date

    if args.file:
        sql_files = [Path(args.file)]
        if not sql_files[0].exists():
            raise SystemExit(f"SQL file not found: {sql_files[0]}")
    else:
        sql_files = list(list_sql_files(args.dir))

    if not sql_files:
        raise SystemExit(f"No SQL files found in {args.dir}")

    started = time.time()
    with get_connection() as conn:
        with conn.cursor() as cur:
            for sql_file in sql_files:
                sql = sql_file.read_text(encoding="utf-8")
                rendered_sql = render_sql(sql, variables)
                for statement in split_sql_statements(rendered_sql):
                    cur.execute(statement)
                print(f"[OK] {sql_file}")
        conn.commit()

    elapsed = time.time() - started
    print(f"Completed {len(sql_files)} files in {elapsed:.2f}s")


if __name__ == "__main__":
    main()
