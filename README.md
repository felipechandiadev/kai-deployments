# kai-deployments

Orquestación **por tenant** (SaaS single-tenant / multi-instancia) para la plataforma Kai.

El código de producto vive en [`kai-suite`](https://github.com/felipechandiadev/kai-suite).  
Este repo define **cómo corre cada instancia** (puertos, dominios, compose/PM2, env examples).

## Estructura

```text
_shared/                 # Plantillas y scripts reutilizables
  templates/
  scripts/
tenants/                 # Una carpeta = una instancia aislada
  kai-store-demo/        # Demo vertical KaiStore
  kai-food-demo/         # Demo vertical KaiFood
```

## Tenants actuales

| Tenant | Producto (`KAI_PRODUCT`) | Notas |
|--------|--------------------------|--------|
| `kai-store-demo` | `kaistore` | Demo retail / joyería |
| `kai-food-demo` | `kaifood` | Demo salón / KDS / mesero |

Clientes reales (joyarte, san-sebastian, …) se agregarán cuando haya instancia que orquestar.

## Reglas

- **No** subir `.env` reales, certificados ni dumps de BD.
- Usar `.env.example` y secretos en el VPS / vault.
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
