# Seguridad

Decisiones de hardening aplicadas por `security/hardening.sh`. Para el detalle operativo de cada componente (instalación, verificación, rollback) ver [`security/README.md`](../security/README.md) y los README de cada subcarpeta.

## Modelo de amenaza

El servidor expone directamente a Internet: SSH (`SSH_PORT`), SMTP (`25` — único puerto SMTP de Postal v3, verificado en el Sprint 8; no existen 587/465) y HTTPS (`80/443`). Todo lo demás (MariaDB, Postgres, RabbitMQ, Redis, Prometheus, Loki, y el panel web de Postal en `127.0.0.1:5000`) vive exclusivamente dentro de `masivos-network` o en loopback — ver [`docs/architecture.md`](architecture.md#puertos-expuestos-en-el-host). El hardening de este documento asume que el vector principal de ataque son esos cuatro puertos públicos, más las cuentas SMTP de Postal (Sprint 8).

## SSH

- Autenticación exclusivamente por clave pública (`PasswordAuthentication no`).
- `PermitRootLogin no` — no hay ninguna operación administrativa que dependa de entrar como `root` directamente; `DEPLOY_USER` con `sudo` cubre todos los casos.
- `AllowUsers ${DEPLOY_USER}` — solo ese usuario puede iniciar sesión por SSH.
- Puerto no estándar (`SSH_PORT`, por defecto `2222`) — reduce el ruido de escaneos automatizados; no sustituye a la autenticación por clave, es una capa adicional.
- `AllowTcpForwarding yes` deliberado: es el mecanismo soportado para que un operador acceda a RabbitMQ/Postgres vía `ssh -L`, ya que esos servicios no exponen puertos al host a propósito.

## Firewall (UFW)

Política `deny` por defecto en entrada. Únicamente se permiten los puertos de la tabla de `docs/architecture.md`. Cualquier puerto nuevo que un servicio necesite exponer debe añadirse primero a esa tabla y luego a `security/ufw/apply-ufw-rules.sh` — nunca al revés.

## Fail2Ban

Jail `[sshd]` con `maxretry=5` en `10m` → ban `1h` con backoff exponencial hasta `24h` para reincidentes. Jails de Postal (autenticación SMTP) y Nginx se añaden en los Sprints 7 y 8 como archivos independientes en `/etc/fail2ban/jail.d/`.

## Kernel (sysctl)

Anti-spoofing, rechazo de ICMP redirects/source routing, protección SYN flood, ASLR completo. **Excepción deliberada:** `net.ipv4.ip_forward=1` se mantiene activo porque Docker lo requiere para el NAT/enrutamiento de `masivos-network` (Sprint 3) — la mayoría de guías de hardening genéricas lo desactivan, aquí rompería el stack completo.

## Actualizaciones automáticas

`bootstrap/packages.sh` configura `unattended-upgrades` para parches de seguridad de Ubuntu. No cubre las imágenes Docker de `services/*` — su actualización se gestiona en `scripts/update.sh` (Sprint 11).

## Rotación de logs

Los logs propios de los scripts (`/var/log/masivos/*.log`) rotan semanalmente, 8 semanas de retención (`security/logrotate/`). Los logs de contenedores Docker rotan vía `docker/daemon.json` (Sprint 3) — dominios independientes.

## Pendiente de sprints futuros

- Jails de Fail2Ban específicos de Postal y Nginx (Sprints 7-8).
- TLS/Let's Encrypt (Sprint 8) — ver [`docs/dns.md`](dns.md).
- Auditoría de permisos de volúmenes Docker y secretos en tiempo de ejecución (Sprint 3 en adelante).
