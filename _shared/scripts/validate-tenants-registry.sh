#!/usr/bin/env bash
# Valida tenants-registry.json: ids, puertos, database.name, redisKeyPrefix, sharedServices.
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
const shared = data.sharedServices || {};
const errors = [];

for (const key of ["postgres", "redis", "osrm"]) {
  if (!shared[key] || typeof shared[key] !== "object") {
    errors.push(`sharedServices.${key} es obligatorio`);
  }
}

const ids = new Set();
const portOwners = new Map();
const dbNames = new Set();
const redisPrefixes = new Set();

for (const t of tenants) {
  if (!t.id) {
    errors.push("Tenant sin id");
    continue;
  }
  if (ids.has(t.id)) errors.push(`id duplicado: ${t.id}`);
  ids.add(t.id);

  if (!t.database || typeof t.database.name !== "string" || !t.database.name) {
    errors.push(`${t.id}: falta database.name`);
  } else {
    if (dbNames.has(t.database.name)) {
      errors.push(`database.name duplicado: ${t.database.name}`);
    }
    dbNames.add(t.database.name);
  }

  if (typeof t.redisKeyPrefix !== "string" || !t.redisKeyPrefix) {
    errors.push(`${t.id}: falta redisKeyPrefix`);
  } else {
    if (redisPrefixes.has(t.redisKeyPrefix)) {
      errors.push(`redisKeyPrefix duplicado: ${t.redisKeyPrefix}`);
    }
    redisPrefixes.add(t.redisKeyPrefix);
  }

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
  `OK ${file}: ${tenants.length} tenant(s), ${portOwners.size} puerto(s), ${dbNames.size} DB, ${redisPrefixes.size} redis prefix(es).`,
);
NODE
