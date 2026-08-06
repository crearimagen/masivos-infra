# services/postgres/init/

Scripts ejecutados automáticamente por el entrypoint oficial de la imagen `postgres` **solo la primera vez** que se inicializa un volumen de datos vacío (no en cada arranque del contenedor).

- `00-extensions.sql`: extensiones base genéricas (`pgcrypto`, `uuid-ossp`, `pg_stat_statements`).

## Cómo añadir inicialización específica de un servicio

Cuando un servicio consumidor (p.ej. Postal en el Sprint 7) necesite su propio esquema o rol de base de datos, añade un archivo nuevo aquí con prefijo numérico mayor (`10-postal-role.sql`, etc.) — se ejecutan en orden alfabético. No modifiques `00-extensions.sql` para eso.

**Importante:** si el volumen `masivos-postgres-data` ya existe (servidor no es la primera vez que arranca), estos scripts **no se re-ejecutan**. Para aplicar un script nuevo a una base ya inicializada, ejecútalo manualmente:

```bash
docker exec -i masivos-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < services/postgres/init/10-nuevo-script.sql
```
