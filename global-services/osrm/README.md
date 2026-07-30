# global-services/osrm

**Runtime:** un motor OSRM por host (mapa regional compartido).  
**Código / bootstrap / datos:** viven en el monorepo **kai** → `services/kai-osrm/` (compose, `scripts/osrm-bootstrap.sh`, volumen `data/`).

## Uso por tenants

Todos los backends apuntan al mismo `OSRM_URL` (`sharedServices.osrm.url` en el registry), tipicamente `http://localhost:5001`.

No duplicar OSRM bajo `tenants/*/`.

## Levantar (suite)

```bash
# Desde la raíz del monorepo kai:
./services/kai-osrm/scripts/osrm-bootstrap.sh   # primera vez
docker compose -f services/kai-osrm/docker-compose.osrm.yml up -d
```

## Compose stub (referencia)

El stub de este folder documenta imagen/puerto para hosts donde solo se monta el volumen ya procesado:

```bash
cd global-services/osrm && docker compose --profile osrm up -d
```

Montar el extract procesado desde el host (ruta a ajustar); ver comentarios en `docker-compose.yml`.
