# Service-specific isolation

Sharing a container never means sharing rows/keys indiscriminately.
Create a namespace per project + least-privilege credentials.

## PostgreSQL (priority 1)

- One compatible server (`postgres` on `dev-services`).
- Per project: `CREATE DATABASE <project>_db` + `CREATE USER <project>_user
  WITH PASSWORD '<random>'` + `GRANT ALL PRIVILEGES ON DATABASE` +
  `ALTER SCHEMA public OWNER TO` / scoped grants. No superuser, no
  `postgres`-role sharing between apps.
- Credential handling: password is generated, applied once via
  `docker exec`, printed once for the user to store in project `.env`.
  It is NEVER written to the registry (only db name + user + project).
- Never `DROP DATABASE` without explicit user/cleanup authorization
  (`cleanup --include-databases --yes`).

Example: `postgres` holds `todo_db`, `notes_db`, `ecommerce_db`, each
with its own `_user`.

## Redis (priority 1)

- Shared server when `maxmemory-policy`, persistence (AOF/RDB), and
  workload are compatible.
- Namespacing: key prefix `"<project>:"` (preferred, works with all
  clients) or logical DB index `SELECT <n>` recorded in registry.
- Document to the user: prefixes/DB indexes are NOT security or noisy-
  neighbor isolation. Incompatible settings, eviction-sensitive
  workloads, or untrusted tenants => dedicated instance.
- No `FLUSHALL` ever on a shared instance; `FLUSHDB` only on a
  project-dedicated DB index with confirmation.

## MongoDB

- Separate database per project (`use <project>_db`), db-scoped user:
  `db.createUser({user, pwd, roles:[{role:"readWrite",db:"<project>_db"}]})`.
- Verify auth is enabled (`--auth` / `MONGO_INITDB_ROOT_*` set at
  provisioning). If the shared instance runs with `--noauth`, do NOT
  share across trust boundaries — provision dedicated with auth.

## LocalStack

- One emulator when `SERVICES` sets overlap and versions match.
- Isolation via unique resource names (`<project>-<resource>`) and
  project-aware config (separate buckets/queues/tables per project).
- AWS-service caveat: the emulator shares account/region state; cross-
  project listing is possible. Tenants that must not see each other's
  resource names => dedicated emulator.

## RabbitMQ

- Share only with explicit vhost per project (`rabbitmqadmin declare
  vhost name=<project>`) + scoped user (`set_permissions -p <project>`).
- No sharing if the app needs custom plugins/exchanges at server scope
  or incompatible `rabbitmq.conf`.

## Elasticsearch

- Share only with per-project index prefix (`<project>-*`) + API key /
  role restricted to that prefix. Different major versions (7 vs 8,
  security-on vs off) are incompatible => dedicated instance.
- Never share when index templates/ILM policies would collide.

## Rule of last resort

If a service has no documented isolation recipe above, treat it as
non-shareable (`project-scoped`) until a recipe is written and reviewed.
