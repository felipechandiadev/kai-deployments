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
  const WEB_KEYS = [
    "backend",
    "admin",
    "pos",
    "stock",
    "eshop",
    "delivery",
    "waiter",
    "kds",
    "board",
    "landing",
  ];
  const NATIVE_PLATFORMS = {
    printers: ["android", "windows", "macos"],
    cfd: ["android"],
  };

  if (apps == null || typeof apps !== "object" || Array.isArray(apps)) {
    errors.push(`${t.id}: apps debe ser objeto { web, native } con booleanos`);
  } else {
    const web = apps.web;
    if (!web || typeof web !== "object" || Array.isArray(web)) {
      errors.push(`${t.id}: apps.web debe ser mapa app → boolean`);
    } else {
      for (const key of WEB_KEYS) {
        if (!(key in web)) {
          errors.push(`${t.id}: apps.web falta clave "${key}"`);
        } else if (typeof web[key] !== "boolean") {
          errors.push(`${t.id}: apps.web.${key} debe ser true|false`);
        }
      }
      for (const key of Object.keys(web)) {
        if (!WEB_KEYS.includes(key)) {
          errors.push(`${t.id}: apps.web clave desconocida "${key}"`);
        }
      }
    }

    const native = apps.native;
    if (!native || typeof native !== "object" || Array.isArray(native)) {
      errors.push(`${t.id}: apps.native debe ser mapa id → { plataforma: boolean }`);
    } else {
      for (const [nid, platforms] of Object.entries(NATIVE_PLATFORMS)) {
        if (!(nid in native) || typeof native[nid] !== "object" || Array.isArray(native[nid])) {
          errors.push(`${t.id}: apps.native.${nid} requerido`);
          continue;
        }
        for (const p of platforms) {
          if (!(p in native[nid])) {
            errors.push(`${t.id}: apps.native.${nid} falta plataforma "${p}"`);
          } else if (typeof native[nid][p] !== "boolean") {
            errors.push(`${t.id}: apps.native.${nid}.${p} debe ser true|false`);
          }
        }
        for (const p of Object.keys(native[nid])) {
          if (!platforms.includes(p)) {
            errors.push(`${t.id}: apps.native.${nid} plataforma desconocida "${p}"`);
          }
        }
      }
      for (const nid of Object.keys(native)) {
        if (!(nid in NATIVE_PLATFORMS)) {
          errors.push(`${t.id}: apps.native id desconocido "${nid}"`);
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
