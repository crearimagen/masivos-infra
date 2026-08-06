# .github/workflows/

CI (validación automática en cada push/PR) y CD manual (despliegue bajo demanda a un servidor ya provisionado).

## `lint.yml` — se ejecuta automáticamente

En cada `push`/`pull_request` a `main`:

- **`shellcheck`** sobre todos los `.sh` del repositorio (severidad `warning`).
- **`compose-config`** — valida la sintaxis de todos los `docker-compose.yml` con `docker compose config`. Genera `.env` temporales desde cada `.env.example` antes de validar (los `.env` reales están en `.gitignore` y no existen en un checkout de CI) — esto de paso detecta si un `docker-compose.yml` usa una variable que `.env.example` no define.
- **`yaml-and-json`** — `yamllint` sobre todo el YAML del repo, y validación de sintaxis de los `.json` (`docker/daemon.json`).

No requiere secretos ni configuración adicional — funciona en cualquier fork.

## `deploy.yml` — disparo manual (`workflow_dispatch`)

Ejecuta `git pull` + `scripts/deploy.sh --environment <env> --services-only` + `scripts/validate.sh` en el servidor de destino, vía SSH.

**Deliberadamente no se dispara en cada push** — un servidor de correo en producción no debe auto-desplegarse sin intervención humana. Desde la pestaña *Actions* del repo, `Run workflow` y elegir el entorno.

### Precondiciones (no las resuelve este workflow)

1. El servidor ya pasó por `bootstrap/install.sh`, `security/hardening.sh` y `docker/install.sh` al menos una vez, manualmente (ver [`scripts/README.md`](../scripts/README.md)) — este workflow usa `--services-only`, no reprovisiona el servidor desde cero.
2. El repositorio ya está clonado en el servidor, con `environments/<env>/.env` y cada `services/<nombre>/.env` ya configurados — esos archivos nunca están en Git.

### Secretos requeridos (Settings → Secrets and variables → Actions)

| Secreto | Descripción |
|---|---|
| `SSH_HOST` | IP o hostname del servidor |
| `SSH_PORT` | El mismo valor que `SSH_PORT` en `environments/<env>/.env` (Sprint 2) |
| `SSH_USER` | El mismo valor que `DEPLOY_USER` en `environments/<env>/.env` (Sprint 1) |
| `SSH_PRIVATE_KEY` | Clave privada correspondiente a la pública instalada por `bootstrap/users.sh` |
| `DEPLOY_PATH` | Ruta absoluta del repo clonado en el servidor (p.ej. `/opt/masivos-infra`) |

### Recomendado, no configurado por este workflow

Configura un **GitHub Environment** (`Settings → Environments`) llamado `prod` con *required reviewers* — así el despliegue a producción exige aprobación manual antes de correr, aunque el `workflow_dispatch` ya se haya lanzado. `dev`/`test` pueden quedar sin esa protección.

## Sin acciones de terceros

Todo el CI/CD usa únicamente `actions/checkout` (oficial de GitHub) y herramientas ya presentes en el runner (`shellcheck`, `docker compose`, `ssh`/`ssh-keyscan`) — ninguna acción de la comunidad sin auditar maneja la clave privada SSH ni ninguna otra credencial.
