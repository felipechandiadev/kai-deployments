# kai-deployments

Configuración e orquestación **por cliente** (single-tenant / multi-instance) para la plataforma Kai.

El código de producto vive en [`kai-suite`](https://github.com/felipechandiadev/kai-suite).  
Este repo solo define **cómo corre cada instancia** (puertos, dominios, compose/PM2, env examples).

## Estructura

```text
clients/
  demo/            # Ambiente demo (kaisuite.pro)
  joyarte/
  san-sebastian/
global/            # Scripts / plantillas compartidas (opcional)
```

## Reglas

- **No** subir `.env` reales, certificados ni dumps de BD.
- Usar `.env.example` y secretos en el VPS / vault.
- Backups → object storage (`s3://…`), nunca Git.
- Apuntar a imágenes o checkout de `kai-suite` versionado (tags), no copiar el monorepo aquí.

## Desarrollo local

Abrí el workspace multi-root `kai-platform.code-workspace` desde `kai-suite` para ver ambos repos en Cursor:

- `kai-suite` → código
- `kai-deployments` → este repo (hermano: `../kai-deployments`)

## Relación con kai-suite

| En kai-suite | En kai-deployments |
|--------------|--------------------|
| `deploy/` (bootstrap VPS, ports demo example) | Estado por cliente en `clients/*` |
| `envs/`, `seeds/` (producto / fixtures) | Overrides y secretos de instancia |
