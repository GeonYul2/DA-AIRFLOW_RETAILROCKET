#!/usr/bin/env python
import argparse
from datetime import datetime, timedelta, timezone
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", default="data/raw")
    parser.add_argument("--max-age-hours", type=int, default=168)
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    if not data_dir.exists():
        raise SystemExit(f"Data directory not found: {data_dir}")

    files = [p for p in data_dir.rglob("*.csv") if p.is_file()]
    if not files:
        raise SystemExit(f"No CSV files found in {data_dir}")

    latest_file = max(files, key=lambda p: p.stat().st_mtime)
    latest_mtime = datetime.fromtimestamp(latest_file.stat().st_mtime, tz=timezone.utc)
    cutoff = datetime.now(timezone.utc) - timedelta(hours=args.max_age_hours)

    print(f"latest_csv={latest_file}")
    print(f"latest_mtime_utc={latest_mtime.isoformat()}")
    print(f"cutoff_utc={cutoff.isoformat()}")

    if latest_mtime < cutoff:
        raise SystemExit(
            f"Raw data is stale: latest_mtime={latest_mtime.isoformat()} < cutoff={cutoff.isoformat()}"
        )

    print("Raw freshness check passed")


if __name__ == "__main__":
    main()
