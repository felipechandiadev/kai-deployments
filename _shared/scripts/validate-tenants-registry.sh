#!/usr/bin/env bash
# Valida tenants-registry.json: ids, puertos, database, redisKeyPrefix, mail.mode, sharedServices.
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

for (const key of ["postgres", "redis", "osrm", "mail"]) {
  if (!shared[key] || typeof shared[key] !== "object") {
    errors.push(`sharedServices.${key} es obligatorio`);
  }
}

const sharedMail = shared.mail || {};
if (sharedMail.mode && !["shared", "dedicated"].includes(sharedMail.mode)) {
  errors.push(`sharedServices.mail.mode inválido: ${sharedMail.mode}`);
}
if (typeof sharedMail.url !== "string" || !sharedMail.url) {
  errors.push("sharedServices.mail.url es obligatorio");
}

const ids = new Set();
const portOwners = new Map();
const dbNames = new Set();
const redisPrefixes = new Set();

function claimPort(port, owner) {
  if (typeof port !== "number" || !Number.isInteger(port)) {
    errors.push(`${owner}: puerto inválido (${port})`);
    return;
  }
  const prev = portOwners.get(port);
  if (prev) errors.push(`colisión puerto ${port}: ${prev} y ${owner}`);
  else portOwners.set(port, owner);
}

if (typeof sharedMail.port === "number") {
  claimPort(sharedMail.port, "sharedServices.mail");
}

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

  const mail = t.mail;
  if (mail != null) {
    if (typeof mail !== "object") {
      errors.push(`${t.id}: mail debe ser objeto`);
    } else {
      const mode = mail.mode ?? "shared";
      if (!["shared", "dedicated"].includes(mode)) {
        errors.push(`${t.id}: mail.mode inválido (${mode})`);
      }
      if (mode === "dedicated") {
        const hasUrl = typeof mail.url === "string" && mail.url.length > 0;
        const hasPort = typeof mail.port === "number" && Number.isInteger(mail.port);
        if (!hasUrl && !hasPort) {
          errors.push(`${t.id}: mail dedicated requiere url o port`);
        }
        if (hasPort) claimPort(mail.port, `${t.id}/mail`);
      }
    }
  }

  const ports = t.ports || {};
  for (const [app, port] of Object.entries(ports)) {
    if (port == null) continue;
    claimPort(port, `${t.id}/${app}`);
  }

  const apps = t.apps;
  if (apps != null) {
    if (Array.isArray(apps)) {
      errors.push(
        `${t.id}: apps debe ser objeto { web, native } (no array plano)`,
      );
    } else if (typeof apps !== "object") {
      errors.push(`${t.id}: apps inválido`);
    } else {
      if (apps.web != null) {
        if (!Array.isArray(apps.web) || !apps.web.every((x) => typeof x === "string")) {
          errors.push(`${t.id}: apps.web debe ser string[]`);
        }
      }
      if (apps.native != null) {
        if (!Array.isArray(apps.native)) {
          errors.push(`${t.id}: apps.native debe ser array`);
        } else {
          const nativeIds = new Set();
          const allowedPlatforms = new Set([
            "android",
            "windows",
            "macos",
            "linux",
            "ios",
          ]);
          for (const n of apps.native) {
            if (!n || typeof n !== "object" || typeof n.id !== "string" || !n.id) {
              errors.push(`${t.id}: apps.native[] requiere id`);
              continue;
            }
            if (nativeIds.has(n.id)) {
              errors.push(`${t.id}: apps.native id duplicado (${n.id})`);
            }
            nativeIds.add(n.id);
            if (!Array.isArray(n.platforms) || n.platforms.length === 0) {
              errors.push(`${t.id}: apps.native.${n.id} requiere platforms[]`);
            } else {
              for (const p of n.platforms) {
                if (!allowedPlatforms.has(p)) {
                  errors.push(
                    `${t.id}: apps.native.${n.id} plataforma inválida (${p})`,
                  );
                }
              }
            }
          }
        }
      }
    }
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
