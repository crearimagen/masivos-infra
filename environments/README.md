# environments/

Cada subcarpeta (`dev/`, `test/`, `prod/`) representa un **servidor físico o VM independiente**, no un stack Docker paralelo en la misma máquina. Ver la justificación completa en [`docs/architecture.md`](../docs/architecture.md#modelo-de-entornos).

El código de `services/*` es idéntico entre entornos. Lo único que cambia por entorno es el archivo de variables globales `.env`, que `scripts/deploy.sh` carga y propaga a los `.env` de cada servicio.

## Uso

En el servidor del entorno correspondiente:

```bash
cp environments/prod/.env.example environments/prod/.env
# editar environments/prod/.env con los valores reales del servidor
./scripts/deploy.sh --environment prod
```

`environments/<env>/.env` **nunca se versiona** (excluido por el `.gitignore` raíz); solo se versiona `.env.example`.

## Variables definidas

| Variable | Descripción |
|---|---|
| `ENVIRONMENT_NAME` | `dev`, `test` o `prod` — usado para prefijar logs y validaciones |
| `DOMAIN_ROOT` | Dominio raíz del entorno (p.ej. `masivos.app`, `test.masivos.app`) |
| `SERVER_PUBLIC_IP` | IP pública del servidor — usada para validar registros DNS en `scripts/validate.sh` |
| `TLS_ADMIN_EMAIL` | Email de contacto para Let's Encrypt (avisos de expiración) |
| `CLOUDFLARE_API_TOKEN` | Token con scope `Zone:DNS:Edit` sobre `DOMAIN_ROOT` — ver [`docs/dns.md`](../docs/dns.md) |
| `TIMEZONE` | Timezone del servidor, formato IANA (p.ej. `America/El_Salvador`) |
| `DOCKER_NETWORK_SUBNET` | Subnet fija para `masivos-network` (evita colisiones con el rango por defecto de Docker) |

## Referencia cruzada

- Topología de red y puertos: [`docs/architecture.md`](../docs/architecture.md)
- Estrategia DNS/TLS: [`docs/dns.md`](../docs/dns.md)
