# Tenant: mias

Instancia **KaiFood** vacía operable (sin catálogo, sin waiter / eShop / delivery / landing).

| Campo | Valor |
|-------|--------|
| ID / carpeta / DB | `mias` |
| Producto | `kaisuite` (apps food) |
| Empresa | Mias SpA / Mias (`kaifood`) |
| Menu slug | `mias` |
| Seed | `mias` (`npm run seed:mias`) |
| Puertos | bloque **556x** |

## Dev local

```bash
# Desde kai-deployments
./_shared/scripts/validate-tenants-registry.sh
./_shared/scripts/render-tenant-env.sh mias
./_shared/scripts/dev-tenant.sh mias --seed
```

Solo seed (con `kai-core/.env` apuntando a la DB del tenant):

```bash
cd ../kai && npm run seed:mias
# o:
./_shared/scripts/seed-tenant.sh mias
```

## Apps / hosts

Dominios públicos (`kaisuite.pro`):

| App | Host | Puerto local |
|-----|------|--------------|
| Backend | `core.mias.kaisuite.pro` | 5560 |
| Admin | `admin.mias.kaisuite.pro` | 5571 |
| POS | `pos.mias.kaisuite.pro` | 5562 |
| Stock | `stock.mias.kaisuite.pro` | 5563 |
| KDS | `kds.mias.kaisuite.pro` | 5568 |
| Board | `board.mias.kaisuite.pro` | 5569 |
| Menú | `menu.mias.kaisuite.pro` | 5570 |

Apps: `backend,admin,pos,stock,menu,board,kds` (sin waiter / landing).

- `NEXT_PUBLIC_MENU_STORE_SLUG=mias`

## Seed (mínimo)

- Usuarios: `superadmin`, `admin`, `operador` (password `098098`) — sin mesero
- 1 sucursal HQ, 1 salón con 1 mesa, 1 UP Cocina (KDS), 1 UL
- Lista Minorista vacía, sin productos/categorías
- Socio Gabriel 100%, RUT empresa `76.999.111-5`

## Kai Printers (descargas POS)

```bash
./_shared/scripts/sync-tenant-pos-downloads.sh mias
```

Local: `http://localhost:5562/downloads/…`

## Notas

- Registry local (`tenants-registry.json`) es gitignored; el example compartido incluye la entrada `mias` con `seed.profile=mias`.
- Seed en monorepo: `seeds/mias/` (sin `data/catalog.json`).
