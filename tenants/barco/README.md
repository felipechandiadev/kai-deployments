# Tenant: barco

Instancia **Kai Suite** dual-company (sin landing):

| Empresa | Producto | Catálogo (seed) |
|---------|----------|-----------------|
| **El Barco** | `kaistore` | `seed/data/catalog-store.json` (~3100 SKUs) |
| **Ohlala** | `kaifood` | `seed/data/catalog-food.json` (~3900 SKUs) |

Los `.FDB` y `exports/PDVDATA*` son **locales** (gitignored): solo para regenerar los JSON.

## Qué incluye el seed

- Scaffold por empresa: IVA 19%, unidades, 1 sucursal, 1 bodega, lista Minorista, POS + cash hub, CC, medios de pago
- Productos + snapshot `StockLevel` desde `DINVENTARIO` (sin historial de ventas/compras)
- **Ohlala:** `on_menu`, carta slug `ohlala`, tips (enabled=false), salón + 6 mesas, cocina (UP), UL Cafetería (turno 09:00–21:00) + UL Salón (mesero)
- Usuarios (password seed `098098`, todos con Person):

| Usuario | Rol | Membership |
|---------|-----|------------|
| `superadmin` | SUPER_ADMIN | Plataforma |
| `admin` | ADMIN | Dueño en ambas |
| `operador` | POS_OPERATOR | Ambas |
| `mesero` | WAITER | Solo Ohlala (+ employee tipsEligible) |

El runner vive en el monorepo: `kai/seeds/barco` (`npm run seed:barco`).

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
