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
  kai-food-demo/
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

### `apps` (web + nativos)

```json
"apps": {
  "web": ["backend", "admin", "pos", "stock", "eshop", "delivery", "landing"],
  "native": [
    {
      "id": "printers",
      "label": "Kai Printers",
      "platforms": ["android", "windows", "macos"],
      "source": "kai-suite (kai-printers-android, kai-printers-desktop)"
    },
    {
      "id": "cfd",
      "label": "Kai CFD",
      "platforms": ["android"],
      "source": "kai-suite (kai-screen-android)"
    }
  ]
}
```

Los nativos **no** ocupan puerto del host; el registry declara qué instalables/plataformas habilita el tenant (descargas POS `/downloads/`, etc.).

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
- Seeds de producto → `kai-suite/seeds/`.

## Desarrollo local

Abrí `kai-platform.code-workspace` desde `kai-suite` (multi-root).

## Relación con kai-suite

| En kai-suite | En kai-deployments |
|--------------|--------------------|
| `deploy/` (bootstrap VPS) | Estado por tenant + `global-services/` |
| `envs/`, `seeds/` | Overrides de instancia |
| OSRM / mail / voice (código) | Runtime 1× documentado aquí |
