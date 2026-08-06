# services/redis

Redis 7 para Masivos.app — caché y/o estado de colas para Postal (a confirmar en el Sprint 7). Servicio independiente: puede ejecutarse solo (`docker compose -f docker-compose.yml up -d`) o como parte del stack completo vía [`docker/compose/docker-compose.yml`](../../docker/compose/docker-compose.yml).

## Qué hace

- Redis 7 (Alpine), sin puertos publicados al host — solo alcanzable desde `masivos-network`.
- Autenticación obligatoria (`requirepass`), inyectada en tiempo de ejecución desde `.env` — nunca escrita en `redis.conf`.
- **Persistencia activa por defecto** (AOF `everysec` + snapshots RDB) y `maxmemory-policy noeviction` — ver justificación en [`redis.conf`](redis.conf). Esto es deliberadamente más conservador que un Redis "de caché" típico, hasta que se confirme en `services/postal` qué tan crítico es su contenido.
- Healthcheck vía `redis-cli ping`.

## Cómo instalarlo

```bash
cp services/redis/.env.example services/redis/.env
# editar services/redis/.env: REDIS_PASSWORD
docker compose --env-file services/redis/.env -f services/redis/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes (crea `masivos-network` y el volumen `masivos-redis-data`).

## Cómo actualizarlo

Cambiar la versión de imagen en `docker-compose.yml` y ejecutar `docker compose ... up -d` recrea el contenedor preservando el volumen (`/data`, con el AOF y los snapshots RDB). Para cambios de `redis.conf`, `docker compose ... restart redis` es suficiente para la mayoría de directivas.

## Cómo respaldarlo

**Pendiente, deliberadamente no implementado en este sprint.** La estructura original de este servicio no incluye `backup/` (a diferencia de `services/postgres/`), y la persistencia AOF/RDB activa ya protege contra la pérdida de datos por reinicio del contenedor — el escenario más común. Si el Sprint 7 confirma que Redis guarda estado importante de Postal (no solo caché desechable), se añadirá `backup/backup-redis.sh` siguiendo el mismo patrón que `services/postgres/backup/` (ver [`docs/backup.md`](../../docs/backup.md)), respaldando `dump.rdb` con `BGSAVE` + copia del volumen.

## Cómo restaurarlo

Mientras no exista un script formal: el volumen `masivos-redis-data` contiene `dump.rdb` y `appendonly.aof`. Restaurar manualmente implica detener el contenedor, reemplazar esos archivos dentro del volumen, y reiniciar — Redis carga el AOF (si existe) con prioridad sobre el RDB al arrancar.

## Cómo monitorearlo

```bash
docker exec masivos-redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ping
docker exec masivos-redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO memory
docker exec masivos-redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO persistence
```

Métricas vía Prometheus (`redis_exporter`) se añaden en `services/prometheus` (Sprint 9).
