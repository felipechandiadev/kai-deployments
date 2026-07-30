# global-services/mail

**Runtime:** un sidecar **kai-mail** por host (correo transaccional).  
**Código:** [`kai-suite/services/kai-mail`](https://github.com/felipechandiadev/kai-suite) — Nest + BullMQ + Redis + Nodemailer.

## Compartido

Todos los backends de todos los tenants apuntan al mismo `KAI_MAIL_URL` (`sharedServices.mail` en el registry), tipicamente `http://localhost:5040`.

- Cola BullMQ fija: `mail-send` (correcta con **un** mail sidecar).
- API key: `KAI_MAIL_API_KEY` (misma en Core y en el sidecar; no en el registry).
- Redis: el de `global-services/redis` (BullMQ).

No levantar un kai-mail por tenant salvo requisito de aislamiento SMTP/compliance.

## Cómo levantarlo

Preferible desde el monorepo (workspace npm):

```bash
# en kai-suite
npm run mail:dev
# o build + compose del servicio:
# docker compose -f services/kai-mail/docker-compose.mail.yml up -d
```

Docs: `kai-suite/docs/apps/SERVICES-SIDECARS.md`, `services/kai-mail/README.md`.

El stub de este folder solo fija el contrato de puerto/env para ops del VPS.

## Puerto

**5040** (HTTP API). Mailpit local (dev): UI **8025**, SMTP **1025**.
