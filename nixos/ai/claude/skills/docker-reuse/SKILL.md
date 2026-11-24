---
name: docker-reuse
description: Use when asked to create/write a docker-compose file, Dockerfile, or "dockerize" a project (e.g. "create a docker compose for this project", "add postgres to docker-compose", "dockerize this repo"). Before creating any new container definition, inspects existing local Docker containers and images and reuses them instead of spinning up redundant duplicates — reuse a running container of the same kind (e.g. an existing postgres container, just add a new database inside it) when the app doesn't need isolation; otherwise reuse the already-pulled image (same tag) instead of pulling a new one; only introduce a brand-new image/version when the project explicitly pins a version/tag that differs from what's available locally.
---

# Docker Reuse

Goal: never let a new project's docker-compose silently duplicate infrastructure
that already exists on this machine. Every time you are asked to produce or
edit a docker-compose (or Dockerfile-based) setup, follow this decision order
before writing any `services:` block.

## Step 1 — Inventory what already exists

Run these before writing anything:

```bash
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}'
docker network ls --format '{{.Name}}\t{{.Driver}}'
docker volume ls --format '{{.Name}}\t{{.Driver}}'
```

Also check for compose projects already managing these containers:

```bash
docker compose ls
```

Build a mental map: for each service kind the new project needs (postgres,
redis, mysql, mongo, rabbitmq, minio, elasticsearch, etc.), note:
- Is a container of that kind already **running**? Which image/tag, which
  exposed port, which compose project (if any) owns it?
- Is the **image** already pulled locally, even if no container is running?

## Step 2 — Decide reuse vs. new, per service, in this priority order

1. **Reuse a running container directly** (preferred, avoids redundant
   resources) — valid when:
   - The project does NOT require a specific/pinned version that conflicts
     with what's running (check the user's request, `package.json`,
     `requirements.txt`, ORM config, or existing lockfiles for a required
     major version).
   - The service is the kind where multiple logical apps commonly share one
     server process by namespacing data instead of the whole container —
     e.g. Postgres/MySQL/MongoDB (create a new database/schema + user inside
     the existing instance), Redis (use a distinct DB index or key prefix),
     RabbitMQ (use a new vhost).
   - Action: do NOT add that service to the new project's docker-compose at
     all. Instead:
     - Create the new database/vhost/namespace inside the existing container
       (e.g. `docker exec <container> psql -U postgres -c "CREATE DATABASE
       <app>_db;"`).
     - Point the new project's `.env`/config at the existing container's
       host port and network (join its existing Docker network if the new
       project needs container-to-container access instead of localhost).
     - Note this decision to the user explicitly: which container is being
       reused and what was created inside it.

2. **Reuse the already-pulled image, new container** — valid when reuse-in-place
   (step 1) isn't appropriate (e.g. the app needs total isolation, its own
   lifecycle, a different config file mounted at the same path, or the
   existing container is managed by an unrelated project the user shouldn't
   touch) but an image with the exact same repository:tag is already present
   locally.
   - Action: reference that exact image/tag in the compose file. Do not pull
     or build a new one. Give the new container a distinct name/port/volume
     so it doesn't collide with the existing one.

3. **Pull/introduce a new image or version** — only when:
   - The project explicitly pins a version/tag not available locally, or
   - The available local image/version is incompatible (e.g. app requires
     Postgres 16 features, only Postgres 13 is running), or
   - No image of that kind exists locally at all.
   - Action: use the minimal, official image tag that satisfies the actual
     requirement — don't default to `latest` if a version is implied
     elsewhere in the project (lockfile, docs, CI config).

Never duplicate a resource "just to be safe." If reuse is possible per the
rules above, reuse it — that's the whole point of this skill.

## Step 3 — Write the docker-compose

- For services you're reusing via Step 1: omit them from `services:`
  entirely. Instead add a short comment block at the top of the compose file
  documenting what's reused and how to connect to it (host, port, db name,
  network).
- For services from Step 2/3: define them normally, using `image:` (not
  `build:`) with the exact reused tag when applicable, and join the existing
  external network if cross-container communication is needed:

  ```yaml
  networks:
    default:
      external: true
      name: <existing-network-name>
  ```

- Use named volumes for state and give them project-specific names so they
  don't collide with the reused/existing container's volumes.
- Set env vars (`DATABASE_URL`, `REDIS_URL`, etc.) to point at whichever
  host/container/port was actually decided on above.

## Step 4 — Report back to the user

Always summarize, in plain terms, before/after applying:
- Which existing containers/images were detected.
- Which ones are being reused, and how (shared instance + new DB, vs. shared
  image + new container).
- Which services are net-new and why (version mismatch, isolation need, or
  genuinely nothing existed locally).

If reusing a running container requires creating a new database/user inside
it, running `docker exec` to do so counts as a state-changing action —
confirm with the user before running it, same as any other action that
touches infra outside the current project.

## Notes

- This applies to local/dev docker-compose setups. Do not apply "reuse"
  logic to production/CI compose files unless the user says the same
  physical/infra reuse applies there too — production usually wants
  isolated, versioned, per-app resources.
- If `docker` isn't running or accessible, say so and fall back to writing a
  normal self-contained compose file, noting that reuse detection was
  skipped.
