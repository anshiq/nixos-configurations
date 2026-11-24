# Provisioning workflow

Deterministic order. Each step has an explicit failure action.

```text
Requirements -> registry+docker inspect -> compatible service?
  Found -> health/network/isolation check -> pass? reuse : dedicated path
  Not found -> local image? pull if needed -> provision -> ...
  -> project data + credentials -> networking -> verify + register -> report
```

## 1. Requirements

Extract: service kinds, major versions, extensions/plugins, network
needs (container-to-container vs localhost), persistence needs,
isolation scope. Sources: user request, lockfiles, ORM config, docs.
Record the requested `--scope` (default `shared-if-compatible`).

## 2. Inspect (read-only)

```bash
scripts/devinfra services list          # registry reconciled with docker
docker ps -a --format '...'
docker images --format '...'
docker network inspect dev-services     # or docker network ls
```

Do NOT start/stop/delete/upgrade to make discovery easier.

## 3. Match

`ensure` logic (same in helper and by hand):

1. Registry hit with same canonical name + major version + scope allows
   sharing => `docker inspect` the container ID.
2. `docker inspect` shows running + healthy + on/attachable to
   `dev-services` + config compatible => REUSE.
3. Else: `docker images` has compatible `repo:tag` => create container
   from local image (no pull).
4. Else: `docker pull` the minimal official tag, then create.
5. Creation always: `--name <canonical> [--suffix for dedicated]`,
   `--network dev-services` (create network first if missing),
   named volume, no public port unless required, health check.

Concurrency: helper takes an `flock` on the registry DB; second
concurrent `ensure` waits and then sees the first one's result (no
duplicates). Manual flows: re-list before creating.

## 4. Project data + credentials

- postgres: `database create` (idempotent `CREATE DATABASE IF NOT
  EXISTS`-equivalent + least-privilege user). Redis/mongo/localstack:
  record namespace per `isolation.md`.
- Passwords: random 24+ chars, applied once, shown once, never logged
  or stored. Registry stores `(service, project, db_name, db_user)` only.

## 5. Networking + connection

- Ensure app joins `dev-services` (external network in Compose) or uses
  mapped host port for localhost dev.
- `connection --project` prints host/port/db/network/alias with secrets
  redacted (`****`, `${VAR}` placeholders).

## 6. Verify + register + report

- Verify: `pg_isready` / `redis-cli ping` / driver connect from app net.
  Do NOT claim ready before a passing probe.
- Register dependency in SQLite (`dependencies` row). Update
  `services.last_verified`.
- Report: reused (container ID, image, what namespace was added) vs
  created (why: version mismatch / unhealthy / isolation / nothing
  existed). Include exact env vars with secret values masked.

## Failure handling

| Failure | Action |
|---|---|
| Docker daemon down | Abort, say so, offer standalone Compose fallback note |
| No compatible service + pull fails (offline) | Abort, list local images, suggest closest compatible or dedicated build |
| Version incompatible | Dedicated instance, never upgrade shared |
| Unhealthy shared container | Do not reuse; guide recovery (`docker logs`, restart by OWNER only), offer dedicated |
| Network missing | Create `dev-services` (safe, idempotent) then attach |
| Auth failure | Do not retry with stored secrets (none stored); ask user for admin DSN once via env |
| Provisioning fails | Report failing step + next safe action; leave no half-registered rows (transaction) |
