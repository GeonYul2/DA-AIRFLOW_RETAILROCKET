#!/usr/bin/env python
import argparse
import csv
import time
from pathlib import Path
from typing import Iterable, List, Optional, Set, Tuple

from scripts.utils.db import get_connection


def _batched(iterable: Iterable[Tuple], batch_size: int) -> Iterable[List[Tuple]]:
    batch: List[Tuple] = []
    for item in iterable:
        batch.append(item)
        if len(batch) >= batch_size:
            yield batch
            batch = []
    if batch:
        yield batch


def _parse_int(x: Optional[str]) -> Optional[int]:
    if x is None:
        return None
    x = x.strip()
    if x == "":
        return None
    return int(x)


def _read_events_rows(events_path: Path, limit: int) -> Tuple[Iterable[Tuple], Set[int]]:
    item_ids: Set[int] = set()

    def gen():
        with events_path.open("r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            required = {"timestamp", "visitorid", "event", "itemid", "transactionid"}
            if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
                raise ValueError(f"Unexpected header in {events_path}. got={reader.fieldnames}")

            count = 0
            for row in reader:
                ts = _parse_int(row.get("timestamp"))
                visitor = _parse_int(row.get("visitorid"))
                event_type = (row.get("event") or "").strip()
                item = _parse_int(row.get("itemid"))
                tx = _parse_int(row.get("transactionid"))

                if item is not None:
                    item_ids.add(item)

                yield (ts, visitor, event_type, item, tx)

                count += 1
                if limit > 0 and count >= limit:
                    break

    return gen(), item_ids


def _read_category_rows(path: Path) -> Iterable[Tuple]:
    def gen():
        with path.open("r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            required = {"categoryid", "parentid"}
            if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
                raise ValueError(f"Unexpected header in {path}. got={reader.fieldnames}")

            for row in reader:
                cat = _parse_int(row.get("categoryid"))
                parent = _parse_int(row.get("parentid"))
                yield (cat, parent)

    return gen()


def _read_properties_rows(
    paths: List[Path],
    allowed_properties: Set[str],
    limit: int,
    filter_item_ids: Optional[Set[int]],
) -> Iterable[Tuple]:
    def gen():
        count = 0
        for path in paths:
            with path.open("r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                required = {"timestamp", "itemid", "property", "value"}
                if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
                    raise ValueError(f"Unexpected header in {path}. got={reader.fieldnames}")

                for row in reader:
                    prop = (row.get("property") or "").strip()
                    if prop not in allowed_properties:
                        continue

                    item = _parse_int(row.get("itemid"))
                    if item is None:
                        continue
                    if filter_item_ids is not None and item not in filter_item_ids:
                        continue

                    ts = _parse_int(row.get("timestamp"))
                    value = row.get("value")
                    if value is not None:
                        value = value.strip()

                    yield (ts, item, prop, value)

                    count += 1
                    if limit > 0 and count >= limit:
                        return

    return gen()


def _insert_many(cur, sql: str, rows: Iterable[Tuple], batch_size: int, label: str) -> int:
    total = 0
    for batch in _batched(rows, batch_size):
        cur.executemany(sql, batch)
        total += len(batch)
        if total % (batch_size * 10) == 0:
            print(f"[LOAD] {label}: inserted={total}")
    print(f"[LOAD] {label}: inserted_total={total}")
    return total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", default="data/raw/retailrocket")
    parser.add_argument("--events-limit", type=int, default=300_000, help="0 = load all events")
    parser.add_argument("--batch-size", type=int, default=5000)
    parser.add_argument("--skip-item-properties", action="store_true")
    parser.add_argument("--properties", default="categoryid,available")
    parser.add_argument("--properties-limit", type=int, default=2_000_000, help="0 = load all filtered properties")
    parser.add_argument("--filter-properties-by-event-items", action="store_true")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    events_path = data_dir / "events.csv"
    cat_path = data_dir / "category_tree.csv"
    prop1 = data_dir / "item_properties_part1.csv"
    prop2 = data_dir / "item_properties_part2.csv"

    for p in [events_path, cat_path]:
        if not p.exists():
            raise FileNotFoundError(f"Missing file: {p}")

    prop_paths = [p for p in [prop1, prop2] if p.exists()]

    started = time.time()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE raw_rr_events")
            cur.execute("TRUNCATE TABLE raw_rr_category_tree")
            cur.execute("TRUNCATE TABLE raw_rr_item_properties")

            event_rows_iter, item_ids = _read_events_rows(events_path, args.events_limit)
            sql_events = """
                INSERT INTO raw_rr_events (timestamp_ms, visitor_id, event_type, item_id, transaction_id)
                VALUES (%s, %s, %s, %s, %s)
            """
            _insert_many(cur, sql_events, event_rows_iter, args.batch_size, "raw_rr_events")

            sql_cat = """
                INSERT INTO raw_rr_category_tree (category_id, parent_id)
                VALUES (%s, %s)
            """
            _insert_many(cur, sql_cat, _read_category_rows(cat_path), args.batch_size, "raw_rr_category_tree")

            if args.skip_item_properties:
                print("[LOAD] skipping raw_rr_item_properties (skip-item-properties enabled)")
            else:
                if not prop_paths:
                    print("[LOAD] item_properties_part*.csv not found; skipping raw_rr_item_properties")
                else:
                    allowed = {p.strip() for p in args.properties.split(",") if p.strip()}
                    filter_items = item_ids if args.filter_properties_by_event_items else None
                    prop_rows = _read_properties_rows(prop_paths, allowed, args.properties_limit, filter_items)
                    sql_prop = """
                        INSERT INTO raw_rr_item_properties (timestamp_ms, item_id, property, value)
                        VALUES (%s, %s, %s, %s)
                    """
                    _insert_many(cur, sql_prop, prop_rows, args.batch_size, "raw_rr_item_properties")

            for t in ["raw_rr_events", "raw_rr_category_tree", "raw_rr_item_properties"]:
                cur.execute(f"SELECT COUNT(*) FROM {t}")
                print(f"{t}: {cur.fetchone()[0]} rows")

        conn.commit()

    elapsed = time.time() - started
    print(f"RetailRocket raw load completed in {elapsed:.2f}s")


if __name__ == "__main__":
    main()
