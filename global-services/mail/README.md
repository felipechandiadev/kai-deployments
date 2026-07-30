# global-services/mail

**Código:** [`kai-suite/services/kai-mail`](https://github.com/felipechandiadev/kai-suite) — Nest + BullMQ + Redis + Nodemailer.  
**Config ops:** `sharedServices.mail` + opcional `tenants[].mail` en el Tenant Registry.

Kai-mail puede correr en dos modos. El default del host es **compartido**; un tenant puede declarar **dedicated**.

## Modos

| Modo | Registry | Runtime | `KAI_MAIL_URL` del backend | Cola BullMQ |
|------|----------|---------|----------------------------|-------------|
| **shared** (recomendado) | `sharedServices.mail` + `tenants[].mail.mode: "shared"` (o omitir `mail`) | 1× proceso en el host (`:5040`) | URL de `sharedServices.mail.url` | `mail-send` global |
| **dedicated** (viable) | `tenants[].mail.mode: "dedicated"` + `url` o `port` | 1 kai-mail **por tenant** | URL/puerto del tenant | Idealmente cola/prefijo propio (pendiente en el servicio Nest) |

Secrets (`MAIL_FROM`, SMTP, `KAI_MAIL_API_KEY`) → `.env` del sidecar / tenant, **nunca** el registry.

### Cuándo usar cada uno

- **shared:** demos, pocos clientes, mismo SMTP/From genérico, ahorro de RAM (un Nest).
- **dedicated:** From/SMTP por marca, compliance, aislamiento fuerte de cola/credenciales.

### Ejemplo dedicated en el registry

```json
"mail": {
  "mode": "dedicated",
  "url": "http://localhost:5240",
  "port": 5240
}
```

El puerto dedicated no debe chocar con `tenants[].ports` ni con otros dedicated (el validador lo comprueba).

## Compartido (recomendado) — detalle

Todos los backends apuntan a `http://localhost:5040` (o la URL del host).

- Cola: `mail-send`.
- Redis: `global-services/redis`.
- Ops: este folder + `npm run mail:dev` / compose en kai-suite.

## Individual (dedicated) — detalle

1. Declarar `mail.mode: "dedicated"` + `url`/`port` en el tenant.
2. Levantar otro proceso kai-mail (mismo binario del suite) en ese puerto.
3. En el `.env` del backend del tenant: `KAI_MAIL_URL` = esa URL.
4. SMTP/`MAIL_FROM` propios en el `.env` de ese sidecar.

Hasta que exista prefijo de cola en Nest, **no** compartas el mismo Redis+cola `mail-send` entre dos workers dedicated sin aislamiento; usá Redis DB distinta o instancia Redis aparte, o aceptá el riesgo en demos.

## Cómo levantarlo (shared)

```bash
# en kai-suite
npm run mail:dev
# docker compose -f services/kai-mail/docker-compose.mail.yml up -d
```

Docs: `kai-suite/docs/apps/SERVICES-SIDECARS.md`, `services/kai-mail/README.md`.

## Puertos de referencia

| Servicio | Puerto |
|----------|--------|
| kai-mail shared (API) | **5040** |
| Mailpit UI / SMTP (dev) | **8025** / **1025** |
| dedicated (ejemplo) | bloque del tenant, p. ej. **5240** |
