import os
from pathlib import Path
from typing import Dict, Iterable, Optional
from urllib.parse import parse_qs, unquote, urlparse

import psycopg2
import pymysql


DEFAULT_DSN = "postgresql://airflow:airflow@localhost:5432/warehouse"


def _resolve_dsn() -> str:
    return os.getenv("WAREHOUSE_DSN", DEFAULT_DSN)


def get_db_type() -> str:
    scheme = urlparse(_resolve_dsn()).scheme.lower()
    if scheme.startswith("postgres"):
        return "postgres"
    if scheme.startswith("mysql"):
        return "mysql"
    raise ValueError(f"Unsupported WAREHOUSE_DSN scheme: {scheme}")


def _mysql_connect_from_dsn(dsn: str):
    parsed = urlparse(dsn)
    query = parse_qs(parsed.query)
    return pymysql.connect(
        host=parsed.hostname or "localhost",
        port=parsed.port or 3306,
        user=unquote(parsed.username or ""),
        password=unquote(parsed.password or ""),
        database=(parsed.path or "/warehouse").lstrip("/"),
        charset=query.get("charset", ["utf8mb4"])[0],
        autocommit=False,
        cursorclass=pymysql.cursors.Cursor,
    )


def get_connection():
    dsn = _resolve_dsn()
    db_type = get_db_type()
    if db_type == "postgres":
        return psycopg2.connect(dsn)
    if db_type == "mysql":
        return _mysql_connect_from_dsn(dsn)
    raise ValueError(f"Unsupported db_type: {db_type}")


def render_sql(sql: str, variables: Optional[Dict[str, str]] = None) -> str:
    rendered = sql
    for key, value in (variables or {}).items():
        rendered = rendered.replace(f"{{{{ {key} }}}}", value)
    return rendered


def list_sql_files(directory: str) -> Iterable[Path]:
    path = Path(directory)
    return sorted(path.glob("*.sql"))
