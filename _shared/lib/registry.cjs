#!/usr/bin/env node
/**
 * Helpers Tenant Registry (kai-deployments).
 * Uso:
 *   node registry.mjs get <tenant-id>           → JSON del tenant
 *   node registry.mjs deploy-apps <tenant-id>   → lista comma-separated
 *   node registry.mjs env-vars <tenant-id>      → KEY=value (topología, sin secretos)
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "../..");
const REG =
  process.env.TENANTS_REGISTRY ||
  path.join(ROOT, "tenants-registry.json");

function loadRegistry() {
  if (!fs.existsSync(REG)) {
    console.error(`No existe ${REG}`);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(REG, "utf8"));
}

function findTenant(data, id) {
  const t = (data.tenants || []).find((x) => x.id === id);
  if (!t) {
    console.error(`Tenant no encontrado: ${id}`);
    process.exit(1);
  }
  if (t.active === false) {
    console.error(`Tenant inactivo: ${id}`);
    process.exit(1);
  }
  return t;
}

const WEB_ORDER = [
  "backend",
  "admin",
  "pos",
  "stock",
  "eshop",
  "delivery",
  "waiter",
  "kds",
  "board",
  "mail",
  "voice",
  "landing",
];

function deployAppsFromWeb(web) {
  const apps = [];
  for (const key of WEB_ORDER) {
    if (web && web[key] === true) apps.push(key);
  }
  // Sidecar mail: no vive en apps.web del registry; se activa con backend.
  if (web && web.backend === true && !apps.includes("mail")) {
    apps.push("mail");
  }
  return apps.join(",");
}

function envVarsFromTenant(data, t) {
  const shared = data.sharedServices || {};
  const host = process.env.KAI_DEV_HOST || "localhost";
  const ports = t.ports || {};
  const db = t.database || {};
  const web = (t.apps && t.apps.web) || {};

  const backendPort = ports.backend ?? 5160;
  const lines = [];
  const put = (k, v) => {
    if (v === undefined || v === null || v === "") return;
    lines.push(`${k}=${v}`);
  };

  put("KAI_PRODUCT", t.product || "kaistore");
  put(
    "LANDING_PRODUCT",
    t.product === "kaifood" ? "food" : "store",
  );
  put("KAI_DEV_HOST", host);
  put("KAI_DEPLOY_APPS", deployAppsFromWeb(web));
  put("KAI_DEPLOY_PROFILE", "retail-full");

  put("DB_HOST", (shared.postgres && shared.postgres.host) || "localhost");
  put("DB_PORT", (shared.postgres && shared.postgres.port) || 5432);
  put("DB_USERNAME", db.user || db.name);
  put("DB_DATABASE", db.name);

  put("REDIS_HOST", (shared.redis && shared.redis.host) || "localhost");
  put("REDIS_PORT", (shared.redis && shared.redis.port) || 6379);
  put("REDIS_KEY_PREFIX", t.redisKeyPrefix);

  put("OSRM_URL", (shared.osrm && shared.osrm.url) || "http://localhost:5001");
  put("KAI_MAIL_URL", (shared.mail && shared.mail.url) || "http://localhost:5040");
  put("KAI_MAIL_PORT", (shared.mail && shared.mail.port) || 5040);
  put("KAI_VOICE_URL", (shared.voice && shared.voice.url) || "http://localhost:5041");
  put("KAI_VOICE_PORT", (shared.voice && shared.voice.port) || 5041);

  put("KAI_BACKEND_PORT", ports.backend);
  put("KAI_ADMIN_PORT", ports.admin);
  put("KAI_POS_PORT", ports.pos);
  put("KAI_STOCK_PORT", ports.stock);
  put("KAI_ESHOP_PORT", ports.eshop);
  put("KAI_DELIVERY_PORT", ports.delivery);
  put("KAI_LANDING_PORT", ports.landing);
  put("KAI_WAITER_PORT", ports.waiter);
  put("KAI_KDS_PORT", ports.kds);
  put("KAI_BOARD_PORT", ports.board);

  put("KAI_BACKEND_URL", `http://${host}:${backendPort}`);
  put("BACKEND_API_URL", `http://${host}:${backendPort}`);
  put("NEXT_PUBLIC_BACKEND_API_URL", `http://${host}:${backendPort}`);

  if (ports.admin != null) {
    put("ADMIN_NEXTAUTH_URL", `http://${host}:${ports.admin}`);
  }
  if (ports.pos != null) {
    put("POS_NEXTAUTH_URL", `http://${host}:${ports.pos}`);
  }
  if (ports.stock != null) {
    put("STOCK_NEXTAUTH_URL", `http://${host}:${ports.stock}`);
  }
  if (ports.eshop != null) {
    put("NEXT_PUBLIC_ESHOP_SITE_URL", `http://${host}:${ports.eshop}`);
  }

  put("KAI_FEATURE_JEWELRY", web.eshop ? "false" : "false");
  put("KAI_FEATURE_ESHOP", web.eshop === true ? "true" : "false");
  put("KAI_FEATURE_POS", web.pos === true ? "true" : "false");
  put("KAI_FEATURE_STOCK", web.stock === true ? "true" : "false");
  put("KAI_FEATURE_KAI_MAIL", "true");
  put("KAI_FEATURE_MULTI_COMPANY", "true");

  if (t.seed && t.seed.profile) {
    put("KAI_SEED_PROFILE", t.seed.profile);
  }

  put("NODE_ENV", "development");
  return lines.join("\n");
}

const [cmd, tenantId] = process.argv.slice(2);
if (!cmd || !tenantId) {
  console.error(
    "Uso: registry.mjs get|deploy-apps|env-vars|folder <tenant-id>",
  );
  process.exit(1);
}

const data = loadRegistry();
const t = findTenant(data, tenantId);

switch (cmd) {
  case "get":
    process.stdout.write(JSON.stringify(t, null, 2) + "\n");
    break;
  case "deploy-apps":
    process.stdout.write(
      deployAppsFromWeb((t.apps && t.apps.web) || {}) + "\n",
    );
    break;
  case "env-vars":
    process.stdout.write(envVarsFromTenant(data, t) + "\n");
    break;
  case "folder":
    process.stdout.write((t.folder || `tenants/${t.id}`) + "\n");
    break;
  case "db":
    process.stdout.write(
      JSON.stringify(
        {
          name: t.database && t.database.name,
          user: (t.database && t.database.user) || (t.database && t.database.name),
          host: (data.sharedServices.postgres && data.sharedServices.postgres.host) || "localhost",
          port: (data.sharedServices.postgres && data.sharedServices.postgres.port) || 5432,
        },
        null,
        2,
      ) + "\n",
    );
    break;
  default:
    console.error(`Comando desconocido: ${cmd}`);
    process.exit(1);
}
