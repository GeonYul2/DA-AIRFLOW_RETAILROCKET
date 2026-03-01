from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import median


def utc_date_from_ms(ts_ms: str) -> str:
    ts = int(ts_ms)
    return datetime.fromtimestamp(ts / 1000, tz=timezone.utc).date().isoformat()


def profile_events(events_path: Path) -> dict:
    event_counts = Counter()
    daily_counts = defaultdict(int)
    visitors = set()
    items = set()

    total_rows = 0
    tx_non_null = 0
    tx_null_on_transaction = 0
    min_ts = None
    max_ts = None

    with events_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            total_rows += 1
            event = (row.get("event") or "").strip().lower()
            event_counts[event] += 1

            ts_raw = row.get("timestamp") or "0"
            ts = int(ts_raw)
            if min_ts is None or ts < min_ts:
                min_ts = ts
            if max_ts is None or ts > max_ts:
                max_ts = ts

            day = utc_date_from_ms(ts_raw)
            daily_counts[day] += 1

            visitor_id = row.get("visitorid")
            item_id = row.get("itemid")
            if visitor_id:
                visitors.add(visitor_id)
            if item_id:
                items.add(item_id)

            tx = (row.get("transactionid") or "").strip()
            if tx:
                tx_non_null += 1
            if event == "transaction" and not tx:
                tx_null_on_transaction += 1

    sorted_days = sorted(daily_counts.items(), key=lambda x: x[0])
    min_day, min_day_events = min(sorted_days, key=lambda x: x[1])
    max_day, max_day_events = max(sorted_days, key=lambda x: x[1])

    return {
        "total_rows": total_rows,
        "unique_visitors": len(visitors),
        "unique_items": len(items),
        "event_counts": dict(event_counts),
        "tx_non_null": tx_non_null,
        "tx_null_on_transaction": tx_null_on_transaction,
        "start_date_utc": utc_date_from_ms(str(min_ts)) if min_ts is not None else None,
        "end_date_utc": utc_date_from_ms(str(max_ts)) if max_ts is not None else None,
        "active_days": len(sorted_days),
        "daily_min": {"date": min_day, "events": min_day_events},
        "daily_max": {"date": max_day, "events": max_day_events},
        "daily_median": int(median([v for _, v in sorted_days])) if sorted_days else 0,
    }


def profile_category_tree(category_path: Path) -> dict:
    parent_by_node = {}
    children = defaultdict(set)

    with category_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cid = (row.get("categoryid") or "").strip()
            pid = (row.get("parentid") or "").strip()
            if not cid:
                continue
            parent_by_node[cid] = pid
            if pid:
                children[pid].add(cid)

    all_nodes = set(parent_by_node.keys())
    roots = [cid for cid, pid in parent_by_node.items() if not pid]
    leaves = [cid for cid in all_nodes if cid not in children]

    return {
        "nodes": len(all_nodes),
        "roots": len(roots),
        "leaves": len(leaves),
    }


def fmt_int(v: int) -> str:
    return f"{v:,}"


def build_markdown(events: dict, category: dict, output_path: Path) -> str:
    views = events["event_counts"].get("view", 0)
    carts = events["event_counts"].get("addtocart", 0)
    txs = events["event_counts"].get("transaction", 0)

    cart_per_view = (carts / views) if views else 0
    tx_per_cart = (txs / carts) if carts else 0

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    return f"""# RetailRocket Dataset EDA (요약)

> 생성 시각: {generated_at}  
> 생성 스크립트: `python3 scripts/profile_retailrocket_eda.py`

## 왜 이 요약이 필요한가
- 퍼널 분석 전, 데이터의 기본 구조(이벤트 타입/기간/규모)를 먼저 확인합니다.
- 카테고리 트리 구조(노드/루트/리프)를 확인해 카테고리 단위 지표 해석 가능성을 점검합니다.

## 1) Events 기본 통계 (`events.csv`)

| 항목 | 값 |
|---|---:|
| 전체 이벤트 행 수 | {fmt_int(events['total_rows'])} |
| 고유 방문자 수 | {fmt_int(events['unique_visitors'])} |
| 고유 아이템 수 | {fmt_int(events['unique_items'])} |
| 기간(UTC date) | {events['start_date_utc']} ~ {events['end_date_utc']} |
| 활성 일수 | {fmt_int(events['active_days'])} |
| 일별 이벤트 중앙값 | {fmt_int(events['daily_median'])} |
| 최소 일별 이벤트 | {events['daily_min']['date']} ({fmt_int(events['daily_min']['events'])}) |
| 최대 일별 이벤트 | {events['daily_max']['date']} ({fmt_int(events['daily_max']['events'])}) |

### 이벤트 타입 분포

| event | count | share |
|---|---:|---:|
| view | {fmt_int(views)} | {(views / events['total_rows'] * 100):.2f}% |
| addtocart | {fmt_int(carts)} | {(carts / events['total_rows'] * 100):.2f}% |
| transaction | {fmt_int(txs)} | {(txs / events['total_rows'] * 100):.2f}% |

### 퍼널 관찰값 (이벤트 비율 기준)
- addtocart / view = **{cart_per_view:.4f}**
- transaction / addtocart = **{tx_per_cart:.4f}**
- transaction 이벤트 중 `transaction_id` 누락 건수 = **{fmt_int(events['tx_null_on_transaction'])}**

> 주의: 위 비율은 "세션 전환율"이 아니라 이벤트 수 기준입니다.  
> 세션 기반 CVR은 `fact_rr_sessions`와 `mart_rr_funnel_daily`에서 계산합니다.

## 2) Category Tree 기본 통계 (`category_tree.csv`)

| 항목 | 값 |
|---|---:|
| 카테고리 노드 수 | {fmt_int(category['nodes'])} |
| 루트 카테고리 수(`parentid` 비어있음) | {fmt_int(category['roots'])} |
| 리프 카테고리 수(자식 없음) | {fmt_int(category['leaves'])} |

## 3) EDA 결과를 모델링에 연결한 방식
- 퍼널 단계는 원천 이벤트의 `view → addtocart → transaction` 구조를 그대로 사용했습니다.
- 카테고리 분석은 트리 구조를 평탄화한 `stg_rr_category_dim`과 `dim_rr_category`를 사용합니다.
- 전환율은 세션화 후 KPI 테이블에서 계산해 정의 불일치를 줄였습니다.
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="RetailRocket dataset EDA summary")
    parser.add_argument("--data-dir", default="data/raw/retailrocket", help="Path to raw dataset directory")
    parser.add_argument("--output", default="docs/retailrocket_eda.md", help="Output markdown path")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    events_path = data_dir / "events.csv"
    category_path = data_dir / "category_tree.csv"
    output_path = Path(args.output)

    if not events_path.exists():
        raise FileNotFoundError(f"events.csv not found: {events_path}")
    if not category_path.exists():
        raise FileNotFoundError(f"category_tree.csv not found: {category_path}")

    events_stats = profile_events(events_path)
    category_stats = profile_category_tree(category_path)

    markdown = build_markdown(events_stats, category_stats, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding="utf-8")

    print(f"Wrote: {output_path}")


if __name__ == "__main__":
    main()
