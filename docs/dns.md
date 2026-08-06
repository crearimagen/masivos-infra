# DNS y TLS

Estrategia de DNS y emisión de certificados para Masivos.app. Proveedor: **Cloudflare**. Validación de Let's Encrypt: **DNS-01** vía `certbot-dns-cloudflare`.

## Por qué DNS-01 en lugar de HTTP-01

1. Permite emitir un único certificado que cubra el apex y `*.masivos.app` (wildcard), evitando repetir la emisión por cada subdominio nuevo que se agregue (paneles, tracking, entornos).
2. No depende de que el puerto 80 esté accesible en el momento exacto de la renovación — relevante porque Fail2Ban/UFW (Sprint 2) pueden bloquear tráfico temporalmente.
3. Se automatiza sin exponer superficie HTTP adicional durante el proceso de emisión.

## Regla operativa: registros de correo en DNS-only

Cualquier registro relacionado con envío/recepción de correo (`mail.<dominio>`, el `MX`, y el `A`/`AAAA` que resuelve la IP de envío SMTP) debe permanecer en Cloudflare como **DNS only (nube gris)**. El proxy de Cloudflare (nube naranja) solo termina HTTP/HTTPS — si se activa sobre estos registros, rompe SMTP directo y puede dañar la reputación de la IP de envío. El proxy naranja es opcional y solo aceptable en subdominios puramente HTTP sin relación con el envío (p.ej. `status.<dominio>` si se quisiera ocultar el origen), y por defecto los dejaremos también en DNS-only para simplificar el troubleshooting.

## Subdominios por entorno

Cada entorno (`dev`, `test`, `prod`) usa su propio subdominio raíz para no mezclar reputación de IP ni certificados:

| Entorno | Dominio raíz de ejemplo |
|---|---|
| prod | `masivos.app` |
| test | `test.masivos.app` |
| dev | `dev.masivos.app` |

`environments/<env>/.env` define `DOMAIN_ROOT` con el valor correspondiente.

## Registros DNS requeridos (por entorno)

Sustituir `<DOMAIN_ROOT>` y `<SERVER_IP>` por los valores reales del entorno. Los valores de DKIM/SPF exactos los genera Postal al crear el "mail server" — este documento fija el nombre del registro, el contenido final se documenta en `services/postal/README.md` durante el Sprint 7.

| Tipo | Nombre | Valor | Proxy Cloudflare | Propósito |
|---|---|---|---|---|
| A | `<DOMAIN_ROOT>` | `<SERVER_IP>` | DNS only | Apex — panel web / API |
| A | `mail.<DOMAIN_ROOT>` | `<SERVER_IP>` | DNS only | Hostname HELO/rDNS de Postal |
| MX | `<DOMAIN_ROOT>` | `mail.<DOMAIN_ROOT>` (prioridad 10) | — | Recepción de correo entrante |
| TXT | `<DOMAIN_ROOT>` | `v=spf1 a mx include:spf.<DOMAIN_ROOT> ~all` | — | SPF |
| TXT | `psrp._domainkey.<DOMAIN_ROOT>` | (generado por Postal) | — | DKIM |
| TXT | `_dmarc.<DOMAIN_ROOT>` | `v=DMARC1; p=quarantine; rua=mailto:dmarc@<DOMAIN_ROOT>` | — | DMARC |
| TXT | `track.<DOMAIN_ROOT>` (si se usa dominio de tracking separado) | ver Postal | DNS only | Links/opens tracking |
| A | `grafana.<DOMAIN_ROOT>` | `<SERVER_IP>` | DNS only (opcional naranja) | Dashboard Grafana vía Nginx |
| A | `status.<DOMAIN_ROOT>` | `<SERVER_IP>` | DNS only (opcional naranja) | Uptime Kuma público vía Nginx |

**PTR (rDNS):** no se gestiona en Cloudflare — se configura en el panel del proveedor de VPS (Hetzner, DigitalOcean, OVH, etc.) apuntando `<SERVER_IP>` → `mail.<DOMAIN_ROOT>`. Es obligatorio para que los principales proveedores de correo (Gmail, Outlook) acepten el tráfico SMTP saliente; se valida en `scripts/validate.sh` en un sprint posterior.

## Token de API de Cloudflare

`certbot-dns-cloudflare` necesita un token con el scope mínimo:

- **Zone : DNS : Edit**, restringido a la zona `<DOMAIN_ROOT>` del entorno correspondiente.

Se genera en Cloudflare → *My Profile → API Tokens → Create Token → Edit zone DNS*. El token se guarda en `environments/<env>/.env` como `CLOUDFLARE_API_TOKEN` y **nunca se versiona** (cubierto por `.gitignore`). El script de emisión de certificados (`services/nginx/scripts/`, Sprint 8) lo consumirá para escribir el archivo de credenciales de certbot en tiempo de ejecución, con permisos `600`.

## Flujo de emisión (resumen — implementación en Sprint 8)

1. `scripts/deploy.sh` carga `environments/<env>/.env`.
2. Se genera `~/.secrets/cloudflare.ini` (permisos `600`, fuera del repo) con `dns_cloudflare_api_token = <valor>`.
3. `certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/cloudflare.ini -d <DOMAIN_ROOT> -d *.<DOMAIN_ROOT>`.
4. El certificado resultante se monta en `masivos-nginx` vía volumen `masivos-nginx-data`.
5. Renovación automática vía systemd timer (`certbot renew`), validada por `scripts/healthcheck.sh`.

## Referencia cruzada

- Puertos y topología general: [`docs/architecture.md`](architecture.md)
- Variables de entorno por servidor: [`environments/README.md`](../environments/README.md)
