# global-services/redis

**Runtime:** una instancia Redis por host.  
**Código:** imagen `redis:7-alpine` (compose stub) o servicio del OS (`brew services redis`).

## Aislamiento

Todos los backends comparten host/puerto. El aislamiento es **`REDIS_KEY_PREFIX`** por tenant (registry → `.env`), p. ej. `kai-store-demo:`.

Kai Core ya antepone el prefijo en caché (`REDIS_KEY_PREFIX`).

## Compose stub

```bash
cd global-services/redis
docker compose up -d
```

Puerto por defecto: **6379** (`sharedServices.redis` en el registry).
