# services/rabbitmq

RabbitMQ 3.13 (con plugin de management) para Masivos.app — cola de mensajes que usará Postal (Sprint 7) para el procesamiento asíncrono de envío/entrega. Servicio independiente: puede ejecutarse solo (`docker compose -f docker-compose.yml up -d`) o como parte del stack completo vía [`docker/compose/docker-compose.yml`](../../docker/compose/docker-compose.yml).

## Qué hace

- RabbitMQ 3.13 con plugin de management, usuario y vhost dedicados (`RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_VHOST=/masivos`) — nunca `guest`/`/`.
- AMQP (`5672`) **no se publica al host** — solo alcanzable desde `masivos-network`.
- Panel de administración (`15672`) publicado **únicamente en `127.0.0.1`** del host, para acceso vía túnel SSH — ver la justificación completa en [`docs/architecture.md`](../../docs/architecture.md#puertos-expuestos-en-el-host). Nunca cambiar ese bind a `0.0.0.0`.
- `vm_memory_high_watermark` relativo al límite de memoria del contenedor (no a la RAM total del host).
- Healthcheck vía `rabbitmq-diagnostics ping`.

## Cómo instalarlo

```bash
cp services/rabbitmq/.env.example services/rabbitmq/.env
# editar services/rabbitmq/.env: RABBITMQ_DEFAULT_PASS, RABBITMQ_ERLANG_COOKIE
docker compose --env-file services/rabbitmq/.env -f services/rabbitmq/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes (crea `masivos-network` y el volumen `masivos-rabbitmq-data`).

## Cómo acceder al panel de administración

```bash
ssh -p 2222 deploy@<IP_DEL_SERVIDOR> -L 15672:127.0.0.1:15672
```

Y abrir `http://localhost:15672` en el navegador local, con las credenciales de `RABBITMQ_DEFAULT_USER`/`RABBITMQ_DEFAULT_PASS`.

## Cómo actualizarlo

Cambiar la versión de imagen en `docker-compose.yml` y ejecutar `docker compose ... up -d` recrea el contenedor preservando el volumen (`masivos-rabbitmq-data`, incluye Mnesia — usuarios, vhosts, colas durables). Para cambios de `config/rabbitmq.conf`, `docker compose ... restart rabbitmq` es suficiente.

## Cómo respaldarlo

**Pendiente**, junto con la definición real de colas/exchanges — se implementa cuando `services/postal` (Sprint 7) defina qué topología necesita persistir. El volumen `masivos-rabbitmq-data` ya persiste colas durables entre reinicios del contenedor.

## Cómo restaurarlo

Pendiente, junto con el backup — ver [`docs/restore.md`](../../docs/restore.md).

## Cómo monitorearlo

```bash
docker exec masivos-rabbitmq rabbitmq-diagnostics -q ping
docker exec masivos-rabbitmq rabbitmqctl list_queues name messages consumers
docker exec masivos-rabbitmq rabbitmqctl node_health_check
```

O vía el panel de administración (ver arriba). El plugin `rabbitmq_prometheus` está habilitado (Sprint 10, `config/enabled_plugins`) y expone métricas en `http://masivos-rabbitmq:15692/metrics`, solo dentro de `masivos-network` — scrapeado por `services/prometheus/`.
