# security/fail2ban/

Bloqueo automático de IPs con intentos de login fallidos repetidos.

## Qué hace

- Instala `fail2ban` si falta.
- Configura el jail `[sshd]` sobre `SSH_PORT`, backend `systemd` (lee el journal, no depende de que `/var/log/auth.log` exista).
- Política: `maxretry=5` en `findtime=10m` → ban `1h`, con backoff exponencial (`bantime.factor=2`, `bantime.maxtime=24h`) para reincidentes.

Los jails de Postal (SMTP auth) y Nginx (si aplica) se añaden como archivos independientes en `/etc/fail2ban/jail.d/` durante los Sprints 7 y 8 — este script no se modifica para ello.

## Cómo instalarlo

```bash
sudo ./security/fail2ban/apply-fail2ban.sh --environment prod
```

## Verificación

```bash
sudo fail2ban-client status sshd
```

## Cómo desbanear una IP

```bash
sudo fail2ban-client set sshd unbanip <IP>
```

## Cómo actualizarlo

Edita `jail-masivos-sshd.local.template` y vuelve a ejecutar el script — idempotente, solo reescribe/recarga si el contenido cambió.
