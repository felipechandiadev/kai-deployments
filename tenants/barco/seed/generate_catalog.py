#!/usr/bin/env python3
"""Genera catálogos JSON desde exports JSONL PDV (Barco / Ohlala).

Uso (desde tenants/barco):
  python3 seed/generate_catalog.py --all
  python3 seed/generate_catalog.py --export exports/PDVDATA-barco --out seed/data/catalog-store.json --brand "El Barco"
  python3 seed/generate_catalog.py --export exports/PDVDATA --out seed/data/catalog-food.json --brand "Ohlala"

Copia a ../kai/seeds/barco/data/ si existe el monorepo sibling.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

IVA = 1.19
BARCODE_RE = re.compile(r"^\d{8,14}$")
# Stock basura típico de PDV (sentinel ~1e8)
STOCK_OUTLIER_MAX = 1e7


def load_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def dept_name(dept_id, depts: dict[int, str]) -> str:
    if dept_id is None:
        return "Sin categoría"
    name = depts.get(int(dept_id))
    if not name or name.strip().startswith("-"):
        return "Sin categoría"
    return name.strip()


def unique_name(raw: str, sku: str, used: set[str]) -> str:
    base = " ".join((raw or "").split()).strip() or f"Producto {sku}"
    if base not in used:
        used.add(base)
        return base
    candidate = f"{base} ({sku})"
    used.add(candidate)
    return candidate


def map_unit(tventa: str | None) -> str:
    """TVENTA: U=unidad, D=decimal/peso → KG; también P/W/KG/G/L/ML."""
    t = (tventa or "U").strip().upper()
    if t in {"D", "P", "W", "KG"}:
        return "KG"
    if t == "G":
        return "G"
    if t == "L":
        return "L"
    if t == "ML":
        return "ML"
    return "UN"


def sanitize_stock(raw: float) -> float:
    if raw < 0 or not (raw == raw):  # NaN
        return 0.0
    if raw >= STOCK_OUTLIER_MAX:
        return 0.0
    return float(raw)


def build_catalog(export_dir: Path, brand: str) -> dict:
    products_path = export_dir / "tables" / "PRODUCTOS.jsonl"
    depts_path = export_dir / "tables" / "DEPARTAMENTOS.jsonl"
    if not products_path.is_file():
        raise SystemExit(f"No existe {products_path}")

    depts: dict[int, str] = {}
    if depts_path.is_file():
        for row in load_jsonl(depts_path):
            depts[int(row["ID"])] = str(row.get("NOMBRE") or "")

    used_names: set[str] = set()
    products: list[dict] = []
    categories: set[str] = set()

    for row in load_jsonl(products_path):
        sku = str(row.get("CODIGO") or "").strip()
        if not sku:
            continue
        name = unique_name(str(row.get("DESCRIPCION") or ""), sku, used_names)
        cat = dept_name(row.get("DEPT"), depts)
        categories.add(cat)
        pventa = float(row.get("PVENTA") or 0)
        pcosto = float(row.get("PCOSTO") or 0)
        retail_net = round(pventa / IVA, 2) if pventa else 0.0
        barcode = sku if BARCODE_RE.match(sku) else None
        unit = map_unit(row.get("TVENTA"))
        products.append(
            {
                "name": name,
                "sku": sku,
                "barcode": barcode,
                "categoryName": cat,
                "productBaseUnit": unit,
                "baseCost": pcosto,
                "basePrice": pventa,
                "retailNet": retail_net,
                "trackInventory": True,
                "allowNegativeStock": False,
                "allowDecimals": unit != "UN",
                "initialStock": sanitize_stock(float(row.get("DINVENTARIO") or 0)),
                "tventa": str(row.get("TVENTA") or "U"),
            }
        )

    return {
        "source": f"{export_dir.name}/PRODUCTOS.jsonl",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S"),
        "ivaRate": 19,
        "brand": brand,
        "categories": sorted(categories),
        "products": products,
    }


def write_catalog(catalog: dict, out: Path, suite_data: Path | None) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    out.write_text(payload, encoding="utf-8")
    print(
        f"✅ {len(catalog['products'])} productos · "
        f"{len(catalog['categories'])} categorías · brand={catalog['brand']!r} → {out}"
    )
    if suite_data is not None and suite_data.parent.is_dir():
        suite_data.parent.mkdir(parents=True, exist_ok=True)
        suite_data.write_text(payload, encoding="utf-8")
        print(f"✅ Copia suite: {suite_data}")
    elif suite_data is not None:
        print(f"⚠️  No se copió a suite (no existe {suite_data.parent})")


def main() -> None:
    tenant_root = Path(__file__).resolve().parents[1]
    suite_data_dir = tenant_root.parents[2] / "kai" / "seeds" / "barco" / "data"

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--all",
        action="store_true",
        help="Genera catalog-store.json (PDVDATA-barco) + catalog-food.json (PDVDATA)",
    )
    parser.add_argument(
        "--export",
        type=Path,
        default=None,
        help="Directorio export JSONL (con tables/PRODUCTOS.jsonl)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Salida catalog JSON",
    )
    parser.add_argument(
        "--brand",
        type=str,
        default=None,
        help="Marca en el JSON (default: El Barco / Ohlala según export)",
    )
    args = parser.parse_args()

    jobs: list[tuple[Path, Path, str]] = []
    if args.all:
        jobs = [
            (
                tenant_root / "exports" / "PDVDATA-barco",
                tenant_root / "seed" / "data" / "catalog-store.json",
                "El Barco",
            ),
            (
                tenant_root / "exports" / "PDVDATA",
                tenant_root / "seed" / "data" / "catalog-food.json",
                "Ohlala",
            ),
        ]
    else:
        export = args.export or (tenant_root / "exports" / "PDVDATA-barco")
        out = args.out or (tenant_root / "seed" / "data" / "catalog-store.json")
        brand = args.brand or "El Barco"
        jobs = [(export, out, brand)]

    for export_arg, out_arg, brand in jobs:
        export_dir = export_arg.expanduser()
        if not export_dir.is_absolute():
            export_dir = (tenant_root / export_dir).resolve()
        else:
            export_dir = export_dir.resolve()

        out = out_arg.expanduser()
        if not out.is_absolute():
            out = (tenant_root / out).resolve()
        else:
            out = out.resolve()

        catalog = build_catalog(export_dir, brand)
        suite_copy = suite_data_dir / out.name
        write_catalog(catalog, out, suite_copy)

    # Compat: catalog.json = store (seeds legacy)
    store = tenant_root / "seed" / "data" / "catalog-store.json"
    legacy = tenant_root / "seed" / "data" / "catalog.json"
    if store.is_file():
        shutil.copyfile(store, legacy)
        suite_legacy = suite_data_dir / "catalog.json"
        if suite_data_dir.is_dir():
            shutil.copyfile(store, suite_legacy)


if __name__ == "__main__":
    main()
