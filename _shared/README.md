# _shared/

Plantillas y scripts reutilizables entre tenants.  
**No** poner secretos ni estado de un cliente aquí.

| Carpeta | Contenido |
|---------|-----------|
| `templates/` | Molde de env, ecosystem PM2, compose (cuando haya imágenes) |
| `scripts/` | `dev-tenant`, `render-tenant-env`, `provision-tenant-db`, `deploy-tenant`, `backup-tenant`, `seed-tenant`, `validate-tenants-registry` |
| `lib/` | `registry.cjs` (lectura del Tenant Registry) |

Servicios compartidos del host → [`../global-services/`](../global-services/).  
Registro de puertos/BD/Redis → raíz: `tenants-registry.example.json` / `tenants-registry.json` (gitignored).

Dockerfiles de build → **kai-suite**, no aquí.
