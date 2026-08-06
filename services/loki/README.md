# services/loki

Agregación de logs de todos los contenedores del stack. Consumido por [`services/grafana/`](../grafana/README.md) (datasource ya provisionado); no tiene interfaz propia.

## Qué hace

- `loki`: almacena logs, modo single-binary con almacenamiento en filesystem (`masivos-loki-data`), retención 30 días.
- `promtail`: descubre automáticamente **todos** los contenedores del host (vía el socket de Docker, solo lectura) y envía sus logs a Loki, con etiquetas `container`, `container_id`, `stream`. Esto incluye a Postal, que corre en `network_mode: host` — Docker expone su API/logs igual sin importar la red del contenedor, así que no necesita ningún tratamiento especial aquí (a diferencia de Nginx/Prometheus, que sí necesitan `host-gateway` para *scrapear* HTTP; Promtail *descubre* vía el socket, no vía red).

## Riesgo aceptado: acceso al socket de Docker

`promtail` monta `/var/run/docker.sock` de solo lectura. Es el mecanismo estándar documentado por Grafana para el descubrimiento automático de contenedores (`docker_sd_configs`). Con ese acceso, Promtail puede **inspeccionar** metadatos de cualquier contenedor del host — no puede ejecutar comandos dentro de ellos ni modificarlos a través de este mount. Es una superficie de acceso mayor que la de un exporter típico; se acepta porque es el patrón estándar de la industria para este caso de uso y porque Promtail no expone ningún puerto al exterior.

## Cómo instalarlo

```bash
cp services/loki/.env.example services/loki/.env
docker compose --env-file services/loki/.env -f services/loki/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes.

## Cómo consultar logs directamente (sin Grafana)

```bash
docker exec masivos-loki wget -qO- 'http://127.0.0.1:3100/loki/api/v1/query_range?query={container="masivos-postal-smtp"}' 
```

En la práctica, se usa la UI de Grafana (**Explore → Loki**) — más manejable que la API cruda.

## Cómo actualizarlo

Cambiar la versión de imagen en `docker-compose.yml` (mantener `loki` y `promtail` en la misma versión mayor) y `docker compose ... up -d`.

## Cómo respaldarlo / restaurarlo

Los logs son datos de retención corta (30 días) — no se consideran críticos para backup formal. Si se pierde `masivos-loki-data`, se recrea vacío.

## Cómo monitorearlo

```bash
curl -s http://127.0.0.1:3100/ready 2>/dev/null || docker exec masivos-loki wget -qO- http://127.0.0.1:3100/ready
```
