# services/grafana

Panel de visualización, con los datasources de Prometheus y Loki ya provisionados. Público solo a través de Nginx (Sprint 9) — mismo patrón que Postal.

## Qué hace

- Datasources de `Prometheus` y `Loki` provisionados automáticamente al arrancar (`config/provisioning/datasources/datasources.yml`) — no hace falta configurarlos a mano en la UI.
- Registro público de usuarios deshabilitado (`GF_USERS_ALLOW_SIGN_UP=false`) y analítica/telemetría hacia Grafana Labs deshabilitada.
- **No trae dashboards preconstruidos.** Ver "Dashboards recomendados" abajo — decisión deliberada, no un pendiente: no se puede verificar el contenido exacto de un dashboard JSON sin probarlo contra datos reales, y prefiero no versionar algo sin verificar.

## Cómo instalarlo

```bash
cp services/grafana/.env.example services/grafana/.env
# editar services/grafana/.env: GF_SERVER_ROOT_URL, GF_SECURITY_ADMIN_PASSWORD
docker compose --env-file services/grafana/.env -f services/grafana/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes, y que `services/prometheus` y `services/loki` ya estén corriendo (los datasources apuntan a sus nombres de contenedor).

## Dashboards recomendados

Desde la UI: **Dashboards → New → Import**, y busca por nombre en el catálogo público de grafana.com (no cito IDs numéricos aquí para no fijar una versión que puede cambiar o quedar desactualizada — el buscador de la propia UI de import ya resuelve esto):

- "MySQL" / "MySQL Overview" (para `mysqld-exporter`)
- "PostgreSQL" (para `postgres-exporter`)
- "Redis" (para `redis-exporter`)
- "RabbitMQ Overview" (para el plugin nativo `rabbitmq_prometheus`)
- "NGINX" (para `nginx-prometheus-exporter`)
- "Node Exporter Full" (para `node-exporter`)

Selecciona `Prometheus` como datasource al importar cada uno.

## Cómo actualizarlo

Cambiar la versión de imagen en `docker-compose.yml` y `docker compose ... up -d` — el volumen `masivos-grafana-data` preserva dashboards, usuarios y configuración entre versiones.

## Cómo respaldarlo / restaurarlo

Todo el estado de Grafana (dashboards guardados, usuarios, configuración) vive en `masivos-grafana-data` (SQLite por defecto). No tiene backup formal en este sprint — es reconstruible reimportando los dashboards recomendados; si se necesitara preservar dashboards personalizados creados manualmente, exportarlos a JSON desde la UI (`Dashboard settings → JSON Model`) es la vía soportada por Grafana mismo.

## Cómo monitorearlo

```bash
curl -s http://127.0.0.1:3000/api/health 2>/dev/null || docker exec masivos-grafana curl -sf http://127.0.0.1:3000/api/health
```
