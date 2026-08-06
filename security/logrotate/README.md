# security/logrotate/

Rotación de los logs propios de `masivos-infra` (`/var/log/masivos/*.log`, generados por los scripts de `bootstrap/`, `security/` y `scripts/`).

Los logs de los contenedores Docker se rotan mediante `docker/daemon.json` (Sprint 3), no aquí — son dominios de rotación independientes con volúmenes y ciclos de vida distintos.

## Qué hace

Rotación semanal, retiene 8 semanas, comprime (con `delaycompress` para no romper un `tail -f` en curso), no falla si el archivo no existe.

## Cómo instalarlo

```bash
sudo ./security/logrotate/apply-logrotate.sh --environment prod
```

## Verificación

```bash
sudo logrotate -d /etc/logrotate.d/masivos   # dry-run
sudo logrotate -f /etc/logrotate.d/masivos   # forzar rotacion real
```
