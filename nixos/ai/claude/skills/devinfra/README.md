# devinfra skill

Shared local Docker infrastructure manager. Agents discover and reuse
existing images/containers/networks before provisioning anything new.

## Install

This skill is installed per-agent as plain directories (no build step):

- Claude: `~/.claude/skills/devinfra/` (user skill, auto-discovered)
- Codex: `~/.codex/skills/devinfra/`
- OpenCode: `~/.config/opencode/skills/devinfra/`

All three contain the same content. Copy (or re-copy) with:

```bash
SRC=/tmp/opencode/devinfra-skill/devinfra  # staging path used at build time
mkdir -p ~/.claude/skills ~/.codex/skills ~/.config/opencode/skills
cp -r "$SRC" ~/.claude/skills/devinfra
cp -r "$SRC" ~/.codex/skills/devinfra
cp -r "$SRC" ~/.config/opencode/skills/devinfra
chmod +x ~/.claude/skills/devinfra/scripts/devinfra \
         ~/.codex/skills/devinfra/scripts/devinfra \
         ~/.config/opencode/skills/devinfra/scripts/devinfra
```

Verify: each `SKILL.md` frontmatter has `name: devinfra` and the
`scripts/devinfra --help` runs with stdlib-only Python 3.8+.

## Invocation

- Claude / Codex: skill auto-triggers on docker-compose / dockerize /
  database dependency requests via its `description`; or invoke
  explicitly (`/devinfra` style or "use the devinfra skill").
- OpenCode: same — description-routed. Check `SKILL.md` is listed among
  skills.

Then follow `SKILL.md` → `references/*`, using `scripts/devinfra`:

```bash
scripts/devinfra services list
scripts/devinfra ensure postgres --version 17 --scope shared
scripts/devinfra database create postgres --name todo_db --project todo
scripts/devinfra connection postgres --project todo
scripts/devinfra compose generate --project todo --services postgres,redis
```

## Supported services / policies

Services: `postgres` (17), `redis` (7), `mongodb` (7), `rabbitmq` (3),
`localstack` (3), `elasticsearch` (8). Policies: `shared`,
`shared-if-compatible` (default where safe), `project-scoped`,
`ephemeral`, `dedicated`.

## Discovery

Read-only first: `services list` (registry reconciled with
`docker inspect`), `docker ps -a`, `docker images`, `docker network ls`.
Identity = container ID, never bare name. Unmanaged containers are
reported, never adopted without authorization.

## Compose

Shared mode omits reused deps and joins external `dev-services`;
standalone mode (`--standalone`) emits project-scoped containers.
See `references/compose-guide.md` + `examples/`.

## Tests

```bash
python3 -m unittest discover -s tests -v
```

Mocked-docker unit tests cover reuse, isolation, provisioning, cleanup,
security, concurrency. Docker integration is opt-in:
`DEVINFRA_LIVE=1 python3 -m unittest discover -s tests` (requires daemon).

## Limitations / next steps

- v1 covers postgres + redis deeply; mongo/rabbit/localstack/es have
  catalog entries + isolation rules but thinner probe automation.
- No automatic backups; advise `pg_dump` before destructive work.
- Host-port publishing is opt-in (`--publish`); default is network-only.
- Password rotation and multi-host support are out of scope for v1.
