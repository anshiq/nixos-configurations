# Compose guide

## Shared (preferred when reuse applies)

Omit shared services from `services:`. The app joins the existing
external network and points at stable DNS names.

```yaml
services:
  app:
    build: .
    environment:
      DATABASE_URL: ${DATABASE_URL}   # postgres://<project>_user:****@postgres:5432/<project>_db
      REDIS_URL: ${REDIS_URL}         # redis://redis:6379/0, keys prefixed "<project>:"
    depends_on: []
    networks:
      - shared-dev

networks:
  shared-dev:
    external: true
    name: dev-services
```

Rules:

- No `postgres:` / `redis:` blocks when they come from shared infra.
- `DATABASE_URL` / `REDIS_URL` via `${VAR}` — never hardcoded passwords.
- Use service DNS (`postgres`, `redis`) on `dev-services` for
  container-to-container; use host port only for localhost dev.
- Avoid `ports:` on DB services you don't own. The app's own port only.
- Named volumes only for services you actually declare.

Generate with:

```bash
scripts/devinfra compose generate --project todo --services postgres,redis
```

## Standalone (fallback)

When shared infra is unavailable/unsuitable (daemon down, version
conflict, explicit isolation), declare project-scoped deps explicitly:

```yaml
services:
  app:
    build: .
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@todo-postgres:5432/${POSTGRES_DB}
    networks:
      - default
  todo-postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-todo_db}
      POSTGRES_USER: ${POSTGRES_USER:-todo_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}
    volumes:
      - todo-pgdata:/var/lib/postgresql/data
    networks:
      - default

volumes:
  todo-pgdata:
```

Generate with `compose generate --standalone`. Note in the file header
why standalone was chosen (version X required vs shared Y, isolation
request, daemon unreachable).

See `examples/postgres-redis-compose.yaml` and
`examples/standalone-compose.yaml`.
