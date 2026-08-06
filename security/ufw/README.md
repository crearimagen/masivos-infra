# security/ufw/

Firewall a nivel de host con política de denegación por defecto en entrada.

## Qué hace

- Instala `ufw` si no está presente.
- `default deny incoming`, `default allow outgoing`.
- Abre exclusivamente: `SSH_PORT` (definido por entorno), `25`, `587`, `465` (SMTP/Postal), `80`, `443` (Nginx). Ningún otro puerto es alcanzable desde fuera del host — Postgres, RabbitMQ, Redis, Prometheus y Loki solo son accesibles dentro de `masivos-network` (ver [`docs/architecture.md`](../../docs/architecture.md)).
- Habilita `ufw`.

## Cómo instalarlo

```bash
sudo ./security/ufw/apply-ufw-rules.sh --environment prod
```

Ejecutar después de `security/ssh/apply-ssh-hardening.sh` es seguro y recomendado en ese orden (así el puerto SSH ya está permitido antes de que `sshd` deje de escuchar en el 22); `security/hardening.sh` ya respeta ese orden.

## Cómo actualizarlo

Para abrir un puerto adicional, edita el array `TCP_PORTS` en `apply-ufw-rules.sh` y documenta el motivo en [`docs/architecture.md`](../../docs/architecture.md) — la tabla de puertos ahí debe ser siempre el reflejo exacto de lo que UFW permite.

## Verificación

```bash
sudo ufw status verbose
```

## Rollback manual

```bash
sudo ufw disable
```
