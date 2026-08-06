# security/ssh/

Endurece `sshd` mediante un drop-in en `/etc/ssh/sshd_config.d/99-masivos-hardening.conf`.

## Qué hace

- Cambia el puerto de `sshd` a `SSH_PORT` (`environments/<env>/.env`).
- Deshabilita login por password y por `root` — solo autenticación por clave pública.
- Restringe el acceso SSH exclusivamente a `DEPLOY_USER` (`AllowUsers`).
- Deshabilita X11 forwarding y agent forwarding; mantiene `AllowTcpForwarding yes` a propósito, para permitir `ssh -L` hacia RabbitMQ/Postgres, que intencionalmente no exponen puertos al host (ver [`docs/architecture.md`](../../docs/architecture.md)).

## Cómo instalarlo

```bash
sudo ./security/ssh/apply-ssh-hardening.sh --environment prod
```

**Salvaguarda:** el script se niega a ejecutarse (exit 1) si `DEPLOY_USER` no existe o no tiene ya una clave pública en `authorized_keys` — evita dejar el servidor sin acceso SSH. Ejecuta `bootstrap/users.sh` antes.

Antes de recargar `sshd`, el script valida la configuración con `sshd -t`; si es inválida, revierte automáticamente al drop-in anterior (o lo elimina si no existía) y no recarga el servicio.

**Tras ejecutarlo, verifica el acceso en una terminal nueva sin cerrar la sesión actual:**

```bash
ssh -p 2222 deploy@<IP_DEL_SERVIDOR>
```

## Cómo actualizarlo

Edita `sshd-masivos.conf.template` y vuelve a ejecutar el script — es idempotente y solo reescribe/recarga si el contenido renderizado cambió.

## Rollback manual

```bash
sudo rm /etc/ssh/sshd_config.d/99-masivos-hardening.conf
sudo systemctl reload ssh
```
