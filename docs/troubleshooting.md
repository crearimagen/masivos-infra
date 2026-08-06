# Troubleshooting

Diagnóstico de problemas comunes. Cada entrada apunta primero al comando que confirma la causa, no a la solución directa — verifica antes de actuar.

## Un contenedor no arranca

```bash
docker compose --env-file services/<nombre>/.env -f services/<nombre>/docker-compose.yml logs -f
```

Para Postal específicamente (tres contenedores separados):

```bash
docker logs masivos-postal-web
docker logs masivos-postal-smtp
docker logs masivos-postal-worker
```

## Nginx falla al arrancar / `ssl_certificate` no encontrado

Nginx **requiere** que el certificado ya exista antes de arrancar — no hay fallback. Causa casi segura: el orden de `scripts/deploy.sh` no se respetó, o `issue-certificate.sh` falló.

```bash
ls services/nginx/ssl/live/<DOMAIN_ROOT>/
./services/nginx/scripts/issue-certificate.sh --environment <env>
```

## Nginx no alcanza el panel web de Postal (502/504)

Postal corre en `network_mode: host` (ver [`services/postal/README.md`](../services/postal/README.md)); Nginx lo alcanza vía `extra_hosts: host-gateway`, un mecanismo con dos requisitos que fallan en silencio si no se cumplen:

1. `WEB_SERVER_DEFAULT_BIND_ADDRESS` de Postal debe ser `0.0.0.0`, **nunca** `127.0.0.1` — `host-gateway` no puede atravesar loopback. Verifica `services/postal/.env`.
2. Diagnóstico directo:

```bash
docker exec masivos-nginx curl -sI http://host.docker.internal:5000/
```

Si eso falla pero `docker exec masivos-postal-web curl -sI http://127.0.0.1:5000/` funciona, el problema es el bind address de Postal, no Nginx.

Lo mismo aplica a Prometheus scrapeando `/metrics` de Postal (puertos `9090`/`9091`).

## Postal no conecta a MariaDB

```bash
docker exec masivos-mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT user, host FROM mysql.user WHERE user = 'postal';"
```

Causas más probables: `services/mariadb/.env` (`POSTAL_DB_USER`/`POSTAL_DB_PASSWORD`/`POSTAL_DB_PREFIX`) y `services/postal/.env` (`MAIN_DB_*`/`MESSAGE_DB_*`) no coinciden — son archivos independientes a propósito, nada los sincroniza automáticamente (ver tabla en el [`README.md`](../README.md#2-configurar-cada-servicio) raíz). También verifica que `services/mariadb/init/00-create-postal-user.sh` haya corrido — **solo se ejecuta la primera vez que el volumen `masivos-mariadb-data` se inicializa**; si el volumen ya existía, hay que crear el usuario a mano.

## `docker/validate.sh` o `scripts/validate.sh` fallan

Son de solo lectura — no modifican nada, seguros de re-ejecutar cuantas veces haga falta mientras se investiga. Leen la salida completa: cada check falla independientemente e indica exactamente qué verificar (red, volumen, DNS, certificado, regla de UFW).

## Certificado por expirar / expirado

```bash
openssl x509 -enddate -noout -in services/nginx/ssl/live/<DOMAIN_ROOT>/fullchain.pem
./services/nginx/scripts/renew-certificates.sh --environment <env>
```

## Perdí acceso SSH tras `security/hardening.sh`

El script valida la configuración con `sshd -t` y revierte automáticamente si es inválida — pero no puede protegerte de un `SSH_PORT`/`DEPLOY_USER` mal configurado que sea sintácticamente válido. Si quedaste fuera: acceso por consola del proveedor (VNC/serial) y revisa `/etc/ssh/sshd_config.d/99-masivos-hardening.conf`. Ver [`security/ssh/README.md`](../security/ssh/README.md).

## Un backup falla o queda vacío

`backup-postgres.sh`/`backup-mariadb.sh` eliminan el archivo parcial automáticamente si el volcado falla o resulta vacío — nunca dejan un backup corrupto que parezca válido. Si falla, el error de `pg_dump`/`mariadb-dump` queda en la salida del script; no hace falta inspeccionar el archivo.

## Nada de lo anterior resolvió el problema

Casi todos los servicios de `services/*` no se han probado contra un despliegue real (limitación de las herramientas de desarrollo usadas para construir este repositorio, documentada explícitamente en cada `README.md` bajo "Riesgo conocido de primer despliegue"). Si el comportamiento no coincide con lo documentado, `docker compose logs` del contenedor afectado es siempre el primer paso — no asumas que el problema está en `masivos-infra` antes de leer el log real.
