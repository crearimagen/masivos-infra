# services/postal/templates/

- `dns-records.txt` — plantilla de los registros DNS que deben configurarse en Cloudflare para este entorno, con placeholders que corresponden a las variables de `services/postal/.env`. No se renderiza automáticamente (no hay secretos aquí, solo nombres de dominio) — sustituye los placeholders a mano o con `sed` al preparar el DNS de un entorno nuevo. Ver [`docs/dns.md`](../../../docs/dns.md) para el detalle completo de cada registro.
