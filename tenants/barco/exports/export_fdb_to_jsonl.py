#!/usr/bin/env python3
"""Export all user tables from a Firebird .FDB to JSONL (+ _meta.json)."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

CONTAINER = "fb-barco-export"
IMAGE = "jacobalberty/firebird:2.5-sc"
DATA_DIR = Path("/tmp/barco-fb-export")
DB_IN_CONTAINER = "/firebird/data/PDVDATA.FDB"


def json_default(o):
    if isinstance(o, datetime):
        return o.isoformat(sep="T", timespec="seconds")
    if isinstance(o, date):
        return o.isoformat()
    if isinstance(o, Decimal):
        return float(o)
    if isinstance(o, (bytes, bytearray, memoryview)):
        raw = bytes(o)
        for enc in ("utf-8", "cp1252", "latin-1"):
            try:
                return raw.decode(enc)
            except UnicodeDecodeError:
                continue
        return raw.hex()
    return str(o)


def sanitize_value(v):
    """Normalize string-ish values that arrived with wrong decoding."""
    if isinstance(v, str):
        # If we got latin1-misread as something odd, keep as-is (already decoded by driver).
        return v
    if isinstance(v, (bytes, bytearray, memoryview)):
        return json_default(v)
    return v


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, capture_output=True, text=True)


def ensure_container(fdb_path: Path) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    dest = DATA_DIR / "PDVDATA.FDB"
    print(f"→ copy {fdb_path} → {dest}", flush=True)
    shutil.copy2(fdb_path, dest)
    dest.chmod(0o666)

    run(["docker", "rm", "-f", CONTAINER], check=False)
    print(f"→ start {CONTAINER}", flush=True)
    run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            CONTAINER,
            "-e",
            "ISC_PASSWORD=masterkey",
            "-e",
            "FIREBIRD_DATABASE=PDVDATA.FDB",
            "-v",
            f"{DATA_DIR}:/firebird/data",
            "-p",
            "3051:3050",
            IMAGE,
        ]
    )
    # Wait until wire protocol accepts connections
    import firebirdsql

    last_err: Exception | None = None
    for i in range(40):
        try:
            con = firebirdsql.connect(
                host="127.0.0.1",
                database=DB_IN_CONTAINER,
                port=3051,
                user="SYSDBA",
                password="masterkey",
                charset="WIN1252",
            )
            con.close()
            print(f"→ Firebird ready ({i + 1}s)", flush=True)
            return
        except Exception as e:
            last_err = e
            time.sleep(1)
    raise RuntimeError(f"Firebird did not become ready: {last_err}")


def connect():
    import firebirdsql

    # Chilean PDV DBs are typically WIN1252 / ISO8859_1, not UTF8.
    last: Exception | None = None
    for charset in ("WIN1252", "ISO8859_1", "NONE", "UTF8"):
        try:
            return firebirdsql.connect(
                host="127.0.0.1",
                database=DB_IN_CONTAINER,
                port=3051,
                user="SYSDBA",
                password="masterkey",
                charset=charset,
            )
        except Exception as e:
            last = e
    raise RuntimeError(f"connect failed: {last}")


def list_tables(con) -> list[str]:
    cur = con.cursor()
    cur.execute(
        """
        SELECT TRIM(rdb$relation_name)
        FROM rdb$relations
        WHERE COALESCE(rdb$system_flag, 0) = 0
          AND rdb$view_blr IS NULL
        ORDER BY 1
        """
    )
    return [r[0] for r in cur.fetchall()]


def export_table(con, table: str, out_path: Path) -> int:
    cur = con.cursor()
    cur.execute(f"SELECT * FROM {table}")
    cols = [d[0].strip() if isinstance(d[0], str) else str(d[0]) for d in cur.description]
    count = 0
    with out_path.open("w", encoding="utf-8") as f:
        while True:
            rows = cur.fetchmany(1000)
            if not rows:
                break
            for row in rows:
                obj = {cols[i]: sanitize_value(row[i]) for i in range(len(cols))}
                f.write(json.dumps(obj, ensure_ascii=False, default=json_default))
                f.write("\n")
                count += 1
    return count


def export_db(source_fdb: Path, out_dir: Path) -> None:
    tables_dir = out_dir / "tables"
    if tables_dir.exists():
        shutil.rmtree(tables_dir)
    tables_dir.mkdir(parents=True, exist_ok=True)
    ensure_container(source_fdb)
    con = connect()
    charset = getattr(con, "charset", None)
    print(f"→ charset={charset}", flush=True)
    counts: dict[str, int] = {}
    tables: list[str] = []
    try:
        tables = list_tables(con)
        print(f"→ {len(tables)} tables → {out_dir}", flush=True)
        for t in tables:
            path = tables_dir / f"{t}.jsonl"
            try:
                n = export_table(con, t, path)
            except Exception as e:
                # reconnect after protocol errors and retry once
                print(f"  ! {t} retry after {type(e).__name__}: {e}", flush=True)
                try:
                    con.close()
                except Exception:
                    pass
                con = connect()
                n = export_table(con, t, path)
            counts[t] = n
            print(f"  {t}: {n}", flush=True)
        meta = {
            "source": str(source_fdb.resolve()),
            "sourceName": source_fdb.name,
            "exportedAt": datetime.now().isoformat(timespec="seconds"),
            "format": "jsonl",
            "firebird": {
                "image": IMAGE,
                "user": "SYSDBA",
                "charset": charset,
                "odsHint": "11.x (FB 2.5)",
            },
            "tableCount": len(tables),
            "rowCounts": counts,
            "totalRows": sum(counts.values()),
        }
        (out_dir / "_meta.json").write_text(
            json.dumps(meta, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"→ done {source_fdb.name}: {meta['totalRows']} rows", flush=True)
    finally:
        try:
            con.close()
        except Exception:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if not args.source.is_file():
        print(f"missing source: {args.source}", file=sys.stderr)
        return 1
    export_db(args.source, args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
