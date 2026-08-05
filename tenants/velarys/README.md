# Tenant: velarys

Instancia **KaiFood** (sin landing / eShop / delivery).

| Campo | Valor |
|-------|--------|
| ID / carpeta / DB | `velarys` |
| Producto | `kaisuite` (apps food) |
| Empresa | Velarys (`kaifood`) |
| Menu slug | `velarys` |
| Seed | `velarys` (`npm run seed:velarys`) |
| Puertos | bloque **546x** |

## Dev local

```bash
# Desde kai-deployments
./_shared/scripts/validate-tenants-registry.sh
./_shared/scripts/render-tenant-env.sh velarys
./_shared/scripts/dev-tenant.sh velarys --seed
```

Solo seed (con `kai-core/.env` apuntando a la DB del tenant):

```bash
cd ../kai && npm run seed:velarys
# o:
./_shared/scripts/seed-tenant.sh velarys
```

## Apps / hosts

Dominios públicos (`kaisuite.pro`):

| App | Host | Puerto local |
|-----|------|--------------|
| Backend | `core.velarys.kaisuite.pro` | 5460 |
| Admin | `admin.velarys.kaisuite.pro` | 5471 |
| POS | `pos.velarys.kaisuite.pro` | 5462 |
| Stock | `stock.velarys.kaisuite.pro` | 5463 |
| Waiter | `waiter.velarys.kaisuite.pro` | 5467 |
| KDS | `kds.velarys.kaisuite.pro` | 5468 |
| Board | `board.velarys.kaisuite.pro` | 5469 |
| Menú | `menu.velarys.kaisuite.pro` | 5470 |

Apps: `backend,admin,pos,stock,waiter,menu,board,kds` (sin landing).

- `NEXT_PUBLIC_MENU_STORE_SLUG=velarys`

## Kai Printers (descargas POS)

```bash
./_shared/scripts/sync-tenant-pos-downloads.sh velarys
```

Local: `http://localhost:5462/downloads/…`

## Notas

- Registry local (`tenants-registry.json`) es gitignored; el example compartido incluye la entrada `velarys` con `seed.profile=velarys`.
- Catálogo: `tenants/velarys/seed/data/catalog.json` (mirror de `seeds/velarys/data/catalog.json` en el monorepo).
