# Restore

Procedimiento de restauración de `masivos-infra`. Cada servicio con backup implementa su `restore-<servicio>.sh` junto a su `backup-<servicio>.sh` en `services/<nombre>/backup/` — nunca se entrega un mecanismo de backup sin su contraparte de restauración.

## Patrón de referencia: services/postgres/backup/restore-postgres.sh

- **Requiere un flag `--force` explícito.** Es una operación destructiva (sobreescribe la base de datos actual); el script se niega a ejecutar sin esa confirmación, pero no usa un prompt interactivo — debe poder invocarse desde automatización (cron, CI) cuando el operador ya decidió restaurar.
- Recibe la ruta al archivo de backup como argumento (`--file`) — nunca asume "el último backup", para evitar restaurar el archivo equivocado por accidente.
- Usa `--clean --if-exists` (Postgres) para dejar la base de datos en el estado exacto del dump, sin arrastrar objetos huérfanos de antes de la restauración.

## Cuándo restaurar

- Recuperación ante desastre: pérdida del volumen de datos o del servidor completo.
- Rollback tras una migración o cambio fallido.
- Clonar datos de `prod` hacia `test` para debugging (usando un backup de `prod` restaurado en el entorno `test` — nunca al revés).

## Procedimiento general

1. Verifica que el contenedor del servicio esté corriendo (`docker ps`).
2. Identifica el archivo de backup correcto en `backups/<entorno>/<servicio>/`.
3. Ejecuta el `restore-<servicio>.sh` correspondiente con `--force`.
4. Verifica la integridad de los datos restaurados (consulta de sanity check específica del servicio — ver su README).

## Qué se puede restaurar por servicio

| Servicio | Estado | Sprint |
|---|---|---|
| `mariadb` | Implementado (SQL restaurado vía `mariadb` client) — base de datos real de Postal | 7 |
| `postgres` | Implementado (`pg_restore --clean --if-exists`) — infraestructura general | 4 |
| `rabbitmq`, `redis`, `postal` | Pendiente, junto con su backup respectivo | 5-6, 8 |

## Orquestación

`scripts/restore.sh` (Sprint 12) envolverá los `restore-*.sh` de cada servicio para restauraciones completas del stack. Hasta entonces, cada uno se ejecuta de forma independiente.

## Referencia cruzada

- Backup: [`docs/backup.md`](backup.md)
- Ejemplo completo: [`services/postgres/README.md`](../services/postgres/README.md#cómo-restaurarlo)
