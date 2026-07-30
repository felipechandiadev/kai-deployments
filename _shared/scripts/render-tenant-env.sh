#!/usr/bin/env bash
# Materializa tenants/<id>/.env desde .env.example + topología del registry.
# No pisa secretos ya presentes (DB_PASSWORD, JWT_*, NEXTAUTH_SECRET, API keys).
# Uso: ./_shared/scripts/render-tenant-env.sh <tenant-id>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TENANT="${1:-}"
REG_JS="$ROOT/_shared/lib/registry.cjs"

if [[ -z "$TENANT" ]]; then
  echo "Uso: $0 <tenant-id>" >&2
  exit 1
fi

FOLDER="$(TENANTS_REGISTRY="${TENANTS_REGISTRY:-$ROOT/tenants-registry.json}" node "$REG_JS" folder "$TENANT")"
DIR="$ROOT/$FOLDER"
EXAMPLE="$DIR/.env.example"
DEST="$DIR/.env"

if [[ ! -d "$DIR" ]]; then
  echo "No existe $DIR" >&2
  exit 1
fi

mkdir -p "$DIR"
if [[ ! -f "$EXAMPLE" ]]; then
  echo "[render-tenant-env] falta $EXAMPLE — creando mínimo" >&2
  printf '# Generado — completar secretos\n' > "$EXAMPLE"
fi

if [[ ! -f "$DEST" ]]; then
  cp "$EXAMPLE" "$DEST"
  echo "[render-tenant-env] creado $DEST desde .env.example"
fi

# Keys que nunca se sobrescriben si ya existen con valor no vacío
is_secret_key() {
  case "$1" in
    DB_PASSWORD|JWT_SECRET|JWT_REFRESH_SECRET|FISCAL_ENCRYPTION_KEY|KAI_MAIL_API_KEY)
      return 0 ;;
    *NEXTAUTH_SECRET*|*_SECRET|*PASSWORD*|*API_KEY*)
      return 0 ;;
  esac
  return 1
}

env_get() {
  local file="$1" key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- || true
}

set_kv() {
  local file="$1" key="$2" val="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    perl -i -pe "s/^\Q${key}\E=.*/${key}=${val}/" "$file" 2>/dev/null || \
      sed -i '' "s|^${key}=.*|${key}=${val}|" "$file"
  else
    printf '%s=%s\n' "$key" "$val" >> "$file"
  fi
}

TMP="$(mktemp)"
TENANTS_REGISTRY="${TENANTS_REGISTRY:-$ROOT/tenants-registry.json}" \
  node "$REG_JS" env-vars "$TENANT" > "$TMP"

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  [[ -z "$key" ]] && continue
  if is_secret_key "$key"; then
    existing="$(env_get "$DEST" "$key")"
    if [[ -n "$existing" ]]; then
      continue
    fi
  fi
  set_kv "$DEST" "$key" "$val"
done < "$TMP"
rm -f "$TMP"

# Defaults de secretos de desarrollo si faltan
if [[ -z "$(env_get "$DEST" DB_PASSWORD)" ]]; then
  set_kv "$DEST" "DB_PASSWORD" "kai123"
  echo "[render-tenant-env] DB_PASSWORD=kai123 (default dev)"
fi
if [[ -z "$(env_get "$DEST" ADMIN_NEXTAUTH_SECRET)" ]]; then
  set_kv "$DEST" "ADMIN_NEXTAUTH_SECRET" "dev-admin-secret-change-me"
fi
if [[ -z "$(env_get "$DEST" POS_NEXTAUTH_SECRET)" ]]; then
  set_kv "$DEST" "POS_NEXTAUTH_SECRET" "dev-pos-secret-change-me"
fi
if [[ -z "$(env_get "$DEST" STOCK_NEXTAUTH_SECRET)" ]]; then
  set_kv "$DEST" "STOCK_NEXTAUTH_SECRET" "dev-stock-secret-change-me"
fi
if [[ -z "$(env_get "$DEST" KAI_MAIL_API_KEY)" ]]; then
  set_kv "$DEST" "KAI_MAIL_API_KEY" "dev-kai-mail-key"
fi

# JWT / fiscal desde matriz suite (dev) si faltan
SUITE_SHARED=""
for cand in "${KAI_SUITE_ROOT:-}/envs/shared.env.example" "$ROOT/../kai/envs/shared.env.example" "$ROOT/../kai-suite/envs/shared.env.example"; do
  if [[ -f "$cand" ]]; then
    SUITE_SHARED="$cand"
    break
  fi
done
if [[ -n "$SUITE_SHARED" ]]; then
  for key in JWT_SECRET JWT_REFRESH_SECRET JWT_EXPIRES_IN JWT_REFRESH_EXPIRES_IN FISCAL_ENCRYPTION_KEY; do
    if [[ -z "$(env_get "$DEST" "$key")" ]]; then
      val="$(env_get "$SUITE_SHARED" "$key")"
      [[ -n "$val" ]] && set_kv "$DEST" "$key" "$val"
    fi
  done
fi

echo "[render-tenant-env] actualizado: $DEST"
