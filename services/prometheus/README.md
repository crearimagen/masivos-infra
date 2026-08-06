# services/prometheus

Prometheus + exporters: recolecta métricas de MariaDB, Postgres, Redis, RabbitMQ, Nginx, Postal y el host. Consumido por [`services/grafana/`](../grafana/README.md); no tiene interfaz propia para uso diario.

## Qué hace

| Contenedor | Recolecta de | Cómo llega |
|---|---|---|
| `mysqld-exporter` | MariaDB | usuario `MONITORING_DB_USER` (Sprint 7) |
| `postgres-exporter` | Postgres | rol `pg_monitor` (Sprint 4) |
| `redis-exporter` | Redis | `REDIS_PASSWORD` (Sprint 5) |
| `nginx-exporter` | Nginx | `stub_status` interno, puerto `8080` no publicado (Sprint 9) |
| — (nativo) | RabbitMQ | plugin `rabbitmq_prometheus`, puerto `15692` interno (Sprint 6) |
| — (nativo, `/metrics`) | Postal `worker`/`smtp` | vía `host-gateway` (Sprint 8) — el proceso `web` no expone métricas |
| `node-exporter` | El host (CPU, disco, RAM) | `network_mode: host`, igual que Postal |

Prometheus mismo publica `127.0.0.1:9090` — solo para debugging vía túnel SSH; el consumo normal es a través de Grafana.

## Cómo instalarlo

```bash
cp services/prometheus/.env.example services/prometheus/.env
# editar services/prometheus/.env: credenciales de cada exporter (deben
# coincidir con las de mariadb/postgres/redis - ver comentarios en el
# .env.example)
docker compose --env-file services/prometheus/.env -f services/prometheus/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes, y que MariaDB/Postgres ya tengan sus usuarios de monitoreo creados (se crean automáticamente en la primera inicialización de esos volúmenes — Sprints 7 y 4).

## Cómo verificar los targets

```bash
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

Todos deben mostrar `"health": "up"`. Si `postal_worker`/`postal_smtp`/`node` aparecen `down`, verifica primero `docker exec masivos-prometheus wget -qO- http://host.docker.internal:9090/metrics` (o el puerto correspondiente) — es la misma cadena `host-gateway` que Nginx usa para Postal (Sprint 9); si eso falla, el problema está ahí, no en Prometheus.

## Cómo actualizarlo

Editar `config/prometheus.yml` y `docker compose ... restart prometheus` — no requiere recrear el contenedor, Prometheus recarga la config con una señal `SIGHUP`, pero un restart simple es igual de seguro y más simple de razonar.

## Cómo respaldarlo / restaurarlo

Las métricas son datos de series temporales de corta retención (`PROMETHEUS_RETENTION`, 30 días por defecto) — no se consideran datos críticos que requieran backup. Si se pierde el volumen `masivos-prometheus-data`, se recrea vacío y empieza a acumular de nuevo.

## Cómo monitorearlo

```bash
curl -s http://127.0.0.1:9090/-/healthy
```
