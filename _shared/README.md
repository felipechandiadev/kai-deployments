# _shared/

Plantillas y scripts reutilizables entre tenants.  
**No** poner secretos ni estado de un cliente aquí.

| Carpeta | Contenido |
|---------|-----------|
| `templates/` | Molde de env, ecosystem PM2, compose (cuando haya imágenes) |
| `scripts/` | `deploy-tenant`, `backup-tenant`, `seed-tenant`, `validate-tenants-registry` |

El registro de puertos/hosts vive en la raíz: `tenants-registry.example.json` (git) / `tenants-registry.json` (local, gitignored).

Dockerfiles de build → **kai-suite**, no aquí.
