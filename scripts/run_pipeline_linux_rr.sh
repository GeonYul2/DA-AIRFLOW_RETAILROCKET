#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TARGET_DATE="$(
python3 - <<'PY'
import csv
from datetime import datetime, timezone
from pathlib import Path

p = Path("data/raw/retailrocket/events.csv")
if not p.exists():
    print(datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    raise SystemExit(0)

max_ts = None
with p.open("r", encoding="utf-8") as f:
    r = csv.DictReader(f)
    for row in r:
        ts = row.get("timestamp")
        if not ts:
            continue
        try:
            v = int(ts)
        except Exception:
            continue
        if max_ts is None or v > max_ts:
            max_ts = v

if max_ts is None:
    print(datetime.now(timezone.utc).strftime("%Y-%m-%d"))
else:
    dt = datetime.fromtimestamp(max_ts / 1000.0, tz=timezone.utc)
    print(dt.strftime("%Y-%m-%d"))
PY
)"

TARGET_DATE="${1:-$DEFAULT_TARGET_DATE}"
REPORT_DIR="${2:-/opt/airflow/logs/reports}"
SQL_ROOT="${SQL_ROOT:-sql/retailrocket}"

echo "[RR PIPELINE] target_date=${TARGET_DATE}"
echo "[RR PIPELINE] report_dir=${REPORT_DIR}"
echo "[RR PIPELINE] sql_root=${SQL_ROOT}"

python -m scripts.check_raw_freshness --data-dir "data/raw/retailrocket" --max-age-hours "${RAW_FRESHNESS_MAX_HOURS:-168}"

python -m scripts.load_raw.load_retailrocket \
  --data-dir "data/raw/retailrocket" \
  --events-limit "${RR_EVENTS_LIMIT:-300000}" \
  --properties "${RR_PROPERTIES:-categoryid,available}" \
  --properties-limit "${RR_PROPERTIES_LIMIT:-2000000}" \
  --filter-properties-by-event-items

python -m scripts.run_sql_dir --dir "${SQL_ROOT}/10_staging"
python -m scripts.run_sql_dir --dir "${SQL_ROOT}/20_mart"
python -m scripts.run_sql_dir --dir "${SQL_ROOT}/30_kpi" --target-date "${TARGET_DATE}"

python -m scripts.run_quality_checks \
  --target-date "${TARGET_DATE}" \
  --dir "${SQL_ROOT}/90_quality" \
  --run-id "linux_rr_${TARGET_DATE}"

python -m scripts.export_rr_funnel_csv \
  --target-date "${TARGET_DATE}" \
  --output-path "${REPORT_DIR}/rr_funnel_daily_${TARGET_DATE}.csv"

python -m scripts.export_rr_cohort_csv \
  --output-path "${REPORT_DIR}/rr_cohort_weekly_${TARGET_DATE}.csv"

python -m scripts.export_rr_crm_targets_csv \
  --target-date "${TARGET_DATE}" \
  --output-path "${REPORT_DIR}/rr_crm_targets_${TARGET_DATE}.csv"

python -m scripts.write_rr_pipeline_summary \
  --target-date "${TARGET_DATE}" \
  --run-id "linux_rr_${TARGET_DATE}" \
  --output-path "${REPORT_DIR}/rr_pipeline_summary_${TARGET_DATE}.txt"

echo "[RR PIPELINE] completed"
