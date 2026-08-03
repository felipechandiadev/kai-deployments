#!/usr/bin/env bash
# Verifica (y opcionalmente rsync) los binarios Kai Printers / CFD del POS
# según apps.native del tenant.
#
# Uso:
#   ./_shared/scripts/sync-tenant-pos-downloads.sh <tenant-id>
#   ./_shared/scripts/sync-tenant-pos-downloads.sh barco --dry-run
#   TENANT_POS_DOWNLOADS_RSYNC_TARGET=user@host:/path/kai-pos/public/downloads/ \
#     ./_shared/scripts/sync-tenant-pos-downloads.sh barco --rsync
#
# Local: todos los tenants comparten el mismo checkout kai-suite → un publish
# en kai-pos/public/downloads alcanza a todas las instancias.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REG_JS="$ROOT/_shared/lib/registry.cjs"

TENANT=""
DRY_RUN=false
DO_RSYNC=false

usage() {
  echo "Uso: $0 <tenant-id> [--dry-run] [--rsync]"
  echo "  --dry-run  Solo listar checks / URLs (default sin --rsync)"
  echo "  --rsync    Copiar manifests + binarios habilitados al destino remoto"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --rsync) DO_RSYNC=true; shift ;;
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

resolve_registry() {
  if [[ -n "${TENANTS_REGISTRY:-}" && -f "$TENANTS_REGISTRY" ]]; then
    echo "$TENANTS_REGISTRY"
    return
  fi
  if [[ -f "$ROOT/tenants-registry.json" ]]; then
    echo "$ROOT/tenants-registry.json"
    return
  fi
  if [[ -f "$ROOT/tenants-registry.example.json" ]]; then
    echo "$ROOT/tenants-registry.example.json"
    return
  fi
  echo ""
}

SUITE="$(resolve_suite_root)"
if [[ -z "$SUITE" ]]; then
  echo "[sync-pos-downloads] No se encontró kai-suite (KAI_SUITE_ROOT o ../kai)." >&2
  exit 1
fi

REG_FILE="$(resolve_registry)"
if [[ -z "$REG_FILE" ]]; then
  echo "[sync-pos-downloads] No hay tenants-registry.json ni example." >&2
  exit 1
fi

export TENANTS_REGISTRY="$REG_FILE"
DOWNLOADS="$SUITE/kai-pos/public/downloads"
if [[ ! -d "$DOWNLOADS" ]]; then
  echo "[sync-pos-downloads] No existe $DOWNLOADS" >&2
  exit 1
fi

TENANT_JSON="$(node "$REG_JS" get "$TENANT")"
HOST="${KAI_DEV_HOST:-localhost}"

read_json() {
  node -e "const t=JSON.parse(process.argv[1]); const path=process.argv[2].split('.'); let v=t; for (const k of path) { if (v==null) { process.exit(2); } v=v[k]; } if (v===undefined||v===null) process.exit(2); if (typeof v==='object') process.stdout.write(JSON.stringify(v)); else process.stdout.write(String(v));" "$TENANT_JSON" "$1" 2>/dev/null || true
}

POS_PORT="$(read_json ports.pos)"
POS_HOST_PUBLIC="$(read_json hosts.pos)"
PRINTERS_JSON="$(read_json apps.native.printers)"
CFD_JSON="$(read_json apps.native.cfd)"

if [[ -z "$PRINTERS_JSON" ]]; then
  PRINTERS_JSON='{}'
fi

echo "==> sync-tenant-pos-downloads: $TENANT"
echo "    registry:  $REG_FILE"
echo "    suite:     $SUITE"
echo "    downloads: $DOWNLOADS"
if [[ -n "$POS_PORT" && "$POS_PORT" != "null" ]]; then
  echo "    POS local: http://${HOST}:${POS_PORT}/downloads/"
fi
if [[ -n "$POS_HOST_PUBLIC" && "$POS_HOST_PUBLIC" != "null" ]]; then
  echo "    POS host:  https://${POS_HOST_PUBLIC}/downloads/"
fi
echo

FILES_TO_SYNC=()
MISSING=0

