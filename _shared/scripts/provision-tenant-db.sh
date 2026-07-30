#!/usr/bin/env bash
# Crea rol + database PostGIS para un tenant (idempotente).
# Uso: ./_shared/scripts/provision-tenant-db.sh <tenant-id>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TENANT="${1:-}"
REG_JS="$ROOT/_shared/lib/registry.cjs"

if [[ -z "$TENANT" ]]; then
  echo "Uso: $0 <tenant-id>" >&2
  exit 1
fi

FOLDER="$(TENANTS_REGISTRY="${TENANTS_REGISTRY:-$ROOT/tenants-registry.json}" node "$REG_JS" folder "$TENANT")"
ENV_FILE="$ROOT/$FOLDER/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Falta $ENV_FILE — ejecutá render-tenant-env.sh primero" >&2
  exit 1
fi

env_get() {
  grep -E "^${1}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true
}

DB_HOST="$(env_get DB_HOST)"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="$(env_get DB_PORT)"
DB_PORT="${DB_PORT:-5432}"
DB_USERNAME="$(env_get DB_USERNAME)"
DB_DATABASE="$(env_get DB_DATABASE)"
DB_PASSWORD="$(env_get DB_PASSWORD)"
DB_PASSWORD="${DB_PASSWORD:-kai123}"

if [[ -z "$DB_DATABASE" || -z "$DB_USERNAME" ]]; then
  echo "DB_DATABASE / DB_USERNAME vacíos en $ENV_FILE" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "✗ psql no está en PATH" >&2
  exit 1
fi

echo "==> Provision DB tenant=$TENANT → ${DB_HOST}:${DB_PORT} / ${DB_DATABASE} (user ${DB_USERNAME})"

PSQL_ADMIN=(psql -p "$DB_PORT" -d postgres -v ON_ERROR_STOP=1)
if ! "${PSQL_ADMIN[@]}" -c "SELECT 1" >/dev/null 2>&1; then
  PSQL_ADMIN=(psql -h "$DB_HOST" -p "$DB_PORT" -d postgres -v ON_ERROR_STOP=1)
fi

# Escapar comillas simples para SQL literal
sql_quote() {
  printf "%s" "$1" | sed "s/'/''/g"
}

USER_Q="$(sql_quote "$DB_USERNAME")"
PASS_Q="$(sql_quote "$DB_PASSWORD")"
DB_Q="$(sql_quote "$DB_DATABASE")"

ROLE_EXISTS="$("${PSQL_ADMIN[@]}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${USER_Q}'" || true)"
if [[ "$ROLE_EXISTS" != "1" ]]; then
  "${PSQL_ADMIN[@]}" -c "CREATE ROLE \"${DB_USERNAME}\" LOGIN PASSWORD '${PASS_Q}';"
  echo "  → rol creado: $DB_USERNAME"
else
  "${PSQL_ADMIN[@]}" -c "ALTER ROLE \"${DB_USERNAME}\" WITH LOGIN PASSWORD '${PASS_Q}';" >/dev/null
  echo "  → rol ya existía (password sync)"
fi

DB_EXISTS="$("${PSQL_ADMIN[@]}" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_Q}'" || true)"
if [[ "$DB_EXISTS" != "1" ]]; then
  "${PSQL_ADMIN[@]}" -c "CREATE DATABASE \"${DB_DATABASE}\" OWNER \"${DB_USERNAME}\";"
  echo "  → database creada: $DB_DATABASE"
else
  echo "  → database ya existía: $DB_DATABASE"
fi

"${PSQL_ADMIN[@]}" -d "$DB_DATABASE" -c "CREATE EXTENSION IF NOT EXISTS postgis;" >/dev/null
"${PSQL_ADMIN[@]}" -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_DATABASE}\" TO \"${DB_USERNAME}\";" >/dev/null || true

echo "✅ DB lista: $DB_DATABASE"
