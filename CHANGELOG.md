# Changelog

Todos los cambios notables de este proyecto se documentan aquí. Formato basado en [Keep a Changelog](https://keepachangelog.com/), agrupado por el sprint en que se implementó (ver [`docs/architecture.md`](docs/architecture.md#roadmap-de-sprints)).

## [Unreleased]

### Sprint 13 — CI/CD
- Workflow de lint (`shellcheck`, validación de `docker-compose.yml`, YAML/JSON) en cada push/PR.
- Workflow de despliegue manual (`workflow_dispatch`) vía SSH, sin acciones de terceros.

### Sprint 12 — Orquestación
- `scripts/deploy.sh`, `update.sh`, `rollback.sh`, `backup.sh`, `restore.sh`, `healthcheck.sh`, `validate.sh`.

### Sprint 11 — Uptime Kuma
- Monitoreo de disponibilidad externo, página de estado pública vía Nginx.

### Sprint 10 — Observabilidad
- Prometheus con exporters de MariaDB, Postgres, Redis, Nginx y RabbitMQ nativo; Grafana con datasources provisionados; Loki + Promtail.

### Sprint 9 — Nginx + TLS
- Reverse proxy TLS-terminating; emisión de certificados Let's Encrypt vía `certbot-dns-cloudflare` (DNS-01).
- Corrección: Postal solo usa el puerto SMTP `25` (no 587/465, como se asumió originalmente).

### Sprint 8 — Postal
- Servicio Postal completo, siguiendo la plantilla `docker-compose` oficial del proyecto (`network_mode: host`).

### Sprint 7 — MariaDB
- Verificado contra la documentación oficial de Postal: requiere MariaDB, no Postgres, y no usa RabbitMQ ni Redis.

### Sprints 4-6 — Postgres, Redis, RabbitMQ
- Implementados según el stack original solicitado; conservados como infraestructura general tras la corrección del Sprint 7.

### Sprint 3 — Docker
- Instalación de Docker Engine, `daemon.json` de producción, red y volúmenes nombrados, compose principal.

### Sprint 2 — Seguridad
- Hardening de SSH, UFW, Fail2Ban, sysctl y logrotate.

### Sprint 1 — Bootstrap
- Provisión base idempotente de Ubuntu 24.04.

### Sprint 0 — Arquitectura
- Estructura inicial del repositorio, diseño de red/entornos/DNS.
