#!/usr/bin/env bash
# Dev local de un tenant (como instancia): materializa .env, BD, proyecta a kai-suite y levanta apps.
#
# Uso:
#   ./_shared/scripts/dev-tenant.sh kai-suite-demo
#   ./_shared/scripts/dev-tenant.sh kai-suite-demo --seed
#   ./_shared/scripts/dev-tenant.sh kai-suite-demo --apps-only
#   ./_shared/scripts/dev-tenant.sh kai-suite-demo --no-infra --no-migrate
#
# Builds viven en kai-suite; este repo solo orquesta config/datos.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REG_JS="$ROOT/_shared/lib/registry.cjs"
VALIDATE="$ROOT/_shared/scripts/validate-tenants-registry.sh"
RENDER="$ROOT/_shared/scripts/render-tenant-env.sh"
PROVISION_DB="$ROOT/_shared/scripts/provision-tenant-db.sh"

TENANT=""
DO_INFRA=true
DO_MIGRATE=true
DO_SEED=false
APPS_ONLY=false

usage() {
  echo "Uso: $0 <tenant-id> [--seed] [--no-infra] [--no-migrate] [--apps-only]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed) DO_SEED=true; shift ;;
    --no-infra) DO_INFRA=false; shift ;;
    --no-migrate) DO_MIGRATE=false; shift ;;
    --apps-only) APPS_ONLY=true; DO_INFRA=false; DO_MIGRATE=false; DO_SEED=false; shift ;;
    --help|-h) usage; exit 0 ;;
    -*)
      echo "Flag desconocido: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -z "$TENANT" ]]; then
        TENANT="$1"
      else
        echo "Argumento extra: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$TENANT" ]]; then
  usage >&2
  exit 1
fi

resolve_suite_root() {
  if [[ -n "${KAI_SUITE_ROOT:-}" && -d "$KAI_SUITE_ROOT" ]]; then
    echo "$(cd "$KAI_SUITE_ROOT" && pwd)"
    return
  fi
  for cand in "$ROOT/../kai" "$ROOT/../kai-suite"; do
    if [[ -f "$cand/package.json" && -d "$cand/kai-core" ]]; then
      echo "$(cd "$cand" && pwd)"
      return
    fi
  done
  echo "" 
}

SUITE="$(resolve_suite_root)"
if [[ -z "$SUITE" ]]; then
  echo "[dev-tenant] No se encontró kai-suite (KAI_SUITE_ROOT o ../kai)." >&2
  exit 1
fi

echo "==> dev-tenant: $TENANT"
echo "    deployments: $ROOT"
echo "    suite:       $SUITE"

bash "$VALIDATE"

FOLDER="$(TENANTS_REGISTRY="${TENANTS_REGISTRY:-$ROOT/tenants-registry.json}" node "$REG_JS" folder "$TENANT")"
TENANT_ENV="$ROOT/$FOLDER/.env"

bash "$RENDER" "$TENANT"

if [[ "$APPS_ONLY" != true ]]; then
  bash "$PROVISION_DB" "$TENANT"
fi

if [[ "$DO_INFRA" == true ]]; then
  echo "==> Infra (suite dev-infra)"
  bash "$SUITE/scripts/dev-infra.sh"
fi

echo "==> Proyectar envs → suite (KAI_ENV_MATRIX=$TENANT_ENV)"
KAI_ENV_MATRIX="$TENANT_ENV" bash "$SUITE/envs/sync-dev-envs.sh" --force

tenant_db_has_schema() {
  local db_host db_port db_user db_name db_pass
  db_host="$(grep -E '^DB_HOST=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2-)"
  db_host="${db_host:-localhost}"
  db_port="$(grep -E '^DB_PORT=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2-)"
  db_port="${db_port:-5432}"
  db_user="$(grep -E '^DB_USERNAME=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2-)"
  db_name="$(grep -E '^DB_DATABASE=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2-)"
  db_pass="$(grep -E '^DB_PASSWORD=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2-)"
  db_pass="${db_pass:-kai123}"
  [[ -n "$db_user" && -n "$db_name" ]] || return 1
  command -v psql >/dev/null 2>&1 || return 0
  PGPASSWORD="$db_pass" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -tAc \
    "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='companies' LIMIT 1" \
    2>/dev/null | grep -q 1
}

SEED_SYNCHRONIZE=false
if [[ "$DO_MIGRATE" == true ]] && ! tenant_db_has_schema; then
  echo "==> BD sin esquema — omitiendo migration:run (seed usará DB_SYNCHRONIZE=true)"
  DO_MIGRATE=false
  SEED_SYNCHRONIZE=true
fi

if [[ "$DO_MIGRATE" == true ]]; then
  echo "==> Migraciones kai-core"
  if ! (cd "$SUITE/kai-core" && npm run migration:run); then
    if tenant_db_has_schema; then
      echo "==> migration:run falló con esquema existente — baseline dev (DB_SYNCHRONIZE)"
      (cd "$SUITE/kai-core" && npm run migration:baseline)
    else
      exit 1
    fi
  fi
fi

if [[ "$DO_SEED" == true ]]; then
  PROFILE="$(grep -E '^KAI_SEED_PROFILE=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)"
  PROFILE="${PROFILE:-demo}"
  echo "==> Seed profile=$PROFILE (DB del tenant vía kai-core/.env)"
  case "$PROFILE" in
    demo|kaifood|food|suite)
      if [[ "$SEED_SYNCHRONIZE" == true ]]; then
        (cd "$SUITE" && DB_SYNCHRONIZE=true npm run seed:demo)
        echo "==> Baseline migraciones post-sync"
        (cd "$SUITE/kai-core" && npm run migration:baseline)
      else
        (cd "$SUITE" && npm run seed:demo)
      fi
      ;;
    barco)
      (cd "$SUITE" && npm run seed:barco)
      ;;
    velarys)
      (cd "$SUITE" && npm run seed:velarys)
      ;;
    mias)
      (cd "$SUITE" && npm run seed:mias)
      ;;
    joyarte)
      (cd "$SUITE" && npm run seed:joyarte)
      ;;
    *)
      echo "[dev-tenant] seed.profile desconocido ($PROFILE); corré seed manualmente" >&2
      ;;
  esac
fi

echo ""
echo "==> Apps (matriz tenant)"
echo "    Ctrl+C detiene las apps; infra (Postgres/Redis) sigue arriba."
echo ""
export KAI_ENV_MATRIX="$TENANT_ENV"
exec bash "$SUITE/scripts/dev-apps.sh"
