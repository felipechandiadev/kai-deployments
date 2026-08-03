# Catálogo Barco / Ohlala

Generar ambos JSON desde exports PDV:

```bash
cd ../../kai-deployments/tenants/barco   # o desde tenants/barco
python3 seed/generate_catalog.py --all
```

Salidas: `catalog-store.json` (El Barco), `catalog-food.json` (Ohlala), más copia legacy `catalog.json`.
También se copian a `kai/seeds/barco/data/` si el monorepo sibling existe.

No editar a mano salvo ajustes puntuales; regenerar desde `PRODUCTOS.jsonl`.
