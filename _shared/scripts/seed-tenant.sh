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
echo "  TODO: invocar seed del suite con el perfil acordado (ej. demo / kaifood)."
