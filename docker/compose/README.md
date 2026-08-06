# docker/compose/

Compose principal que orquesta todos los servicios de `services/*` mediante `include:` (Compose Spec), sin redefinirlos. Declara como `external: true` la red `masivos-network` y los 6 volúmenes nombrados creados por `docker/networks.sh` y `docker/volumes.sh` — este archivo nunca los crea, solo los referencia.

## Por qué `include:` y no `-f` múltiples

Cada servicio en `services/<nombre>/docker-compose.yml` es completamente independiente y ejecutable por sí solo (`docker compose -f services/postgres/docker-compose.yml up`), tal como exige `docs/architecture.md`. `include:` permite tener ese mismo archivo, sin duplicarlo ni reescribirlo, agregado aquí para operar el stack completo con un solo comando.

## Estado actual (Sprint 7)

Se incluyen los servicios ya implementados: `mariadb`, `postgres`, `rabbitmq`, `redis`. **`postal` y `nginx` siguen sin implementar** (siguen siendo el placeholder del scaffolding inicial, `image: ...` + `restart: unless-stopped`) y se excluyen deliberadamente de `include:` hasta los Sprints 8 y 9 — antes del Sprint 7 estaban incluidos por error a pesar de no ser funcionales, se corrigió aquí. `grafana`, `prometheus`, `loki` y `uptime-kuma` se añaden en los Sprints 10-11, cuando existan.

**Nota (Sprint 7):** Postal usa `mariadb`, no `postgres`/`redis`/`rabbitmq` — ver [`docs/architecture.md`](../../docs/architecture.md#modelo-de-volúmenes). Esos tres siguen incluidos porque son infraestructura general válida por sí misma, no porque Postal los consuma.

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
