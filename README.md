# kai-deployments

Orquestación **por tenant** (SaaS single-tenant / multi-instancia) para la plataforma Kai.

El código de producto vive en [`kai-suite`](https://github.com/felipechandiadev/kai-suite).  
Este repo define **cómo corre cada instancia** (puertos, dominios, compose/PM2, env examples).

## Estructura

```text
tenants-registry.example.json   # Plantilla del registro (commiteable)
tenants-registry.json           # Registro real del host (gitignored)
_shared/                        # Plantillas y scripts reutilizables
  templates/
  scripts/                      # deploy / backup / seed / validate-tenants-registry
tenants/                        # Una carpeta = una instancia aislada
  kai-store-demo/
  kai-food-demo/
```

## Tenant Registry

Fuente de verdad de **asignación de puertos / hosts** entre instancias en el mismo VPS (evita colisiones).

```bash
cp tenants-registry.example.json tenants-registry.json   # una vez por máquina
# Editar tenants-registry.json con dominios/puertos reales del host
./_shared/scripts/validate-tenants-registry.sh
```

| Archivo | Git |
|---------|-----|
| `tenants-registry.example.json` | Sí (placeholders `example.com`, sin secretos) |
| `tenants-registry.json` | **No** (asignación real del entorno) |

Bloques sugeridos: `kai-store-demo` → serie ~506x; `kai-food-demo` → serie ~516x (`blockSizeHint`: 100).

## Tenants actuales

| Tenant | Producto (`KAI_PRODUCT`) | Notas |
|--------|--------------------------|--------|
| `kai-store-demo` | `kaistore` | Demo retail |
| `kai-food-demo` | `kaifood` | Demo salón / KDS / mesero |

Clientes reales se agregarán cuando haya instancia que orquestar.

## Reglas

- **No** subir `.env` reales, `tenants-registry.json`, certificados ni dumps de BD.
- Usar `.env.example` / `tenants-registry.example.json` como plantillas.
- Backups → object storage (`s3://…`), nunca Git.
- Dockerfiles de build viven en **kai-suite**; aquí solo compose/PM2 y config.
- Seeds de producto: `kai-suite/seeds/`; este repo solo overrides de instancia si hacen falta.

## Desarrollo local

Abrí `kai-platform.code-workspace` desde `kai-suite` (multi-root: suite + este repo).

## Relación con kai-suite

| En kai-suite | En kai-deployments |
|--------------|--------------------|
| `deploy/` (bootstrap VPS) | Estado por tenant en `tenants/*` |
| `envs/`, `seeds/` | Overrides y secretos de instancia |
| Dockerfiles / imágenes | Referenciadas desde compose (cuando existan) |
