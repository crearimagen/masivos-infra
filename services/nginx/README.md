# services/nginx

Reverse proxy TLS-terminating y emisión de certificados Let's Encrypt (DNS-01 vía `certbot-dns-cloudflare`). Único punto de entrada HTTP/HTTPS del servidor — ver [`docs/architecture.md`](../../docs/architecture.md).

## Qué hace

- Termina TLS para el panel web de Postal (Sprint 8) y, más adelante, Grafana y Uptime Kuma (Sprints 10-11).
- Emite y renueva certificados wildcard (`*.<DOMAIN_ROOT>`) vía DNS-01 sobre Cloudflare — no depende de que el puerto 80 esté accesible en el momento de renovación (ver [`docs/dns.md`](../../docs/dns.md)).
- **Alcanza el panel web de Postal (`network_mode: host`, puerto `5000`) vía `extra_hosts: host.docker.internal:host-gateway`** — Nginx permanece en `masivos-network` como el resto del stack; no se propaga la excepción de red de Postal a este servicio. Ver la nota completa en `docs/architecture.md`.
- Rate limiting básico en el login del panel de Postal (`limit_req`).

## Por qué no se usa el `envsubst` nativo de la imagen de Nginx

La imagen oficial soporta renderizar plantillas con variables de entorno automáticamente (`/etc/nginx/templates/*.template`), pero ese mecanismo sustituye **cualquier** `$variable` que encuentre — incluidas las propias variables de Nginx (`$remote_addr`, `$http_referer`, etc.), rompiéndolas. En su lugar, `conf.d/*.conf.template` se renderiza con `sed` vía `scripts/render-config.sh`, el mismo patrón ya usado en `security/ssh/` (Sprint 2). Los `.conf` resultantes no se versionan (contienen el dominio real del servidor) — solo los `.conf.template`.

## Cómo instalarlo

```bash
# 1. Configurar
cp services/nginx/.env.example services/nginx/.env
# editar services/nginx/.env: DOMAIN_ROOT, POSTAL_WEB_HOSTNAME
# (deben coincidir con environments/<env>/.env y services/postal/.env)

# 2. Renderizar la configuracion desde las plantillas
./services/nginx/scripts/render-config.sh

# 3. Generar las credenciales de Cloudflare y emitir el certificado inicial
./services/nginx/scripts/generate-cloudflare-credentials.sh --environment prod
./services/nginx/scripts/issue-certificate.sh --environment prod

# 4. Arrancar nginx (fallara si el paso 3 no genero certificados - esperado)
docker compose --env-file services/nginx/.env -f services/nginx/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes (crea `masivos-network` y el volumen `masivos-nginx-data`), y que `services/postal` ya esté configurado (`WEB_SERVER_DEFAULT_BIND_ADDRESS=0.0.0.0`, ver su README) para que `host-gateway` pueda alcanzarlo.

## Cómo actualizarlo

Editar `conf.d/*.conf.template` o `nginx.conf` y volver a ejecutar `render-config.sh` (recarga Nginx automáticamente si detecta un cambio) o `docker compose ... restart nginx` para cambios en `nginx.conf`.

## Renovación de certificados

```bash
./services/nginx/scripts/renew-certificates.sh --environment prod
```

Idempotente (`certbot renew` no hace nada si ningún certificado está próximo a expirar) y recarga Nginx solo si renovó algo. Pensado para ejecutarse por cron — la orquestación de cron a nivel de todo el repositorio llega en el Sprint 12; hasta entonces, se agenda manualmente o con un cron propio del operador.

## Cómo respaldarlo / restaurarlo

Los certificados (`services/nginx/ssl/`) son reemisibles bajo demanda (`issue-certificate.sh`) — no requieren backup formal. La configuración (`conf.d/*.template`, `nginx.conf`) ya está versionada en Git.

## Cómo monitorearlo

```bash
docker exec masivos-nginx nginx -t
curl -sI https://postal.masivos.app/
```

Métricas vía Prometheus (`nginx-prometheus-exporter` o el módulo `stub_status`) se añaden en `services/prometheus` (Sprint 10).

## Riesgo conocido de primer despliegue

Igual que `services/postal/`: no se ha podido probar contra un servidor real en este entorno de desarrollo. La cadena Nginx → `host-gateway` → Postal es la pieza más nueva de todo el stack (no sigue un patrón usado en sprints anteriores); verifica `docker exec masivos-nginx curl -sI http://host.docker.internal:5000/` como primer paso de diagnóstico si el proxy hacia Postal falla.
