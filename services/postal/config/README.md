# services/postal/config/

Montado de solo lectura en `/config` dentro de los cuatro contenedores de Postal (`web`, `smtp`, `worker`, `runner`).

## Contenido

- `postal.yml` — deliberadamente casi vacío. Toda la configuración real vive en `services/postal/.env` (convención de variables de entorno de Postal — ver comentario en `.env.example`), no aquí. Ver la nota en el propio archivo sobre por qué no está completamente vacío.
- `signing.key` — **no versionado**, generado por `scripts/generate-signing-key.sh`. Clave privada usada por Postal para firmar mensajes/tokens.

## Por qué no se usa un `postal.yml` completo

El resto de este repositorio configura cada servicio exclusivamente vía `.env` (Postgres, MariaDB, Redis, RabbitMQ). Postal permite el mismo patrón — cualquier clave de `postal.yml` tiene una variable de entorno equivalente — así que se mantiene la consistencia en vez de introducir un mecanismo de configuración distinto solo para este servicio.

## Generar `signing.key`

```bash
./services/postal/scripts/generate-signing-key.sh
```

Idempotente: si el archivo ya existe, no lo sobreescribe.
