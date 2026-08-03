# Kai Suite Demo — tenant multi-vertical (KaiStore + KaiFood)

Plantilla de entorno para desarrollo local con **dos empresas** en una BD:

- **Kai Store** (`kaistore`) — retail, eShop, delivery, lavandería
- **Kai Food** (`kaifood`) — salón, KDS, mesero, carta `kai-menu`

## Uso

```bash
cd kai-deployments
./_shared/scripts/dev-tenant.sh kai-suite-demo --seed
```

Seed: `KAI_SEED_MODE=suite` (Store + Food completo, `on_menu` en carta food).

## Apps (puertos 536x)

| App     | Puerto |
|---------|--------|
| backend | 5360   |
| admin   | 5371   |
| pos     | 5362   |
| stock   | 5363   |
| eshop   | 5364   |
| delivery| 5365   |
| landing | 5366   |
| waiter  | 5367   |
| kds     | 5368   |
| board   | 5369   |
| menu    | 5370   |

## Credenciales demo

- `admin` / `098098` — miembro de ambas empresas
- `mesero1` / `098098` — solo Kai Food (WAITER)

Carta pública: http://localhost:5370 (`NEXT_PUBLIC_MENU_STORE_SLUG=kai-food`)
