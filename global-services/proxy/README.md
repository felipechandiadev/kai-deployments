# global-services/proxy

**Runtime:** un reverse proxy en el host (puertos **80/443**).  
**Código:** Caddy, Nginx o Traefik instalado en el VPS — no en kai-suite como app de producto.

## Rol

Recibe HTTPS y enruta por hostname a los puertos de cada tenant (`tenants[].hosts` + `tenants[].ports` en el registry).

Ejemplo conceptual:

- `admin.store-demo.example.com` → `127.0.0.1:5071`
- `pos.food-demo.example.com` → `127.0.0.1:5162`

Los vhosts concretos se generan o mantienen aparte (fuera de alcance de este stub). Fuente de verdad de puertos/dominios: `tenants-registry.json`.
