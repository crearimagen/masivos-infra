# scripts/

Orquestación de todo el stack, sobre lo ya construido en `bootstrap/`, `security/`, `docker/` y cada `services/<nombre>/`. Ningún script aquí implementa lógica nueva de un servicio — todos delegan en los scripts ya existentes de cada componente.

## Componentes

| Script | Qué hace |
|---|---|
| `deploy.sh` | Despliegue completo: bootstrap → hardening → docker → certificados → stack principal → Postal. |
| `update.sh` | `docker compose pull` + `up -d`, para un servicio o para todo el stack principal. |
| `rollback.sh` | Revierte el `docker-compose.yml` de **un** servicio a una referencia de Git anterior. No revierte datos ni migraciones — ver limitación documentada en el script. |
| `backup.sh` | Orquesta `backup-postgres.sh` + `backup-mariadb.sh` (los únicos servicios con backup implementado). |
| `restore.sh` | Envuelve `restore-postgres.sh`/`restore-mariadb.sh`. Destructivo, requiere `--force`. |
| `healthcheck.sh` | Reporta el estado de `docker healthcheck` de todos los contenedores `masivos-*`. |
| `validate.sh` | Valida el stack completo: Docker, salud de contenedores, DNS real, expiración de certificado, reglas de UFW. |

## Uso típico

**Servidor nuevo:**

```bash
sudo ./scripts/deploy.sh --environment prod
# seguir el recordatorio final: crear el primer admin de Postal (paso manual)
./scripts/validate.sh --environment prod
```

**Actualizar una versión ya desplegada:**

```bash
sudo ./scripts/update.sh --environment prod --service postgres
```

**Backup programado (cron):**

```bash
0 3 * * * /ruta/al/repo/scripts/backup.sh --environment prod >> /var/log/masivos/backup-cron.log 2>&1
```

## Qué NO hace este sprint

- No automatiza `postal make-user` (interactivo por diseño de Postal, ver `services/postal/README.md`).
- No automatiza la creación de monitores de Uptime Kuma (sin API declarativa, ver `services/uptime-kuma/README.md`).
- No implementa backup/restore de `redis`, `rabbitmq` ni `postal` — no existen en esos servicios (decisiones de sus sprints respectivos), y `backup.sh`/`restore.sh` no fabrican soporte para ellos.
- `rollback.sh` no revierte datos — solo la definición del contenedor (imagen, config).

## Logs

Todos los scripts usan `bootstrap/lib.sh` — mismo formato y destino (`/var/log/masivos/bootstrap.log`) que `bootstrap/`, `security/` y `docker/`.

## Códigos de salida

Idénticos al resto del repositorio — ver [`bootstrap/README.md`](../bootstrap/README.md#códigos-de-salida).
