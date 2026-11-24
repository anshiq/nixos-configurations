---
name: devinfra
description: Use when the user asks for a new app, infrastructure dependency, Docker Compose file, database, cache, or emulator container (postgres, redis, mongodb, rabbitmq, localstack, elasticsearch). Discovers and reuses existing local Docker images, containers, networks, and the devinfra registry before provisioning anything new; generates Compose files that join shared infrastructure instead of duplicating it.
version: 1
metadata:
  short-description: Shared local Docker infrastructure manager
---

# devinfra — Shared Local Docker Infrastructure Manager

Never create a Docker container just because a project has a new name.
Before provisioning, you MUST discover what already exists and reuse it
when safe.

## When to use

- User asks for a new application, backend, `docker-compose.yml`,
  `Dockerfile` setup, database, cache, queue, or emulator.
- User asks to "dockerize", "add postgres/redis/mongo", or wire up
  `DATABASE_URL` / `REDIS_URL` / similar.
- Any task that would otherwise run `docker run` or add an infra
  `services:` block.

Do NOT apply reuse logic to production/CI manifests unless the user says
the same host reuse applies there. Production wants isolated resources.

## Mandatory workflow

Follow the deterministic workflow (details in
`references/provisioning-workflow.md`):

```text
Requirements -> Inspect registry + docker state -> Find compatible service
  -> Found? check health/network/isolation : check local images -> pull if needed -> provision
  -> Create project data + restricted credentials -> Wire networking
  -> Verify connectivity + register -> Report reused vs created (no secrets)
```

Concretely, run in this order:

1. **Requirements.** Identify needed services + versions from the request,
   lockfiles, ORM config, docs. Note any explicit isolation request
   (`project-scoped`, `ephemeral`, `dedicated`, pinned version).
2. **Discovery (read-only).** Run:
   ```bash
   scripts/devinfra services list
   docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
   docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}'
   docker network ls
   ```
   Never start/stop/delete/reconfigure during discovery. Treat unknown
   containers as externally owned until proven otherwise.
3. **Reuse decision.** Apply `references/reuse-policies.md`. Default policy
   is `shared-if-compatible` for postgres, redis, mongodb, localstack.
   Major-version mismatch, unhealthy container, incompatible config, or
   isolation request => do NOT reuse; provision dedicated/ephemeral.
   Never silently upgrade a shared service for one app.
4. **Provision (only if needed).** Prefer idempotent helper:
   ```bash
   scripts/devinfra ensure <name> --version <major> --scope <policy>
   scripts/devinfra database create <service> --name <db> --project <proj>
   scripts/devinfra connection <service> --project <proj>
   ```
   The helper reuses local images before pulling, creates the
   manager-owned `dev-services` network if missing, and is safe to rerun
   (no duplicate containers/databases). Use `--dry-run` first for any
   destructive or cross-project action.
5. **Compose.** Generate with `scripts/devinfra compose generate`
   (see `references/compose-guide.md`). Omit reused shared services from
   `services:`; join the external `dev-services` network; pass connection
   strings via `${VAR}` env placeholders, never hardcoded secrets.
6. **Verify + report.** `docker exec` health check / app connectivity
   probe, then `services inspect <name>`. Summarize: what was reused
   (container ID prefix, new DB/namespace inside it), what is net-new and
   why, and the env vars to set — with passwords redacted.

## Service rules (summary)

- **Naming:** canonical manager-owned names `postgres`, `redis`,
  `mongodb`, `localstack`, `rabbitmq`, `elasticsearch` on network
  `dev-services`. Never invent `todo-postgres`-style clones when the
  shared instance is compatible. Names alone never prove safety — verify
  container IDs + registry + `docker inspect`.
- **Isolation:** postgres => separate DB + least-privilege user per
  project; redis => key prefix or DB index (no strong isolation — use
  dedicated instance for hostile/incompatible workloads); mongodb =>
  separate DB + db-scoped role; localstack => unique resource names per
  project; rabbitmq/elasticsearch only per `references/isolation.md`.
  Full rules: `references/isolation.md`.
- **Registry:** SQLite at
  `$XDG_DATA_HOME/devinfra/registry.db` (`~/.local/share/devinfra/`),
  tables `services` + `dependencies`. It is a management record, not
  truth — always reconcile against `docker inspect`. Never store
  passwords there. See `references/lifecycle-safety.md`.
- **Safety:** never `docker system prune`, never delete a shared
  container/volume with live dependents, never delete a database without
  explicit user authorization, never expose DB ports publicly without
  requirement, never mount the Docker socket into app containers.
  Destructive paths require `--dry-run` preview + explicit confirm.

## Command interface

All commands are idempotent; reruns create nothing new:

```bash
scripts/devinfra services list
scripts/devinfra services inspect postgres
scripts/devinfra services users postgres
scripts/devinfra ensure postgres --version 17 --scope shared
scripts/devinfra database create postgres --name todo_db --project todo
scripts/devinfra connection postgres --project todo
scripts/devinfra cleanup --project todo --dry-run
scripts/devinfra compose generate --project todo --services postgres,redis
```

Full CLI contract, exit codes, and JSON modes: run
`scripts/devinfra --help` / `<subcommand> --help`.

## References (read on demand)

- `references/reuse-policies.md` — policy table + compatibility matrix.
- `references/isolation.md` — per-service namespacing recipes.
- `references/provisioning-workflow.md` — step-by-step decision tree +
  failure handling.
- `references/compose-guide.md` — shared vs standalone Compose patterns.
- `references/lifecycle-safety.md` — refcounting, cleanup, backup,
  concurrency, ownership.

## Examples

- `examples/postgres-redis-compose.yaml` — app joining shared infra.
- `examples/standalone-compose.yaml` — isolated fallback.
