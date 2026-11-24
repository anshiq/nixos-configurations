# Lifecycle, safety, registry

## Registry

SQLite, stdlib only, at `$XDG_DATA_HOME/devinfra/registry.db`
(fallback `~/.local/share/devinfra/registry.db`):

- `services(name, container_id, container_name, image, version, digest,
  service_type, scope, network, ports, volumes, status, last_verified,
  unmanaged)`
- `dependencies(service, project, db_name, db_user, namespace, created_at)`
  with `UNIQUE(service, project, db_name)`.

Behavior:

- Every `services list/inspect/ensure` reconciles: `docker inspect` each
  stored container ID; missing ID => `status='missing'`; image drift =>
  update + flag; external changes are reported, never auto-overwritten
  destructively.
- Credentials are NEVER stored (no password columns at all).
- Unmanaged containers (found in `docker ps` but not in registry) are
  reported as `unmanaged` candidates; adoption requires explicit
  `ensure --adopt <container>`-style authorization (implemented as
  `ensure` matching by name+image and recording the existing container
  ID only after user confirm).

## Dependency tracking / refcounting

- Each `database create` inserts one `dependencies` row (idempotent).
- A shared service may be removed/stopped ONLY when zero dependent
  projects remain AND user confirms. `cleanup --project X` deletes only
  that project's rows by default.
- Databases are dropped ONLY with `--include-databases --yes` (explicit).
  Volumes are never auto-removed; `docker volume rm` requires the volume
  to have zero dependents + explicit confirm.
- Never run `docker system prune` / `prune -a` as routine management.

## Cleanup contract

```bash
scripts/devinfra cleanup --project todo --dry-run   # preview (default safe)
scripts/devinfra cleanup --project todo              # unregister project rows only
scripts/devinfra cleanup --project todo --include-databases --yes
```

- One project's cleanup never removes a service/volume used by another
  project (checked via remaining `dependencies` rows).
- Ephemeral services (`scope='ephemeral'`, name like `<proj>-test-*`)
  with no remaining dependents are stopped/removed; shared services are
  left running.
- `--dry-run` prints planned actions, changes nothing, exits 0.

## Health / recovery / backup

- `services inspect` shows `docker inspect` State + Health + last probe.
- Recovery guidance (never auto-restart someone else's container):
  `docker logs <name>`, `docker restart <name>` only if registry shows
  manager-owned AND user confirms; otherwise hand to owner.
- Backups: named volumes hold data; before destructive work advise
  `docker exec postgres pg_dump <db> > backup.sql` or volume snapshot.
  No automatic backup engine in v1.

## Concurrency

- `ensure`/`database create` wrap registry writes in a transaction +
  `flock` on `<db>.lock`. Concurrent identical requests serialize; the
  second sees the first's row and reuses (no duplicates). Tests cover
  this with a threaded fake runner.

## Ownership

- `unmanaged=1` rows are read-only: `ensure` will not stop/modify them
  without authorization; `cleanup` never touches them.
- Container identity = Docker container ID, never bare name (names can
  collide across Compose projects).
