-- services/postgres/init/00-extensions.sql
-- Ejecutado automaticamente por el entrypoint oficial de postgres SOLO en la
-- primera inicializacion del volumen (PGDATA vacio). Extensiones genericas
-- de base, independientes de cualquier servicio consumidor.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
