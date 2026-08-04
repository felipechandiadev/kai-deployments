# Tenant: barco

Instancia **KaiFood** (sin landing) — una empresa, dos sucursales:

| Empresa | Producto | Sucursales | Catálogo (seed) |
|---------|----------|------------|-----------------|
| **Ohlala** | `kaifood` | Ohlala (HQ) + El Barco | Merge `catalog-food.json` + `catalog-store.json` (~5k SKUs únicos) |

Los `.FDB` y `exports/PDVDATA*` son **locales** (gitignored): solo para regenerar los JSON.

## Qué incluye el seed

- Scaffold: IVA 19%, unidades, lista Minorista, CC, medios de pago
- Por sucursal: sala de venta (STORE), POS Caja 1, cash hub
- Catálogo unificado (food gana en duplicados); **todos sin control de stock** (sin `StockLevel`)
- **Ohlala:** `on_menu`, carta slug `ohlala`, tips (enabled=false), salón + 6 mesas, cocina (UP), UL Cafetería (turno 09:00–21:00) + UL Salón (mesero)
- **El Barco:** mismo catálogo vía POS, sin mesas
- Usuarios (password seed `098098`, todos con Person):

| Usuario | Rol | Membership |
|---------|-----|------------|
| `superadmin` | SUPER_ADMIN | Plataforma |
| `admin` | ADMIN | Dueño Ohlala |
| `operador` | POS_OPERATOR | Ohlala |
| `mesero` | WAITER | Ohlala (+ employee tipsEligible) |

El runner vive en el monorepo: `kai/seeds/barco` (`npm run seed:barco`).

> **Migración dual → mono:** si ya tenías El Barco (`kaistore`) + Ohlala en la misma DB, **recreá la DB** (o wipe) antes de reseedar. El seed no fusiona empresas viejas.

## Dev local

```bash
# 1) Materializar .env desde registry
./_shared/scripts/render-tenant-env.sh barco

# 2) Levantar (migrate + seed profile=barco)
./_shared/scripts/dev-tenant.sh barco --seed

# O solo seed (con kai-core/.env apuntando a la DB del tenant):
cd ../kai && npm run seed:barco
```

## Regenerar catálogos (opcional, requiere exports locales)

Con `PDVDATA*.FDB` y/ o `exports/PDVDATA*` en la máquina (no van a git):

```bash
# FDB → JSONL (si hace falta)
python3 exports/export_fdb_to_jsonl.py

# Ambos (store + food) y copia a kai/seeds/barco/data/
python3 seed/generate_catalog.py --all

# O por separado:
python3 seed/generate_catalog.py \
  --export exports/PDVDATA-barco \
  --out seed/data/catalog-store.json \
  --brand "El Barco"

python3 seed/generate_catalog.py \
  --export exports/PDVDATA \
  --out seed/data/catalog-food.json \
  --brand "Ohlala"
```

El seed une ambos JSON en runtime (no hace falta un `catalog-unified.json` en git).

## Apps / carta

Dominios públicos (`kaisuite.pro`):

| App | Host |
|-----|------|
| Backend | `core.ohlala.kaisuite.pro` |
| Admin | `admin.ohlala.kaisuite.pro` |
| POS | `pos.ohlala.kaisuite.pro` |
| Stock | `stock.ohlala.kaisuite.pro` |
| Waiter | `waiter.ohlala.kaisuite.pro` |
| KDS | `kds.ohlala.kaisuite.pro` |
| Board | `board.ohlala.kaisuite.pro` |
| Menú | `menu.ohlala.kaisuite.pro` |

Apps: `backend,admin,pos,stock,waiter,menu,board,kds` (sin landing).

- Menu slug: `NEXT_PUBLIC_MENU_STORE_SLUG=ohlala`
- Tenant id / carpeta / DB siguen siendo `barco`

## Kai Printers (descargas POS)

Tras publicar en kai-suite (`npm run kai-printers:publish -- --windows-only`), verificar para este tenant:

```bash
# desde kai-deployments
./_shared/scripts/sync-tenant-pos-downloads.sh barco
```

Local (puerto POS `5262`): `http://localhost:5262/downloads/kai-printers-windows.manifest.json`  
Público: `https://pos.ohlala.kaisuite.pro/downloads/…` (tras rsync al VPS).
