# services/mariadb

Base de datos MariaDB 11.4 — el motor real que usa Postal. Servicio independiente: puede ejecutarse solo (`docker compose -f docker-compose.yml up -d`) o como parte del stack completo vía [`docker/compose/docker-compose.yml`](../../docker/compose/docker-compose.yml).

## Por qué existe este servicio (y no se usa `services/postgres/`)

El stack original de este repositorio listaba PostgreSQL. Al llegar al Sprint 7 (`services/postal/`) verifiqué contra la documentación oficial de Postal, en vez de asumir, y confirmé:

- **Postal v3 (la versión estable actual, desde marzo 2024) requiere MariaDB 10.6+.** Su propia documentación dice explícitamente: *"We do not support using MySQL in place of MariaDB."* PostgreSQL no aparece como opción soportada en ningún lado.
- **Postal v3 no usa RabbitMQ.** Esa dependencia se eliminó del proyecto en la migración a v3 — la cola de mensajes ahora es gestionada por la propia base de datos (`worker` procesa mensajes bloqueados en `message_db`).
- **Postal v3 no usa Redis** en su configuración de referencia (`postal.yml`).

Fuentes: [Pre-requisites — Postal docs](https://docs.postalserver.io/getting-started/prerequisites/), [`doc/config/yaml.yml` del repo oficial](https://github.com/postalserver/postal/blob/main/doc/config/yaml.yml), [Upgrading to v3 — Postal docs](https://docs.postalserver.io/getting-started/upgrade-to-v3/).

`services/postgres/`, `services/redis/` y `services/rabbitmq/` (Sprints 4-6) se conservan en el repositorio como infraestructura general — están completos, correctos, y disponibles para lo que se necesite en el futuro que no sea Postal — pero **Postal se conecta exclusivamente a este servicio.**

## Qué hace

- MariaDB 11.4, sin puertos publicados al host — solo alcanzable desde `masivos-network`.
- `init/00-create-postal-user.sh` crea un usuario dedicado (`POSTAL_DB_USER`) con privilegios sobre cualquier base de datos que empiece con `POSTAL_DB_PREFIX` — **no un solo nombre de base fijo**, porque Postal aprovisiona automáticamente una base de datos nueva (`message_db`) por cada "mail server" que se crea dentro de él, además de su `main_db`. El usuario necesita poder crear y borrar esas bases dinámicamente (requisito explícito de la documentación de Postal).
- `config/masivos.cnf`: `innodb_redo_log_capacity` fijado con margen amplio sobre el mínimo que Postal exige (10× el tamaño máximo de mensaje configurado — ver comentarios en el archivo), charset `utf8mb4`.
- Healthcheck vía `mariadb-admin ping`.

## Cómo instalarlo

```bash
cp services/mariadb/.env.example services/mariadb/.env
# editar services/mariadb/.env: MARIADB_ROOT_PASSWORD, POSTAL_DB_PASSWORD
docker compose --env-file services/mariadb/.env -f services/mariadb/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes (crea `masivos-network` y el volumen `masivos-mariadb-data`, este último añadido en el Sprint 7 — ver [`docs/architecture.md`](../../docs/architecture.md#modelo-de-volúmenes)).

## Cómo actualizarlo

Cambiar la versión de imagen en `docker-compose.yml` y ejecutar `docker compose ... up -d` recrea el contenedor preservando el volumen de datos. Para cambios de `config/masivos.cnf`, `docker compose ... restart mariadb` es suficiente.

## Cómo respaldarlo

```bash
./services/mariadb/backup/backup-mariadb.sh --environment prod
```

Genera un volcado comprimido (`mariadb-dump --all-databases | gzip`) en `backups/<env>/mariadb/` — se usa `--all-databases` en vez de un nombre fijo porque Postal crea bases de datos dinámicamente. Aplica la retención de `MARIADB_BACKUP_RETENTION_DAYS`.

## Cómo restaurarlo

```bash
./services/mariadb/backup/restore-mariadb.sh --environment prod --file backups/prod/mariadb/mariadb_all_20260101T000000Z.sql.gz --force
```

**Destructivo**: sobreescribe/crea bases de datos con los mismos nombres que contiene el dump. El flag `--force` es obligatorio a propósito.

## Cómo monitorearlo

```bash
docker exec masivos-mariadb mariadb-admin -uroot -p"$MARIADB_ROOT_PASSWORD" status
docker exec -it masivos-mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW PROCESSLIST;"
docker exec -it masivos-mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '${POSTAL_DB_PREFIX}%';"
```

Métricas vía Prometheus (`mysqld_exporter`) se añaden en `services/prometheus` (Sprint 10).
