# docker/compose/

Compose principal que orquesta todos los servicios de `services/*` mediante `include:` (Compose Spec), sin redefinirlos. Declara como `external: true` la red `masivos-network` y los 5 volúmenes nombrados creados por `docker/networks.sh` y `docker/volumes.sh` — este archivo nunca los crea, solo los referencia.

## Por qué `include:` y no `-f` múltiples

Cada servicio en `services/<nombre>/docker-compose.yml` es completamente independiente y ejecutable por sí solo (`docker compose -f services/postgres/docker-compose.yml up`), tal como exige `docs/architecture.md`. `include:` permite tener ese mismo archivo, sin duplicarlo ni reescribirlo, agregado aquí para operar el stack completo con un solo comando.

## Estado actual (Sprint 3)

Solo se incluyen los servicios que ya tienen `docker-compose.yml` implementado: `postgres`, `rabbitmq`, `redis`, `postal`, `nginx`. `grafana`, `prometheus`, `loki` y `uptime-kuma` se añaden a la lista `include:` en los Sprints 9 y 10, cuando existan.

## Cómo usarlo

```bash
docker compose \
  --env-file ../../environments/prod/.env \
  -f docker-compose.yml \
  up -d
```

En la práctica, `scripts/deploy.sh` (Sprint 11) envuelve este comando — no se espera que se invoque a mano en producción salvo para debugging.

## Precondición

`docker/install.sh --environment <env>` debe haberse ejecutado antes (crea la red y los volúmenes externos que este archivo referencia).
