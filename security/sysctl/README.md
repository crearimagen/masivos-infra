# security/sysctl/

Parámetros de kernel endurecidos, aplicados vía `/etc/sysctl.d/99-masivos-hardening.conf`.

## Qué hace

Anti-spoofing, rechazo de ICMP redirects y source routing, protección SYN flood, ASLR completo, protección de hardlinks/symlinks — ver comentarios en [`99-masivos-hardening.conf`](99-masivos-hardening.conf) para el detalle de cada parámetro.

**Importante:** `net.ipv4.ip_forward = 1` se mantiene activo a propósito. Docker (Sprint 3) lo requiere para el NAT/enrutamiento de `masivos-network`; desactivarlo (como recomiendan la mayoría de guías de hardening genéricas) rompería todo el stack. El script verifica este valor después de aplicar y falla si no es `1`.

## Cómo instalarlo

```bash
sudo ./security/sysctl/apply-sysctl.sh --environment prod
```

## Cómo actualizarlo

Edita `99-masivos-hardening.conf` y vuelve a ejecutar el script.

## Verificación

```bash
sudo sysctl -a | grep -E 'ip_forward|rp_filter|syncookies'
```
