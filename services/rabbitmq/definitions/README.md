# services/rabbitmq/definitions/

Extension point para definiciones declarativas de RabbitMQ (exchanges, colas, bindings, políticas) cargadas al inicio vía `management.load_definitions` — **deliberadamente vacío en este sprint**.

El vhost y el usuario de administración ya se resuelven mediante `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` / `RABBITMQ_DEFAULT_VHOST` en `services/rabbitmq/.env`, procesados por el entrypoint oficial de la imagen en el primer arranque — no requieren un `definitions.json`.

La topología real de colas/exchanges depende de cómo Postal (Sprint 7) publique y consuma mensajes, que todavía no está implementado. Cuando se conozca, se añadirá aquí un `definitions.json` y se referenciará desde `config/rabbitmq.conf` con:

```
management.load_definitions = /etc/rabbitmq/definitions.json
```

No se inventa esa topología ahora para evitar documentar/versionar exchanges o colas que no existen todavía.
