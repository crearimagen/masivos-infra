# bootstrap/

Provisión base de un servidor Ubuntu 24.04 recién instalado. Es el primer paso de `docs/architecture.md`: deja el sistema listo para `security/hardening.sh`.

## Qué hace

| Script | Responsabilidad |
|---|---|
| `lib.sh` | Librería compartida (logging, validaciones, carga de `.env`). Se hace `source`, no se ejecuta. |
| `packages.sh` | Instala paquetes base (curl, git, chrony, etc.) y configura `unattended-upgrades`. |
| `timezone.sh` | Configura la zona horaria (`TIMEZONE`) y habilita `chrony` para NTP. |
| `hostname.sh` | Configura el hostname como `mail.<DOMAIN_ROOT>` (debe coincidir con el PTR de `docs/dns.md`) y actualiza `/etc/hosts`. |
| `users.sh` | Crea el usuario de despliegue (`DEPLOY_USER`), lo agrega a `sudo`, instala su clave SSH pública y bloquea el login por password de ese usuario y de `root`. |
| `install.sh` | Orquesta los cuatro scripts anteriores en orden. |

## Cómo instalarlo

En un servidor Ubuntu 24.04 recién provisto, con acceso root:

```bash
git clone https://github.com/crearimagen/masivos-infra.git
cd masivos-infra
cp environments/prod/.env.example environments/prod/.env
# editar environments/prod/.env con los valores reales del servidor
sudo ./bootstrap/install.sh --environment prod
```

Cada script puede ejecutarse también de forma individual con el mismo flag `--environment`.

## Idempotencia

Todos los scripts pueden re-ejecutarse sin efectos secundarios: cada acción verifica su propio estado antes de aplicarse (paquete ya instalado, timezone ya configurada, hostname ya correcto, usuario ya existente, clave SSH ya presente). Re-ejecutar `install.sh` tras corregir un error es seguro y es el mecanismo de recuperación esperado.

## Logs

Todos los scripts registran en `/var/log/masivos/bootstrap.log` además de stdout/stderr, con el formato `[timestamp UTC] [LEVEL] [script] mensaje`.

## Códigos de salida

| Código | Significado |
|---|---|
| 0 | Éxito |
| 1 | Error general durante la ejecución |
| 2 | Uso inválido (falta `--environment` o argumento desconocido) |
| 3 | Sistema operativo no soportado (requiere Ubuntu 24.04) |
| 4 | El script no se ejecutó como root |
| 5 | No existe `environments/<env>/.env` |

## Variables requeridas

Ver [`environments/README.md`](../environments/README.md) para la lista completa. Este sprint añade:

- `DEPLOY_USER` — nombre del usuario de despliegue no-root (p.ej. `deploy`)
- `DEPLOY_USER_SSH_PUBLIC_KEY` — contenido de la clave pública SSH que tendrá acceso

## Cómo actualizarlo

`bootstrap/` no gestiona actualizaciones de versión de paquetes más allá de `unattended-upgrades` (parches de seguridad automáticos). Para cambios de paquetes base, edita `BASE_PACKAGES` en `packages.sh` y vuelve a ejecutar `./bootstrap/install.sh --environment <env>` — es idempotente y solo instalará lo que falte.

## Troubleshooting

Ver [`docs/troubleshooting.md`](../docs/troubleshooting.md). Para depurar un fallo puntual, cada script puede ejecutarse solo, por ejemplo:

```bash
sudo ./bootstrap/users.sh --environment prod
```
