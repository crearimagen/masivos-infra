#!/usr/bin/env bash
# services/mariadb/init/01-create-monitoring-user.sh — crea el usuario de
# solo lectura que usa mysqld_exporter (services/prometheus/, Sprint 10).
# Privilegios minimos requeridos por mysqld_exporter: PROCESS,
# REPLICATION CLIENT, SELECT sobre performance_schema (para
# collector.info_schema.* opcionales).
#
# Ejecutado automaticamente SOLO en la primera inicializacion del volumen
# (igual que 00-create-postal-user.sh).
set -Eeuo pipefail

: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD no esta definido}"
: "${MONITORING_DB_USER:?MONITORING_DB_USER no esta definido}"
: "${MONITORING_DB_PASSWORD:?MONITORING_DB_PASSWORD no esta definido}"

mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
	CREATE USER IF NOT EXISTS '${MONITORING_DB_USER}'@'%' IDENTIFIED BY '${MONITORING_DB_PASSWORD}';
	GRANT PROCESS, REPLICATION CLIENT ON *.* TO '${MONITORING_DB_USER}'@'%';
	GRANT SELECT ON performance_schema.* TO '${MONITORING_DB_USER}'@'%';
	FLUSH PRIVILEGES;
EOSQL
