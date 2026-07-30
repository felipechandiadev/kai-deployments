#!/usr/bin/env bash
# Backup DB del tenant → object storage (no Git). Uso: ./_shared/scripts/backup-tenant.sh <tenant-id>
set -euo pipefail

TENANT="${1:-}"
if [[ -z "$TENANT" ]]; then
  echo "Uso: $0 <tenant-id>" >&2
  exit 1
fi

echo "→ backup-tenant: $TENANT"
echo "  TODO: pg_dump + upload a s3/r2 (nunca commits de .sql)."
