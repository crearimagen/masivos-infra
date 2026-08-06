# docker/compose/

Compose principal que orquesta todos los servicios de `services/*` mediante `include:` (Compose Spec), sin redefinirlos. Declara como `external: true` la red `masivos-network` y los 6 volúmenes nombrados creados por `docker/networks.sh` y `docker/volumes.sh` — este archivo nunca los crea, solo los referencia.

## Por qué `include:` y no `-f` múltiples

Cada servicio en `services/<nombre>/docker-compose.yml` es completamente independiente y ejecutable por sí solo (`docker compose -f services/postgres/docker-compose.yml up`), tal como exige `docs/architecture.md`. `include:` permite tener ese mismo archivo, sin duplicarlo ni reescribirlo, agregado aquí para operar el stack completo con un solo comando.

## Estado actual (Sprint 9)

Se incluyen: `mariadb`, `postgres`, `rabbitmq`, `redis`, `nginx`. **`postal` deliberadamente no está en este archivo** — no vive en `masivos-network` (`network_mode: host`, ver [`services/postal/README.md`](../../services/postal/README.md)) y tiene un ciclo de arranque distinto (requiere el paso manual `postal make-user` antes de poder operar) — se levanta con su propio `docker compose -f services/postal/docker-compose.yml`. `grafana`, `prometheus`, `loki` y `uptime-kuma` se añaden en los Sprints 10-11, cuando existan.

**Nota (Sprint 7):** Postal usa `mariadb`, no `postgres`/`redis`/`rabbitmq` — ver [`docs/architecture.md`](../../docs/architecture.md#modelo-de-volúmenes). Esos tres siguen incluidos porque son infraestructura general válida por sí misma, no porque Postal los consuma.

## Cómo usarlo

```bash
docker compose \
  --env-file ../../environments/prod/.env \
  -f docker-compose.yml \
  up -d

# Postal se levanta aparte (ver services/postal/README.md para el orden
# completo, incluyendo el paso manual de creacion del primer admin):
docker compose --env-file ../../services/postal/.env -f ../../services/postal/docker-compose.yml up -d
```

En la práctica, `scripts/deploy.sh` (Sprint 12) envuelve estos comandos — no se espera que se invoquen a mano en producción salvo para debugging.

## Precondición

`docker/install.sh --environment <env>` debe haberse ejecutado antes (crea la red y los volúmenes externos que este archivo referencia).
