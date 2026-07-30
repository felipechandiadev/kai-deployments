# Plantilla docker-compose por tenant (futuro: imágenes versionadas desde kai-suite).
# Copiar a tenants/<id>/docker-compose.yml y fijar tags (ej. kai-backend:1.2.0).
#
# services:
#   backend:
#     image: ghcr.io/felipechandiadev/kai-backend:TAG
#     env_file: .env
#     restart: unless-stopped
#   # pwa-admin, pwa-pos, db, …
#
# networks:
#   default:
#     name: TENANT_net
