# Catálogo Barco / Ohlala

Generar ambos JSON desde exports PDV (fuentes del merge en el seed):

```bash
cd ../../kai-deployments/tenants/barco   # o desde tenants/barco
python3 seed/generate_catalog.py --all
```

Salidas: `catalog-store.json` + `catalog-food.json` (más copia legacy `catalog.json`).
También se copian a `kai/seeds/barco/data/` si el monorepo sibling existe.

El seed (`npm run seed:barco`) unifica en runtime: food gana en choques; sin control de stock.

No editar a mano salvo ajustes puntuales; regenerar desde `PRODUCTOS.jsonl`.
