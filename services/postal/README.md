# services/postal

[Postal](https://github.com/postalserver/postal) v3 — la plataforma de envío/recepción de correo de Masivos.app. A diferencia del resto de `services/*`, **no corre en `masivos-network`**: sigue la plantilla `docker-compose` oficial del proyecto, con `network_mode: host` en sus cuatro contenedores.

## Verificado antes de construir, no asumido

Todo lo siguiente se confirmó contra la documentación y el código fuente oficiales de Postal (no contra memoria ni tutoriales de terceros) antes de escribir una sola línea de este servicio:

- **Motor de base de datos: MariaDB 10.6+ exclusivamente.** Ver [`services/mariadb/README.md`](../mariadb/README.md) — es la razón por la que existe ese servicio en vez de usar `services/postgres/`.
- **Postal v3 no usa RabbitMQ ni Redis.** La cola de mensajes vive en `message_db` (MariaDB), procesada por el proceso `worker`.
- **Un único puerto SMTP: `25`.** No existen listeners de submission (`587`) ni SMTPS (`465`) en la configuración de referencia de Postal v3 — `docs/architecture.md` y `security/ufw/` se corrigieron en este sprint, tenían 587/465 abiertos sin necesidad.
- **`network_mode: host` en los contenedores `web`, `smtp`, `worker` y `runner`**, tal como define la plantilla oficial (`templates/docker-compose.v3.yml` del repositorio [`postalserver/install`](https://github.com/postalserver/install)) — permite que `smtp` bindee el puerto 25 vía `cap_add: NET_BIND_SERVICE` sin correr como root, y que los procesos compartan namespace de red.
- **Toda la configuración puede definirse por variable de entorno**, con equivalencia 1:1 a `postal.yml` (ver [`doc/config/environment-variables.md`](https://github.com/postalserver/postal/blob/main/doc/config/environment-variables.md) del repo oficial) — permite mantener el mismo patrón `.env` que el resto del stack en vez de un archivo de configuración aparte con secretos.
- **`postal make-user` (creación del primer administrador) es interactivo y no acepta flags ni variables de entorno** (confirmado leyendo `script/make_user.rb` del repo oficial) — es el único paso manual de este servicio; se documenta como tal en vez de fingir que se puede automatizar.

## Consecuencias de `network_mode: host` sobre el resto del stack

1. **MariaDB publica `127.0.0.1:3306`** (además de seguir en `masivos-network`) — Postal no puede resolver `masivos-mariadb` por nombre de contenedor al no compartir esa red. Ver [`services/mariadb/docker-compose.yml`](../mariadb/docker-compose.yml).
2. **Nginx (Sprint 9) alcanza el panel web de Postal vía `extra_hosts: host-gateway`.** Esto exigió corregir `WEB_SERVER_DEFAULT_BIND_ADDRESS` de `127.0.0.1` a `0.0.0.0` en este servicio (ver `.env.example`) — el mecanismo `host-gateway` solo funciona contra puertos bindeados a todas las interfaces, nunca contra loopback. La seguridad real la sigue dando UFW, que nunca abre el `5000` — ver [`services/nginx/README.md`](../nginx/README.md).

## Qué hace

- `web`: panel web + API en el puerto `5000`, todas las interfaces (nunca público directamente — solo alcanzable vía Nginx o `docker exec`; ver nota sobre UFW arriba).
- `smtp`: servidor SMTP en el puerto `25`, todas las interfaces.
- `worker`: procesa la cola de entrega (basada en `message_db`, no en un broker externo).
- `runner`: servicio de un solo uso (`profile: tools`, no arranca con `up -d`) para comandos administrativos (`postal initialize`, `postal make-user`).

## Cómo instalarlo

```bash
# 1. Configurar
cp services/postal/.env.example services/postal/.env
# editar services/postal/.env: hostnames, credenciales de MariaDB
# (deben coincidir con services/mariadb/.env), RAILS_SECRET_KEY

# 2. Generar la clave de firma (una sola vez por servidor)
./services/postal/scripts/generate-signing-key.sh

# 3. Asegurarse de que MariaDB esta arriba (Sprint 7)
docker compose --env-file services/mariadb/.env -f services/mariadb/docker-compose.yml up -d

# 4. Crear/migrar el esquema
./services/postal/scripts/initialize-postal.sh --environment prod

# 5. Crear el primer administrador (INTERACTIVO - unico paso manual)
docker compose --env-file services/postal/.env -f services/postal/docker-compose.yml \
  run --rm -it runner postal make-user

# 6. Arrancar web/smtp/worker
docker compose --env-file services/postal/.env -f services/postal/docker-compose.yml up -d
```

Requiere que `docker/install.sh --environment <env>` se haya ejecutado antes (crea el volumen `masivos-postal-data`). No requiere `masivos-network` para Postal mismo (sí para MariaDB, que ya lo tiene desde el Sprint 7).

## DNS

Ver [`docs/dns.md`](../../docs/dns.md) y [`templates/dns-records.txt`](templates/dns-records.txt) — el registro DKIM exacto lo genera Postal al crear el primer "mail server" desde el panel, después de este paso de instalación.

## Cómo actualizarlo

Cambiar `POSTAL_VERSION` en `.env` y volver a ejecutar `docker compose ... up -d` recrea los cuatro contenedores. Ejecutar `./scripts/initialize-postal.sh --environment <env>` después de cada actualización de versión — aplica migraciones de base de datos pendientes (idempotente).

## Cómo respaldarlo

Los datos reales (mensajes, configuración de mail servers) viven en MariaDB — ver [`services/mariadb/README.md`](../mariadb/README.md#cómo-respaldarlo). Adicionalmente, **`config/signing.key` debe respaldarse por separado** (no vive en la base de datos): perderlo invalida la firma de mensajes/tokens existentes. Fuera del alcance de este sprint automatizar ese respaldo — es un archivo pequeño y estático; cópialo manualmente a almacenamiento seguro tras generarlo.

## Cómo restaurarlo

Restaurar el backup de `services/mariadb/` correspondiente (ver su README) y colocar de vuelta el `signing.key` respaldado en `config/signing.key` antes de arrancar los contenedores.

## Cómo monitorearlo

```bash
docker exec masivos-postal-web curl -sf http://127.0.0.1:5000/ -o /dev/null && echo "web OK"
docker exec masivos-postal-smtp nc -z 127.0.0.1 9091 && echo "smtp OK"
docker exec masivos-postal-worker nc -z 127.0.0.1 9090 && echo "worker OK"
docker compose --env-file .env -f docker-compose.yml logs -f
```

Métricas vía Prometheus (Sprint 10): Postal expone `/metrics` en formato Prometheus nativo en `SMTP_SERVER_DEFAULT_HEALTH_SERVER_PORT` (`9091`) y `WORKER_DEFAULT_HEALTH_SERVER_PORT` (`9090`) — verificado contra [`docs.postalserver.io/features/health-metrics`](https://docs.postalserver.io/features/health-metrics/). El proceso `web` no tiene endpoint de métricas documentado. `services/prometheus/` los scrapea vía `host-gateway`, igual que Nginx alcanza el panel web — por eso ambos binds se corrigieron a `0.0.0.0` en este sprint (ver arriba).

## Riesgo conocido de primer despliegue

Este servicio no se ha podido probar contra una instancia real de Postal en este entorno de desarrollo (sin Docker disponible). La estructura del `docker-compose.yml` y las variables de entorno están verificadas contra el código y la documentación oficiales, pero el primer `docker compose up` en un servidor real es la validación definitiva — si algo falla, revisa primero `docker compose logs` del contenedor afectado antes de asumir que el problema está en `masivos-infra`.