check_manifest_pair() {
  local label="$1"
  local manifest_name="$2"
  local enabled="$3"

  if [[ "$enabled" != "true" ]]; then
    echo "· $label: skip (registry=false)"
    return 0
  fi

  local manifest_path="$DOWNLOADS/$manifest_name"
  if [[ ! -f "$manifest_path" ]]; then
    echo "✗ $label: falta $manifest_name"
    MISSING=$((MISSING + 1))
    return 1
  fi

  local filename version
  filename="$(node -e "const m=require(process.argv[1]); if(!m.filename) process.exit(2); process.stdout.write(m.filename);" "$manifest_path")"
  version="$(node -e "const m=require(process.argv[1]); process.stdout.write(String(m.version||''));" "$manifest_path")"
  local bin_path="$DOWNLOADS/$filename"

  if [[ ! -f "$bin_path" ]]; then
    echo "✗ $label: manifest $version OK, falta binario $filename"
    MISSING=$((MISSING + 1))
    FILES_TO_SYNC+=("$manifest_name")
    return 1
  fi

  echo "✓ $label: v${version} → $filename"
  FILES_TO_SYNC+=("$manifest_name" "$filename")

  if [[ -n "$POS_PORT" && "$POS_PORT" != "null" ]]; then
    echo "    http://${HOST}:${POS_PORT}/downloads/${manifest_name}"
    echo "    http://${HOST}:${POS_PORT}/downloads/${filename}"
  fi
  if [[ -n "$POS_HOST_PUBLIC" && "$POS_HOST_PUBLIC" != "null" ]]; then
    echo "    https://${POS_HOST_PUBLIC}/downloads/${manifest_name}"
  fi
}

plat_enabled() {
  node -e "const p=JSON.parse(process.argv[1]||'{}'); process.exit(p[process.argv[2]]===true?0:1);" "$1" "$2"
}

if plat_enabled "$PRINTERS_JSON" android; then
  check_manifest_pair "printers/android" "kai-printers-android.manifest.json" true || true
else
  check_manifest_pair "printers/android" "kai-printers-android.manifest.json" false || true
fi

if plat_enabled "$PRINTERS_JSON" windows; then
  check_manifest_pair "printers/windows" "kai-printers-windows.manifest.json" true || true
else
  check_manifest_pair "printers/windows" "kai-printers-windows.manifest.json" false || true
fi

if plat_enabled "$PRINTERS_JSON" macos; then
  check_manifest_pair "printers/macos" "kai-printers-macos.manifest.json" true || true
else
  check_manifest_pair "printers/macos" "kai-printers-macos.manifest.json" false || true
fi

if [[ -n "$CFD_JSON" ]]; then
  if plat_enabled "$CFD_JSON" android; then
    check_manifest_pair "cfd/android" "kai-screen-android.manifest.json" true || true
  else
    check_manifest_pair "cfd/android" "kai-screen-android.manifest.json" false || true
  fi
fi

echo

load_rsync_target() {
  if [[ -n "${TENANT_POS_DOWNLOADS_RSYNC_TARGET:-}" ]]; then
    echo "$TENANT_POS_DOWNLOADS_RSYNC_TARGET"
    return
  fi
  local envf="$ROOT/tenants/$TENANT/.env"
  if [[ -f "$envf" ]]; then
    # shellcheck disable=SC1090
    set -a
    # solo la clave si existe
    local line
    line="$(grep -E '^[[:space:]]*TENANT_POS_DOWNLOADS_RSYNC_TARGET=' "$envf" | tail -n1 || true)"
    set +a
    if [[ -n "$line" ]]; then
      echo "${line#*=}" | sed 's/^["'\'']//;s/["'\'']$//'
      return
    fi
  fi
  echo ""
}

if [[ "$DO_RSYNC" == true ]]; then
  if [[ "$MISSING" -gt 0 ]]; then
    echo "[sync-pos-downloads] Hay artefactos faltantes; no se hace rsync." >&2
    exit 1
  fi
  TARGET="$(load_rsync_target)"
  if [[ -z "$TARGET" ]]; then
    echo "[sync-pos-downloads] Define TENANT_POS_DOWNLOADS_RSYNC_TARGET (env o tenants/$TENANT/.env)." >&2
    exit 1
  fi
  # Deduplicar lista (bash 3.2 compatible — macOS /bin/bash)
  UNIQUE_ARGS=()
  SEEN=""
  for f in "${FILES_TO_SYNC[@]}"; do
    case " $SEEN " in
      *" $f "*) continue ;;
    esac
    SEEN+=" $f"
    UNIQUE_ARGS+=("$f")
  done
  if [[ ${#UNIQUE_ARGS[@]} -eq 0 ]]; then
    echo "[sync-pos-downloads] Nada que sincronizar (ninguna plataforma habilitada)."
    exit 0
  fi
  echo "→ rsync → $TARGET"
  if [[ "$DRY_RUN" == true ]]; then
    echo "  (dry-run) archivos: ${UNIQUE_ARGS[*]}"
    exit 0
  fi
  (
    cd "$DOWNLOADS"
    rsync -avz "${UNIQUE_ARGS[@]}" "$TARGET"
  )
  echo "✅ rsync OK"
  exit 0
fi

if [[ "$MISSING" -gt 0 ]]; then
  echo "⚠ $MISSING artefacto(s) faltante(s)."
  echo "  Publicá desde kai-suite: npm run kai-printers:publish -- --windows-only"
  echo "  Ver: kai-pos/public/downloads/README.md"
  exit 1
fi

echo "✅ Descargas OK para $TENANT (checkout compartido kai-suite)."
echo "  Local no requiere copia; con --rsync subís binarios al VPS del tenant."
