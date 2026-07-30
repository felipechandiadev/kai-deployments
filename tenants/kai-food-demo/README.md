# Tenant: kai-food-demo

Instancia demo del vertical **KaiFood** (`KAI_PRODUCT=kaifood`).

- Registry: `database.name=kai_food_demo`, `redisKeyPrefix=kai-food-demo:`, puertos **516x**
- Shared: Postgres / Redis / OSRM / mail / voice del host
- Esta carpeta: **solo config y datos** (no builds). Código e imágenes → `kai-suite`.

## Dev local (un comando)

Prerequisitos: PostGIS en `:5432`, sibling `../kai` (o `KAI_SUITE_ROOT`), `tenants-registry.json`.

```bash
# desde kai-deployments
./_shared/scripts/dev-tenant.sh kai-food-demo

# con seed demo
./_shared/scripts/dev-tenant.sh kai-food-demo --seed

# solo apps (ya provisionado)
./_shared/scripts/dev-tenant.sh kai-food-demo --apps-only
```

Desde el suite:

```bash
npm run dev:tenant -- kai-food-demo
```

Apps típicas: core `:5160`, admin `:5161`, pos `:5162`, stock `:5163`, waiter `:5167`, kds `:5168`, board `:5169`, landing Food `:5166` (`LANDING_PRODUCT=food`), mail `:5040`.

Para volver al perfil suite default: en `kai-suite` → `npm run env:dev`.

## Layout

| Path | Git | Rol |
|------|-----|-----|
| `.env.example` | Sí | Plantilla |
| `.env` | No | Secretos + runtime (generado por `render-tenant-env`) |
| `seed/` | Sí (assets) | Bootstrap datos |
| `backups/` | No (solo `.gitkeep`) | Staging dumps → object storage |
| `uploads/` | No (solo `.gitkeep`) | Volumen multimedia del tenant |

## Seed

Copia de trabajo en `seed/`. Runner canónico: `kai-suite/seeds/` (`seed.profile: demo` en el registry).
