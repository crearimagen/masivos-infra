#!/usr/bin/env bash
# services/postgres/init/01-create-monitoring-user.sh — crea el usuario de
# solo lectura que usa postgres_exporter (services/prometheus/, Sprint 10),
# usando el rol predefinido "pg_monitor" (disponible desde Postgres 10,
# otorga exactamente los privilegios de lectura de estadisticas que
# postgres_exporter necesita, sin acceso a datos de aplicacion).
#
# .sh (no .sql) porque necesita leer el password desde una variable de
# entorno en tiempo de ejecucion (env_file en docker-compose.yml) - un
# .sql estatico no puede. Ejecutado automaticamente por el entrypoint
# oficial de postgres SOLO en la primera inicializacion del volumen
# (PGDATA vacio), igual que 00-extensions.sql.
set -Eeuo pipefail

: "${MONITORING_DB_USER:?MONITORING_DB_USER no esta definido}"
: "${MONITORING_DB_PASSWORD:?MONITORING_DB_PASSWORD no esta definido}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	DO \$\$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${MONITORING_DB_USER}') THEN
	    CREATE ROLE "${MONITORING_DB_USER}" LOGIN PASSWORD '${MONITORING_DB_PASSWORD}';
	  END IF;
	END
	\$\$;
	GRANT pg_monitor TO "${MONITORING_DB_USER}";
	GRANT CONNECT ON DATABASE "${POSTGRES_DB}" TO "${MONITORING_DB_USER}";
EOSQL
