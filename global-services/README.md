# global-services/

Servicios de infraestructura que corren **una sola vez en el host** y los usan todos los tenants.

| Pieza | Runtime | Código / imagen |
|-------|---------|-----------------|
| [`postgres/`](./postgres/) | 1× PostGIS | Paquete OS o imagen `postgis/postgis` (no vive en este repo) |
| [`redis/`](./redis/) | 1× Redis | Imagen oficial / brew; aislamiento por `REDIS_KEY_PREFIX` |
| [`mail/`](./mail/) | 1× kai-mail (default) o dedicated por tenant | **kai-suite** `services/kai-mail` — ver modos en el README |
| [`osrm/`](./osrm/) | 1× OSRM | Ops/docs en **kai-suite** (`backend` OSRM hoy; `services/kai-osrm` pendiente) |
| [`proxy/`](./proxy/) | 1× 80/443 | Caddy / Nginx / Traefik en el host |

**Este repo no contiene el código de producto.** Solo documenta (y stubs de compose) cómo se levanta el runtime compartido.

Asignación por tenant (BD, prefijo Redis, puertos de apps): raíz [`tenants-registry.example.json`](../tenants-registry.example.json) → `tenants-registry.json` (gitignored).
