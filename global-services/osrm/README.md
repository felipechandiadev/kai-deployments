# global-services/osrm

**Runtime:** un motor OSRM por host (mapa regional compartido).  
**Código / bootstrap:** vive en **kai-suite** — hoy perfil `osrm` en `backend/docker-compose.yml` + `backend/scripts/osrm-bootstrap.sh`; destino ops: `services/kai-osrm` (migración pendiente en suite).

## Uso por tenants

Todos los backends apuntan al mismo `OSRM_URL` (`sharedServices.osrm.url` en el registry), tipicamente `http://localhost:5001`.

No duplicar OSRM bajo `tenants/*/`.

## Compose stub (referencia)

El stub de este folder documenta imagen/puerto. Para datos de mapa y bootstrap usá los scripts del monorepo hasta completar `services/kai-osrm`.

```bash
# Preferible desde kai-suite mientras dure la migración:
#   cd backend && docker compose --profile osrm up -d
#
# Stub local (requiere volumen/datos preparados):
cd global-services/osrm && docker compose up -d
```
