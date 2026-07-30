# global-services/postgres

**Runtime:** una instancia PostgreSQL **con PostGIS** por host (VPS o máquina de ops).  
**Código:** no hay app Kai aquí — motor del sistema o contenedor `postgis/postgis`.

## Aislamiento

| Compartido | Por tenant (ver registry) |
|------------|---------------------------|
| Host / puerto PostGIS | `database.name`, `database.user` |
| Extensión `postgis` | Datos de negocio en esa BD |

Passwords → `.env` del tenant (nunca el registry).

## Dev (kai-suite)

En desarrollo local el monorepo usa Postgres+PostGIS del **sistema**:

```bash
# en kai-suite
npm run setup:postgres
npm run dev:infra
```

Docs: `kai-suite/docs/project/POSTGIS-DELIVERY.md`.

## Producción / VPS

1. Instalar o levantar **un** PostGIS en el puerto declarado en `sharedServices.postgres`.
2. Crear una database/user por tenant según `tenants-registry.json`.
3. Cada backend apunta con `DB_HOST` / `DB_DATABASE` / `DB_USERNAME` (desde el `.env` del tenant).
