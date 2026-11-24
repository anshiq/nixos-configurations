# Reuse policies

Default: `shared-if-compatible` for services that support safe sharing
(postgres, redis, mongodb, localstack). Everything else defaults to
`project-scoped` until an explicit isolation rule exists for it.

| Policy | Meaning | When to use |
|---|---|---|
| `shared` | Prefer the common instance; reuse when requirements met | Stateless-compatible caches, emulator with namespaced resources, user explicitly wants sharing |
| `shared-if-compatible` | Reuse ONLY if version + config + network + persistence + isolation all compatible | Default for postgres/redis/mongodb/localstack |
| `project-scoped` | Dedicated instance for one project | Explicit isolation request, incompatible version/config, hostile multi-tenant data |
| `ephemeral` | Disposable instance for a test/task, with explicit cleanup | `*-test-*` containers, CI task runners; must set cleanup rule at creation |
| `dedicated` | Always a separate instance | User said "isolated", "own", "don't share", or pinned version conflicts |

## Compatibility checklist (all must pass for reuse)

1. **Version:** same major version (postgres 16 != 17, redis 7 != 8,
   mongo 7 != 8). Minor/patch differences are compatible. `latest` tag
   never counts as compatible — resolve it to a digest first.
2. **Health:** container `State.Running` and health `healthy` (or
   service-specific probe passes: `pg_isready`, `redis-cli ping`,
   `mongosh --eval db.runCommand({ping:1})`). Unhealthy => do not reuse;
   report and offer dedicated provisioning.
3. **Network:** container attached to `dev-services` (or attachable
   without restart). If the app must reach it container-to-container,
   both must share a network.
4. **Persistence:** shared service has a named volume; project data goes
   in a namespaced DB/prefix/vhost, never in shared tables/keys.
5. **Config:** server settings compatible (e.g. redis `maxmemory-policy`,
   postgres extensions, localstack `SERVICES` set). Incompatible flags =>
   dedicated instance.
6. **Isolation:** a namespacing mechanism exists AND is applied
   (see `isolation.md`). No mechanism => no sharing.
7. **Ownership:** registry says manager-owned OR container is unmanaged
   but owner explicitly authorized reuse. Never "adopt" an unmanaged
   container silently — record `unmanaged=1` until authorized.

## Overrides

- User says "isolated / dedicated / own / don't touch X / version N /
  disposable test" => honor it even if reuse would be compatible.
- One app's version requirement NEVER upgrades a shared service.
  Provision a dedicated instance for that app instead.
- When in doubt between unsafe reuse and safe dedicated => dedicated.
