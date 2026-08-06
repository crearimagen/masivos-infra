# security/

Endurecimiento de seguridad del servidor, ejecutado después de `bootstrap/` y antes de `docker/`. Ver el diagrama y la tabla de puertos en [`docs/architecture.md`](../docs/architecture.md) y el detalle de decisiones en [`docs/security.md`](../docs/security.md).

## Componentes

| Carpeta | Responsabilidad | README |
|---|---|---|
| `ssh/` | Solo autenticación por clave, sin `root`, puerto no estándar, solo `DEPLOY_USER` | [ssh/README.md](ssh/README.md) |
| `ufw/` | Firewall deny-by-default, abre solo los puertos de `docs/architecture.md` | [ufw/README.md](ufw/README.md) |
| `fail2ban/` | Baneo automático de IPs con logins fallidos repetidos sobre `sshd` | [fail2ban/README.md](fail2ban/README.md) |
| `sysctl/` | Parámetros de kernel endurecidos, preservando `ip_forward` para Docker | [sysctl/README.md](sysctl/README.md) |
| `logrotate/` | Rotación de `/var/log/masivos/*.log` | [logrotate/README.md](logrotate/README.md) |

## Cómo instalarlo

```bash
sudo ./security/hardening.sh --environment prod
```

Orquesta los cinco componentes en el orden: `sysctl → ufw → fail2ban → ssh → logrotate`. El orden es deliberado — ver comentarios en `hardening.sh`. Cada componente puede ejecutarse también de forma individual.

## Idempotencia

Igual que `bootstrap/`: cada script verifica su propio estado antes de aplicar cambios y puede re-ejecutarse sin efectos secundarios.

## Logs

`/var/log/masivos/bootstrap.log` (compartido con `bootstrap/`, mismo formato de log de `lib.sh`).

## Códigos de salida

Idénticos a los de `bootstrap/` — ver [`bootstrap/README.md`](../bootstrap/README.md#códigos-de-salida).

## Variables requeridas

`SSH_PORT` (nueva en este sprint) además de las ya definidas en `bootstrap/`. Ver [`environments/README.md`](../environments/README.md).

## Advertencia operativa

`ssh/apply-ssh-hardening.sh` cambia el puerto y el usuario permitido de SSH. **No cierres tu sesión actual** hasta confirmar el acceso en una terminal nueva con `ssh -p <SSH_PORT> <DEPLOY_USER>@<IP>`. El script valida la configuración con `sshd -t` antes de recargar y revierte automáticamente si es inválida, pero no puede protegerte de un `SSH_PORT` o `DEPLOY_USER` mal configurados en `.env` que sí sean sintácticamente válidos.
