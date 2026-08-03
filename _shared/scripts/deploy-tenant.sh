#!/usr/bin/env bash
# Deploy / update de un tenant. Uso: ./_shared/scripts/deploy-tenant.sh <tenant-id>
# Stub: completar cuando el flujo VPS (PM2 o compose) esté definido.
set -euo pipefail

TENANT="${1:-}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ -z "$TENANT" ]]; then
  echo "Uso: $0 <tenant-id>" >&2
  echo "Tenants: $(ls -1 "$ROOT/tenants" | tr '\n' ' ')" >&2
  exit 1
fi

DIR="$ROOT/tenants/$TENANT"
if [[ ! -d "$DIR" ]]; then
  echo "No existe tenants/$TENANT" >&2
  exit 1
fi

echo "→ deploy-tenant: $TENANT ($DIR)"
echo "  TODO: leer $DIR/.env, ecosystem o docker compose, migraciones."
echo "  Tip: sincronizar descargas POS (Kai Printers) si el tenant las ofrece:"
echo "    ./_shared/scripts/sync-tenant-pos-downloads.sh $TENANT"
echo "    TENANT_POS_DOWNLOADS_RSYNC_TARGET=user@host:/path/kai-pos/public/downloads/ \\"
echo "      ./_shared/scripts/sync-tenant-pos-downloads.sh $TENANT --rsync"
