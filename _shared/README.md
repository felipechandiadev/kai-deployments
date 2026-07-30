# _shared/

Plantillas y scripts reutilizables entre tenants.  
**No** poner secretos ni estado de un cliente aquí.

| Carpeta | Contenido |
|---------|-----------|
| `templates/` | Molde de env, ecosystem PM2, compose (cuando haya imágenes) |
| `scripts/` | `deploy-tenant`, `backup-tenant`, `seed-tenant` (stubs) |

Dockerfiles de build → **kai-suite**, no aquí.
