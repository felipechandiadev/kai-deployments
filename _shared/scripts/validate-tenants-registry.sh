#!/usr/bin/env bash
# Valida tenants-registry.json: ids únicos y puertos sin colisión entre tenants activos.
# Uso: ./_shared/scripts/validate-tenants-registry.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REG="${TENANTS_REGISTRY:-$ROOT/tenants-registry.json}"

if [[ ! -f "$REG" ]]; then
  echo "No existe $REG" >&2
  echo "Copiá la plantilla: cp tenants-registry.example.json tenants-registry.json" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Se necesita node para validar el JSON." >&2
  exit 1
fi

TENANTS_REGISTRY_PATH="$REG" node <<'NODE'
const fs = require("fs");
const file = process.env.TENANTS_REGISTRY_PATH;
const data = JSON.parse(fs.readFileSync(file, "utf8"));
const tenants = (data.tenants || []).filter((t) => t.active !== false);

const ids = new Set();
const portOwners = new Map();
const errors = [];

for (const t of tenants) {
  if (!t.id) {
    errors.push("Tenant sin id");
    continue;
  }
  if (ids.has(t.id)) errors.push(`id duplicado: ${t.id}`);
  ids.add(t.id);

  const ports = t.ports || {};
  for (const [app, port] of Object.entries(ports)) {
    if (port == null) continue;
    if (typeof port !== "number" || !Number.isInteger(port)) {
      errors.push(`${t.id}.${app}: puerto inválido (${port})`);
      continue;
    }
    const prev = portOwners.get(port);
    if (prev) errors.push(`colisión puerto ${port}: ${prev} y ${t.id}/${app}`);
    else portOwners.set(port, `${t.id}/${app}`);
  }
}

if (errors.length) {
  console.error("tenants-registry inválido:");
  for (const e of errors) console.error(" -", e);
  process.exit(1);
}

console.log(
  `OK ${file}: ${tenants.length} tenant(s) activo(s), ${portOwners.size} puerto(s) asignados.`,
);
NODE
