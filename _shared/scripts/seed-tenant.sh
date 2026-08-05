#!/usr/bin/env bash
# Seed de un tenant vía perfil del monorepo. Uso: ./_shared/scripts/seed-tenant.sh <tenant-id>
# Preferir SEED_PROFILE / seeds en kai-suite; no duplicar fixtures aquí.
set -euo pipefail

TENANT="${1:-}"
if [[ -z "$TENANT" ]]; then
  echo "Uso: $0 <tenant-id>" >&2
  exit 1
fi

echo "→ seed-tenant: $TENANT"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TENANT_ENV="$ROOT/tenants/$TENANT/.env"
SUITE="${KAI_SUITE_ROOT:-$(cd "$ROOT/../kai" 2>/dev/null && pwd)}"

if [[ ! -d "$SUITE" ]]; then
  echo "No se encontró kai-suite (KAI_SUITE_ROOT o ../kai)." >&2
  exit 1
fi

PROFILE=""
if [[ -f "$TENANT_ENV" ]]; then
  PROFILE="$(grep -E '^KAI_SEED_PROFILE=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)"
fi
if [[ -z "$PROFILE" ]]; then
  # Fallback: registry
  REGISTRY="$ROOT/tenants-registry.json"
  if [[ -f "$REGISTRY" ]] && command -v python3 >/dev/null; then
    PROFILE="$(python3 - <<PY
import json
reg=json.load(open("$REGISTRY"))
t=next((x for x in reg.get("tenants",[]) if x.get("id")=="$TENANT"), None)
print((t or {}).get("seed",{}).get("profile") or "")
PY
)"
  fi
fi
PROFILE="${PROFILE:-demo}"

echo "  profile=$PROFILE suite=$SUITE"
case "$PROFILE" in
  demo|kaifood|food|suite)
    (cd "$SUITE" && npm run seed:demo)
    ;;
  barco)
    (cd "$SUITE" && npm run seed:barco)
    ;;
  velarys)
    (cd "$SUITE" && npm run seed:velarys)
    ;;
  joyarte)
    (cd "$SUITE" && npm run seed:joyarte)
    ;;
  *)
    echo "seed.profile desconocido ($PROFILE)" >&2
    exit 1
    ;;
esac
