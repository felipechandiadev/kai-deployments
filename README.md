# kai-deployments

Orquestación **por tenant** (SaaS single-tenant / multi-instancia) para la plataforma Kai.

El código de producto vive en [`kai-suite`](https://github.com/felipechandiadev/kai-suite).  
Este repo define **cómo corre cada instancia** y los servicios **compartidos** del host.

## Estructura

```text
tenants-registry.example.json   # Plantilla del registro (commiteable)
tenants-registry.json           # Registro real del host (gitignored)
global-services/                # Runtime 1×: PostGIS, Redis, mail, voice, OSRM, proxy
_shared/                        # Plantillas y scripts
tenants/                        # Una carpeta = una instancia aislada
  kai-store-demo/
    seed/                       # Bootstrap datos (copia inicial desde kai-suite/seeds/demo)
  kai-food-demo/
    seed/
```

## Shared vs tenant

| Compartido (`global-services/` + `sharedServices`) | Por tenant (`tenants/*` + entrada en registry) |
|----------------------------------------------------|--------------------------------------------------|
| Postgres + PostGIS (1 instancia) | `database.name` / `database.user` |
| Redis (1 instancia) | `redisKeyPrefix` → `REDIS_KEY_PREFIX` |
| OSRM, kai-voice | Misma URL en todos los backends |
| kai-mail (**default shared**) | `tenants[].mail.mode`: `shared` \| `dedicated` (+ url/port si dedicated) |
| Proxy 80/443 | Puertos y hosts de apps |

## Tenant Registry

```bash
cp tenants-registry.example.json tenants-registry.json
# Editar dominios/puertos/BD reales
./_shared/scripts/validate-tenants-registry.sh
```

| Archivo | Git |
|---------|-----|
| `tenants-registry.example.json` | Sí |
| `tenants-registry.json` | **No** |

Campos por tenant activos: `id`, `ports`, `database.name`, `redisKeyPrefix`, `apps.{web,native}`, opcional `mail.mode`.  
Validación: ids, puertos (apps + mail dedicated + shared mail), BD y prefijos Redis únicos; `apps.native[].platforms`; `sharedServices.postgres|redis|osrm|mail` presentes.

### `apps` (catálogo completo → true | false)

Todas las claves deben existir; `true` = habilitada en ese tenant.

```json
"apps": {
  "web": {
    "backend": true,
    "admin": true,
    "pos": true,
    "stock": true,
    "eshop": true,
    "delivery": true,
    "waiter": false,
    "kds": false,
    "board": false,
    "landing": true
  },
  "native": {
    "printers": { "android": true, "windows": true, "macos": true },
    "cfd": { "android": true }
  }
}
```

Nativos no usan puerto del host; indican qué instalables/plataformas ofrece el tenant (p. ej. descargas POS).

Bloques de puertos: `kai-store-demo` ~506x; `kai-food-demo` ~516x.

## Tenants actuales

| Tenant | Producto | DB (example) | Redis prefix |
|--------|----------|--------------|--------------|
| `kai-store-demo` | `kaistore` | `kai_store_demo` | `kai-store-demo:` |
| `kai-food-demo` | `kaifood` | `kai_food_demo` | `kai-food-demo:` |

## Reglas

- **No** subir `.env` reales, `tenants-registry.json`, certificados ni dumps.
- Passwords solo en `.env` del tenant / vault.
- Backups → object storage, nunca Git.
- Dockerfiles de build → **kai-suite**; aquí compose/PM2 y config de host.
- Seeds de producto canónicos: `kai-suite/seeds/`. Por tenant: `tenants/<id>/seed/` (copia de trabajo; demos parten de `seeds/demo`).

## Desarrollo local

Abrí `kai-platform.code-workspace` desde `kai-suite` (multi-root).

### Un tenant en modo instancia (recomendado KaiFood)

```bash
# desde este repo
./_shared/scripts/validate-tenants-registry.sh
./_shared/scripts/dev-tenant.sh kai-food-demo          # apps food en :516x
./_shared/scripts/dev-tenant.sh kai-food-demo --seed   # + seed demo
```

El script:

1. Materializa `tenants/<id>/.env` (registry + `.env.example`; no pisa secretos).
2. Crea la database PostGIS del tenant si falta.
3. Proyecta envs al checkout de **kai-suite** (`KAI_ENV_MATRIX`).
4. Corre migraciones y levanta solo las apps de `apps.web` (+ mail).

**Builds** viven en `kai-suite` / registry de imágenes — **no** en `tenants/`.

Volver al perfil suite default: `cd ../kai && npm run env:dev`.

## Relación con kai-suite

| En kai-suite | En kai-deployments |
|--------------|--------------------|
| `deploy/` (bootstrap VPS) | Estado por tenant + `global-services/` |
| `envs/`, `seeds/` | Overrides de instancia + `dev-tenant` |
| OSRM / mail / voice (código) | Runtime 1× documentado aquí |
