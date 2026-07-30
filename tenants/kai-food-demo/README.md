# Tenant: kai-food-demo

Instancia demo del vertical **KaiFood** (`KAI_PRODUCT=kaifood`).

- Registry: `database.name=kai_food_demo`, `redisKeyPrefix=kai-food-demo:`
- Shared: `OSRM_URL` / mail / voice / Postgres+Redis del host (`global-services/`)
- Seeds de producto: `kai-suite/seeds/` (no duplicar aquí)
- Completar `.env` en el VPS a partir de `.env.example`

## Seed

Copia de trabajo desde `kai-suite/seeds/demo` en `seed/` (bootstrap del tenant). El runner canónico del monorepo sigue en `kai-suite/seeds/`.
