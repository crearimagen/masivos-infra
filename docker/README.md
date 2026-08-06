# docker/

Instala Docker Engine, configura el daemon para producción, y crea la red y los volúmenes compartidos por `services/*`. Se ejecuta después de `security/hardening.sh` y antes de desplegar cualquier servicio.

## Qué hace

| Archivo | Responsabilidad |
|---|---|
| `install.sh` | Instala Docker Engine desde el repo oficial, aplica `daemon.json`, agrega `DEPLOY_USER` al grupo `docker`, ejecuta `networks.sh` y `volumes.sh`. |
| `daemon.json` | Configuración de producción: logging con rotación, `live-restore`, `userland-proxy: false`, ulimits altos. |
| `networks.sh` | Crea `masivos-network` (bridge) con la subnet de `DOCKER_NETWORK_SUBNET`. |
| `volumes.sh` | Crea los 5 volúmenes nombrados (`masivos-postgres-data`, etc.). |
| `validate.sh` | Verifica (sin modificar nada) que todo lo anterior esté correctamente aplicado. |
| `compose/` | Compose principal que agrega los `docker-compose.yml` de `services/*` vía `include:`. |

## Cómo instalarlo

```bash
sudo ./docker/install.sh --environment prod
```

Requiere que `security/hardening.sh --environment prod` se haya ejecutado antes: `docker/install.sh` depende de `net.ipv4.ip_forward=1`, que `security/sysctl/` garantiza explícitamente (ver [`docs/security.md`](../docs/security.md)).

## Cómo validarlo

```bash
./docker/validate.sh --environment prod
```

No requiere `root`; cualquier usuario en el grupo `docker` puede ejecutarlo.

## Cómo actualizarlo

Docker Engine se actualiza vía `apt` (cubierto por `unattended-upgrades`, configurado en `bootstrap/packages.sh`, para parches menores). Para cambiar `daemon.json`, edítalo y vuelve a ejecutar `./docker/install.sh --environment <env>` — es idempotente: solo reinicia el daemon si el contenido cambió, y `live-restore: true` mantiene los contenedores corriendo durante el reinicio.

## Notas de diseño

- `docker/networks.sh` **nunca recrea automáticamente** una red existente con una subnet distinta a la esperada — eso desconectaría contenedores en ejecución. Si detecta un desajuste, falla explícitamente y pide intervención manual.
- La lista `include:` de `docker/compose/docker-compose.yml` crece con cada sprint de `services/*` — ver [`docker/compose/README.md`](compose/README.md).

## Troubleshooting

Ver [`docs/troubleshooting.md`](../docs/troubleshooting.md). Para depurar, cada script acepta `--help` y puede ejecutarse de forma individual.
