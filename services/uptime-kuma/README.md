# services/uptime-kuma

[Uptime Kuma](https://github.com/louislam/uptime-kuma) — monitoreo de disponibilidad externo (HTTP/TCP/DNS) con página de estado pública. Público solo a través de Nginx (Sprint 9), en `status.<DOMAIN_ROOT>` (subdominio ya reservado desde el Sprint 0, ver [`docs/dns.md`](../../docs/dns.md)).

## Verificado antes de construir

**Uptime Kuma no tiene configuración declarativa de monitores** — ni archivo YAML, ni API REST pública para crearlos por script. Es una limitación real del proyecto (confirmado en su wiki oficial y en discusiones abiertas del repositorio, no una carencia de este sprint). Los monitores se crean a través de su UI web. Igual que `postal make-user` (Sprint 8), este es un paso manual documentado, no automatizado — no existe un mecanismo del propio Uptime Kuma que permita hacerlo de otra forma.

Uptime Kuma sí soporta oficialmente usar MariaDB como backend en vez de su SQLite embebido por defecto. No se usa aquí — acoplar este servicio a `services/mariadb/` no aporta nada frente al SQLite por defecto (que ya persiste en `masivos-uptime-kuma-data`) y añadiría una dependencia innecesaria.

## Qué hace

- Contenedor único, `masivos-network`, sin `host-gateway` — a diferencia de Nginx→Postal, Uptime Kuma no necesita alcanzar nada en `network_mode: host`; simplemente hace peticiones salientes normales a los dominios que se configuren como monitores.
- Reverse-proxied por Nginx con soporte de WebSocket (actualización del panel en tiempo real).

## Cómo instalarlo

```bash
cp services/uptime-kuma/.env.example services/uptime-kuma/.env
docker compose --env-file services/uptime-kuma/.env -f services/uptime-kuma/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes, y que `services/nginx` esté configurado con `UPTIME_KUMA_WEB_HOSTNAME` (ver su `.env.example`) y el certificado ya emitido para poder reenviar tráfico.

## Configuración inicial (manual, interactiva)

1. Abrir `https://status.<DOMAIN_ROOT>` — el primer acceso pide crear el usuario administrador.
2. **Añadir monitores apuntando a los dominios públicos, no a nombres de contenedor internos** — así se prueba la disponibilidad real (DNS + TLS + red pública), que es el propósito de un uptime monitor:
   - `https://postal.<DOMAIN_ROOT>` (HTTP(s))
   - `https://grafana.<DOMAIN_ROOT>` (HTTP(s))
   - `<SERVER_PUBLIC_IP>:25` (TCP, SMTP de Postal)
3. Opcional: crear una **Status Page** pública (distinta del panel de administración, no requiere login) con los monitores que se quieran mostrar externamente.

## Cómo actualizarlo

Cambiar la versión de imagen en `docker-compose.yml` y `docker compose ... up -d` — el volumen `masivos-uptime-kuma-data` preserva monitores e historial entre versiones.

## Cómo respaldarlo / restaurarlo

Todo el estado (monitores, historial, configuración) vive en `masivos-uptime-kuma-data` (SQLite). Sin backup formal en este sprint — los monitores son rápidos de recrear manualmente si se pierde el volumen; el historial de disponibilidad acumulado sí se perdería, lo cual es un riesgo aceptado dado el bajo costo de reconfiguración.

## Cómo monitorearlo

```bash
curl -sI https://status.masivos.app/ 
docker exec masivos-uptime-kuma wget -qO- http://127.0.0.1:3001/ >/dev/null && echo "OK"
```

Nota: nadie monitorea al monitor — si Uptime Kuma mismo cae, no hay alerta automática de eso. Es una limitación aceptada de tener un solo monitor de disponibilidad (no se justifica un segundo sistema de monitoreo redundante para este stack).
