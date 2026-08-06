# Backup

Estrategia de respaldo de `masivos-infra`. Cada servicio con estado propio (bases de datos, colas persistentes) implementa su backup en `services/<nombre>/backup/`, siguiendo el patrón establecido en `services/postgres/backup/` — el primero implementado, y la referencia a replicar.

## Patrón de referencia: services/postgres/backup/backup-postgres.sh

- Formato nativo de la herramienta del servicio (`pg_dump -Fc` para Postgres), no un `tar` genérico del volumen — más portable entre versiones y verificable.
- Salida en `backups/<entorno>/<servicio>/`, con timestamp UTC en el nombre de archivo — nunca sobreescribe un backup anterior.
- Retención configurable vía `.env` del servicio (`POSTGRES_BACKUP_RETENTION_DAYS`), aplicada al final de cada corrida exitosa.
- Falla explícitamente (exit distinto de 0) y limpia archivos parciales si el backup no se completó correctamente — nunca deja un backup truncado que parezca válido.

## Dónde viven los backups

`backups/<entorno>/<servicio>/` en el host. El directorio `backups/` está excluido de Git (`.gitignore`) — nunca se versionan datos de producción.

**Responsabilidad del operador, fuera del alcance de este repositorio:** copiar `backups/` a almacenamiento externo (S3, Backblaze, etc.). `masivos-infra` genera y retiene backups localmente; la replicación fuera del servidor es una decisión operativa que se documentará aquí cuando se implemente (candidato para un sprint posterior si se requiere).

## Qué se respalda por servicio

| Servicio | Estado | Sprint |
|---|---|---|
| `mariadb` | Implementado (`mariadb-dump --all-databases`) — base de datos real de Postal | 7 |
| `postgres` | Implementado (`pg_dump -Fc`) — infraestructura general, no usado por Postal | 4 |
| `rabbitmq` | Pendiente — infraestructura general, no usado por Postal; evaluar si aplica en el futuro | 6 |
| `redis` | Pendiente — infraestructura general, no usado por Postal; evaluar si aplica en el futuro | 5 |
| `postal` | Pendiente — datos de configuración propios del contenedor (`masivos-postal-data`) | 8 |

## Orquestación

`scripts/backup.sh` (Sprint 12) ejecutará el backup de todos los servicios con estado en un solo comando, para uso en cron. Hasta entonces, cada `backup-*.sh` de servicio se ejecuta de forma independiente.

## Referencia cruzada

- Restauración: [`docs/restore.md`](restore.md)
- Ejemplo completo: [`services/postgres/README.md`](../services/postgres/README.md#cómo-respaldarlo)
