#!/usr/bin/env bash
# Dev local de un tenant (como instancia): materializa .env, BD, proyecta a kai-suite y levanta apps.
#
# Uso:
#   ./_shared/scripts/dev-tenant.sh kai-food-demo
#   ./_shared/scripts/dev-tenant.sh kai-food-demo --seed
#   ./_shared/scripts/dev-tenant.sh kai-food-demo --apps-only
#   ./_shared/scripts/dev-tenant.sh kai-food-demo --no-infra --no-migrate
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

if [[ "$DO_MIGRATE" == true ]]; then
  echo "==> Migraciones kai-core"
  (cd "$SUITE/kai-core" && npm run migration:run)
fi

if [[ "$DO_SEED" == true ]]; then
  PROFILE="$(grep -E '^KAI_SEED_PROFILE=' "$TENANT_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)"
  PROFILE="${PROFILE:-demo}"
  echo "==> Seed profile=$PROFILE (DB del tenant vía kai-core/.env)"
  case "$PROFILE" in
    demo|kaifood|food)
      (cd "$SUITE" && npm run seed:demo)
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
