# services/postgres

Base de datos Postgres 16 para Masivos.app. Servicio independiente: puede ejecutarse solo (`docker compose -f docker-compose.yml up -d`) o como parte del stack completo vía [`docker/compose/docker-compose.yml`](../../docker/compose/docker-compose.yml).

> **Nota abierta:** este servicio es un componente Postgres genérico y completo. Aún no está confirmado si Postal (Sprint 7) puede usarlo directamente como su base de datos interna — el proyecto Postal ha requerido tradicionalmente MySQL/MariaDB. Esa decisión se revisa explícitamente al construir `services/postal/`.

## Qué hace

- Postgres 16 (Debian), sin puertos publicados al host — solo alcanzable desde `masivos-network`.
- Configuración de producción en [`config/postgresql.conf`](config/postgresql.conf) y [`config/pg_hba.conf`](config/pg_hba.conf) (montadas de solo lectura, cargadas explícitamente vía `-c config_file=...`).
- Extensiones base (`pgcrypto`, `uuid-ossp`, `pg_stat_statements`) en [`init/00-extensions.sql`](init/00-extensions.sql).
- Healthcheck (`pg_isready`) y límites de recursos configurables por `.env`.

## Cómo instalarlo

```bash
cp services/postgres/.env.example services/postgres/.env
# editar services/postgres/.env: POSTGRES_PASSWORD, y limites si el
# servidor no es el sizing de referencia (ver docs/architecture.md)
docker compose --env-file services/postgres/.env -f services/postgres/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes (crea `masivos-network` y el volumen `masivos-postgres-data`).

## Cómo actualizarlo

Cambiar la versión de imagen en `docker-compose.yml` y ejecutar `docker compose ... up -d` vuelve a crear el contenedor preservando el volumen de datos. Para cambios de configuración (`postgresql.conf`/`pg_hba.conf`), basta con `docker compose ... restart postgres` — no requiere recrear el contenedor.

## Cómo respaldarlo

```bash
./services/postgres/backup/backup-postgres.sh --environment prod
```

Genera un dump en formato custom (`pg_dump -Fc`) en `backups/<env>/postgres/`, y aplica la retención definida en `POSTGRES_BACKUP_RETENTION_DAYS` (`.env`). `backups/` está excluido de Git (`.gitignore`) — es responsabilidad del operador copiarlo a almacenamiento externo (fuera del alcance de este sprint; se abordará en `scripts/backup.sh`, Sprint 11, como orquestador de todos los backups de servicios).

## Cómo restaurarlo

```bash
./services/postgres/backup/restore-postgres.sh --environment prod --file backups/prod/postgres/postgres_masivos_20260101T000000Z.dump --force
```

**Destructivo** (`pg_restore --clean --if-exists`): sobreescribe la base de datos actual. El flag `--force` es obligatorio a propósito — el script se niega a ejecutar sin él.

## Cómo monitorearlo

Verificación básica manual:

```bash
docker exec masivos-postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
docker exec -it masivos-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM pg_stat_activity;"
docker exec -it masivos-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

`pg_stat_statements` ya está habilitado (ver `postgresql.conf`) para que Prometheus (`services/prometheus`, Sprint 9) pueda scrapear métricas de consultas vía `postgres_exporter` sin reconfigurar nada entonces.
