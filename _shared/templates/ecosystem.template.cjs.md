# Plantilla PM2 — copiar a tenants/<id>/ecosystem.config.cjs y ajustar name/puertos/cwd.
# Hoy el VPS suele usar suite compartida + ecosystem por tenant (ver docs/infra-futura-vps).
#
# module.exports = {
#   apps: [
#     {
#       name: 'TENANT-api',
#       cwd: '/path/to/kai-suite/backend',
#       script: 'dist/main.js',
#       env: { NODE_ENV: 'production' },
#       // env_file o dotenv según tu deploy.sh
#     },
#   ],
# };
