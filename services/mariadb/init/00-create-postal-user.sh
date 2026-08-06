#!/usr/bin/env bash
# services/mariadb/init/00-create-postal-user.sh — crea el usuario que Postal
# usara para conectarse, con privilegios sobre cualquier base de datos que
# empiece con POSTAL_DB_PREFIX (Postal aprovisiona una base de datos nueva
# por cada mail server que se crea dentro de el; ver
# https://docs.postalserver.io/getting-started/prerequisites/, que exige
# "credentials allowing full access to create and delete databases").
#
# Ejecutado automaticamente por el entrypoint oficial de la imagen mariadb
# SOLO en la primera inicializacion del volumen de datos vacio (igual que
# los scripts de docker-entrypoint-initdb.d de postgres). Usa variables de
# entorno (via env_file en docker-compose.yml) en vez de un .sql estatico
# porque el .sql no puede leer secretos en tiempo de ejecucion.
set -Eeuo pipefail

: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD no esta definido}"
: "${POSTAL_DB_USER:?POSTAL_DB_USER no esta definido}"
: "${POSTAL_DB_PASSWORD:?POSTAL_DB_PASSWORD no esta definido}"
: "${POSTAL_DB_PREFIX:?POSTAL_DB_PREFIX no esta definido}"

mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
	CREATE USER IF NOT EXISTS '${POSTAL_DB_USER}'@'%' IDENTIFIED BY '${POSTAL_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${POSTAL_DB_PREFIX}%\`.* TO '${POSTAL_DB_USER}'@'%';
	FLUSH PRIVILEGES;
EOSQL
