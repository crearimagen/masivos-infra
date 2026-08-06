# services/nginx/conf.d/_postal_proxy_headers.inc
# Cabeceras de proxy compartidas para las location blocks que apuntan a
# postal_web. Extension .inc (no .conf) a proposito: nginx.conf solo hace
# "include conf.d/*.conf", este archivo no debe cargarse como bloque de
# nivel superior, solo via "include" explicito dentro de un location.
# Sin contenido especifico de dominio - no es una plantilla, se versiona
# tal cual.

proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_http_version 1.1;
proxy_set_header Connection "";
proxy_connect_timeout 10s;
proxy_read_timeout 60s;
