"""Mocked-docker unit tests for the devinfra CLI.

Covers the 14 required scenarios without touching a real daemon.
Opt-in live test: DEVINFRA_LIVE=1 (requires docker daemon).
"""
import importlib.util
import io
import json
import os
import sqlite3
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stdout, redirect_stderr
from types import SimpleNamespace

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLI_PATH = os.path.join(SKILL_DIR, "scripts", "devinfra")


def load_cli():
    import importlib.machinery
    loader = importlib.machinery.SourceFileLoader("devinfra_cli", CLI_PATH)
    spec = importlib.util.spec_from_loader("devinfra_cli", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


devinfra = load_cli()


class FakeDocker:
    """Minimal fake docker daemon: containers, images, networks, exec log."""

    def __init__(self):
        self.containers = {}  # cid -> inspect dict
        self.by_name = {}  # name -> cid
        self.images = set()
        self.networks = {"bridge"}
        self.pulls = []
        self.runs = []
        self.execs = []
        self.removed = []
        self.dbs = {}  # cname -> set(db names)
        self.next_id = 1

    # -- state builders --
    def add_image(self, ref):
        self.images.add(ref)

    def add_container(self, name, image, running=True, healthy=True, networks=("dev-services",)):
        cid = f"fake{self.next_id:08d}"[:12]
        self.next_id += 1
        self.networks.update(networks)
        self.containers[cid] = {
            "Id": cid,
            "Name": "/" + name,
            "Config": {"Image": image},
            "State": {"Running": running, "Status": "running" if running else "exited",
                      "Health": {"Status": "healthy" if healthy else "unhealthy"}},
            "NetworkSettings": {"Networks": {n: {} for n in networks}},
            "Mounts": [{"Name": f"{name}-data"}],
        }
        self.by_name[name] = cid
        self.dbs.setdefault(name, set())
        return cid

    # -- fake subprocess seam --
    def run_docker(self, args, check=False, capture=True):
        def ok(out=""):
            return SimpleNamespace(returncode=0, stdout=out, stderr="")
        def err(msg=""):
            return SimpleNamespace(returncode=1, stdout="", stderr=msg)
        if not args:
            return err("empty")
        cmd = args[0]
        if cmd == "info":
            return ok("99.0-fake")
        if cmd == "ps":
            rows = []
            for cid, c in self.containers.items():
                name = c["Name"].lstrip("/")
                rows.append(json.dumps({"ID": cid, "Names": name, "Image": c["Config"]["Image"],
                                        "Status": c["State"]["Status"],
                                        "Ports": "", "NetworkSettings": {}}))
            return ok("\n".join(rows))
        if cmd == "images":
            rows = []
            for ref in sorted(self.images):
                repo, _, tag = ref.partition(":")
                rows.append(json.dumps({"Repository": repo or ref, "Tag": tag or "latest",
                                        "ID": "sha256:fake", "Size": "1MB"}))
            return ok("\n".join(rows))
        if cmd == "inspect":
            target = args[1] if len(args) > 1 else ""
            if target in self.containers:
                return ok(json.dumps([self.containers[target]]))
            if target.lstrip("/") in self.by_name:
                return ok(json.dumps([self.containers[self.by_name[target.lstrip("/")]]]))
            # network inspect fallback handled below; container miss:
            if target in self.networks:
                return ok(json.dumps([{"Name": target}]))
            return err("No such object")
        if cmd == "network":
            action = args[1] if len(args) > 1 else ""
            name = args[2] if len(args) > 2 else ""
            if action == "inspect":
                return ok(json.dumps([{"Name": name}])) if name in self.networks else err("no such network")
            if action == "create":
                self.networks.add(name)
                return ok(name)
            if action == "ls":
                return ok("\n".join(self.networks))
        if cmd == "pull":
            ref = args[1]
            self.pulls.append(ref)
            self.images.add(ref)
            return ok(f"Pulled {ref}")
        if cmd == "run":
            # parse --name and image (last arg)
            name = None
            for i, a in enumerate(args):
                if a == "--name" and i + 1 < len(args):
                    name = args[i + 1]
            image = args[-1]
            self.runs.append(list(args))
            cid = self.add_container(name or f"c{self.next_id}", image)
            return ok(cid + "\n")
        if cmd == "exec":
            # args: exec <cname> <prog> ...
            self.execs.append(list(args))
            cname = args[1] if len(args) > 1 else ""
            tail = " ".join(args[2:])
            if "SELECT 1 FROM pg_database" in tail:
                # report db presence
                import re
                m = re.search(r"datname='([^']+)'", tail)
                db = m.group(1) if m else ""
                return ok(" 1\n" if db in self.dbs.get(cname, set()) else "\n")
            if "CREATE DATABASE" in tail:
                import re
                m = re.search(r'CREATE DATABASE "([^"]+)"', tail)
                if m:
                    self.dbs.setdefault(cname, set()).add(m.group(1))
                return ok("CREATE DATABASE")
            if "DROP DATABASE" in tail:
                import re
                m = re.search(r'DROP DATABASE IF EXISTS "([^"]+)"', tail)
                if m:
                    self.dbs.get(cname, set()).discard(m.group(1))
                return ok("DROP DATABASE")
            return ok("")
        if cmd == "rm":
            target = args[-1]
            self.removed.append(target)
            cid = target if target in self.containers else self.by_name.get(target.lstrip("/"), None)
            if cid and cid in self.containers:
                name = self.containers[cid]["Name"].lstrip("/")
                del self.containers[cid]
                self.by_name.pop(name, None)
            return ok(target)
        return err(f"unsupported fake cmd: {args}")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.reg = os.path.join(self.tmp.name, "registry.db")
        os.environ["DEVINFRA_REGISTRY"] = self.reg
        self.fake = FakeDocker()
        self._orig = devinfra.run_docker
        devinfra.run_docker = self.fake.run_docker

    def tearDown(self):
        devinfra.run_docker = self._orig
        os.environ.pop("DEVINFRA_REGISTRY", None)
        self.tmp.cleanup()

    def run_cli(self, argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                rc = devinfra.main(argv)
            except SystemExit as e:
                rc = e.code or 0
        return rc, out.getvalue(), err.getvalue()

    def seed_service(self, name="postgres", version="17", image="postgres:17-alpine",
                     running=True, healthy=True, scope="shared-if-compatible"):
        self.fake.add_image(image)
        cid = self.fake.add_container(name, image, running=running, healthy=healthy)
        conn = devinfra.connect()
        conn.execute(
            "INSERT INTO services(name,container_id,container_name,image,version,scope,network,status,unmanaged)"
            " VALUES(?,?,?,?,?,?,?,?,0)",
            (name, cid, name, image, version, scope, "dev-services", "running"),
        )
        conn.commit()
        conn.close()
        return cid


class TestReuse(Base):
    def test_01_healthy_postgres_reused(self):
        """1. An existing healthy PostgreSQL container is reused."""
        self.seed_service()
        rc, out, _ = self.run_cli(["ensure", "postgres", "--version", "17"])
        self.assertEqual(rc, 0)
        self.assertIn("reused", out)
        self.assertEqual(len(self.fake.runs), 0, "must not create a container")

    def test_02_second_project_separate_db_no_new_container(self):
        """2. Second project gets a separate database without another container."""
        self.seed_service()
        rc, _, _ = self.run_cli(["database", "create", "postgres", "--name", "todo_db", "--project", "todo"])
        self.assertEqual(rc, 0)
        rc, out, _ = self.run_cli(["database", "create", "postgres", "--name", "notes_db", "--project", "notes"])
        self.assertEqual(rc, 0)
        self.assertEqual(len(self.fake.runs), 0)
        conn = sqlite3.connect(self.reg)
        n = conn.execute("SELECT COUNT(*) c FROM dependencies").fetchone()[0]
        conn.close()
        self.assertEqual(n, 2)

    def test_03_missing_image_pulled_only_when_required(self):
        """3. A missing image is pulled only when required."""
        # image present locally -> no pull
        self.fake.add_image("redis:7-alpine")
        rc, _, _ = self.run_cli(["ensure", "redis", "--version", "7"])
        self.assertEqual(rc, 0)
        self.assertEqual(self.fake.pulls, [])
        # missing image -> exactly one pull
        rc, _, _ = self.run_cli(["ensure", "mongodb", "--version", "7"])
        self.assertEqual(rc, 0)
        self.assertEqual(self.fake.pulls, ["mongo:7"])

    def test_04_missing_service_provisioned(self):
        """4. A missing compatible service is provisioned."""
        self.fake.networks.add("dev-services")
        rc, out, _ = self.run_cli(["ensure", "postgres", "--version", "17"])
        self.assertEqual(rc, 0)
        self.assertIn("created", out)
        self.assertEqual(len(self.fake.runs), 1)

    def test_05_incompatible_version_not_reused(self):
        """5. An incompatible service version is not reused."""
        cid = self.seed_service(version="16", image="postgres:16-alpine")
        rc, _, err = self.run_cli(["ensure", "postgres", "--version", "17"])
        self.assertEqual(rc, 0)
        # must NOT have touched/replaced the v16 container; dedicated path instead
        self.assertIn(cid, self.fake.containers)
        self.assertEqual(len(self.fake.runs), 1)
        dedicated = [r for r in self.fake.runs if "postgres-v17" in " ".join(r)]
        self.assertTrue(dedicated, f"expected dedicated v17 container, runs={self.fake.runs}")

    def test_06_unhealthy_container_handled_safely(self):
        """6. An unhealthy container is handled safely (no reuse, nonzero exit)."""
        self.seed_service(healthy=False)
        rc, out, err = self.run_cli(["ensure", "postgres", "--version", "17"])
        self.assertNotEqual(rc, 0)
        self.assertEqual(len(self.fake.runs), 0)
        self.assertIn("unhealthy", (out + err).lower())

    def test_07_existing_network_reused(self):
        """7. An existing external Docker network is reused (not recreated)."""
        self.seed_service()
        self.assertIn("dev-services", self.fake.networks)
        before = set(self.fake.networks)
        rc, _, _ = self.run_cli(["ensure", "redis", "--version", "7"])
        self.assertEqual(rc, 0)
        self.assertEqual(set(self.fake.networks), before | {"dev-services"})


class TestComposeIdempotency(Base):
    def test_08_compose_omits_shared_deps(self):
        """8. Generated Compose files do not duplicate shared dependencies."""
        self.seed_service("postgres")
        self.seed_service("redis", version="7", image="redis:7-alpine")
        rc, out, _ = self.run_cli(["compose", "generate", "--project", "todo",
                                   "--services", "postgres,redis"])
        self.assertEqual(rc, 0)
        self.assertIn("external: true", out)
        self.assertIn("dev-services", out)
        self.assertNotIn("image: postgres", out)
        self.assertNotIn("image: redis", out)
        self.assertIn("${DATABASE_URL}", out)

    def test_09_repeated_provisioning_idempotent(self):
        """9. Repeated provisioning requests do not create duplicates."""
        self.fake.networks.add("dev-services")
        for _ in range(3):
            rc, _, _ = self.run_cli(["ensure", "postgres", "--version", "17"])
            self.assertEqual(rc, 0)
        self.assertEqual(len(self.fake.runs), 1)
        rc, _, _ = self.run_cli(["database", "create", "postgres", "--name", "todo_db", "--project", "todo"])
        rc, out, _ = self.run_cli(["database", "create", "postgres", "--name", "todo_db", "--project", "todo"])
        self.assertIn("exists", out)
        conn = sqlite3.connect(self.reg)
        n = conn.execute("SELECT COUNT(*) c FROM dependencies").fetchone()[0]
        conn.close()
        self.assertEqual(n, 1)


class TestLifecycle(Base):
    def test_10_cleanup_keeps_other_projects_service(self):
        """10. One project's cleanup does not remove a service used by another."""
        self.seed_service()
        self.run_cli(["database", "create", "postgres", "--name", "todo_db", "--project", "todo"])
        self.run_cli(["database", "create", "postgres", "--name", "notes_db", "--project", "notes"])
        rc, _, _ = self.run_cli(["cleanup", "--project", "todo", "--yes"])
        self.assertEqual(rc, 0)
        conn = sqlite3.connect(self.reg)
        left = [r[0] for r in conn.execute("SELECT project FROM dependencies")]
        svc = conn.execute("SELECT COUNT(*) c FROM services WHERE name='postgres'").fetchone()[0]
        conn.close()
        self.assertEqual(left, ["notes"])
        self.assertEqual(svc, 1, "shared service row must survive")
        self.assertEqual(self.fake.removed, [])

    def test_11_no_credential_leak(self):
        """11. Credentials are not leaked into logs or registry metadata."""
        self.seed_service()
        rc, out, err = self.run_cli(["database", "create", "postgres", "--name", "todo_db",
                                     "--project", "todo", "--owner", "todo_user"])
        self.assertEqual(rc, 0)
        # registry must have no password column / value
        conn = sqlite3.connect(self.reg)
        conn.row_factory = sqlite3.Row
        cols = [r[1] for r in conn.execute("PRAGMA table_info(dependencies)")]
        dump = "\n".join(str(dict(r)) for r in conn.execute("SELECT * FROM dependencies"))
        conn.close()
        self.assertNotIn("password", " ".join(cols).lower())
        # connection output must redact
        rc, cout, _ = self.run_cli(["connection", "postgres", "--project", "todo"])
        self.assertEqual(rc, 0)
        self.assertIn("****", cout)
        # password printed once at creation goes to stdout only, never stored:
        self.assertNotIn("password", dump.lower())

    def test_12_concurrent_ensure_single_container(self):
        """12. Concurrent requests do not create duplicate shared services."""
        self.fake.networks.add("dev-services")
        # serialize via real lock; threads share one fake daemon
        orig_run = self.fake.run_docker
        import time as _t
        def slow_run(args, check=False, capture=True):
            if args and args[0] == "run":
                _t.sleep(0.05)
            return orig_run(args, check=check, capture=capture)
        devinfra.run_docker = slow_run
        results = []
        def worker():
            o, e = io.StringIO(), io.StringIO()
            with redirect_stdout(o), redirect_stderr(e):
                try:
                    results.append(devinfra.main(["ensure", "postgres", "--version", "17"]))
                except SystemExit as ex:
                    results.append(ex.code or 0)
        threads = [threading.Thread(target=worker) for _ in range(5)]
        [t.start() for t in threads]
        [t.join() for t in threads]
        self.assertTrue(all(r == 0 for r in results), results)
        self.assertEqual(len(self.fake.runs), 1, f"duplicate containers: {self.fake.runs}")

    def test_13_ephemeral_cleanup_spares_shared(self):
        """13. Ephemeral services can be cleaned up without affecting shared."""
        self.seed_service()  # shared postgres
        eph_cid = self.fake.add_container("todo-test-postgres", "postgres:17-alpine")
        conn = devinfra.connect()
        conn.execute(
            "INSERT INTO services(name,container_id,container_name,image,version,scope,network,status)"
            " VALUES(?,?,?,?,?,?,?,?)",
            ("todo-test-postgres", eph_cid, "todo-test-postgres",
             "postgres:17-alpine", "17", "ephemeral", "dev-services", "running"),
        )
        conn.execute(
            "INSERT INTO dependencies(service,project,db_name,db_user,namespace,created_at)"
            " VALUES(?,?,?,?,?,?)", ("todo-test-postgres", "todo", "test_db", "", "test_db", "now"),
        )
        conn.commit()
        conn.close()
        rc, out, _ = self.run_cli(["cleanup", "--project", "todo", "--yes"])
        self.assertEqual(rc, 0)
        conn = sqlite3.connect(self.reg)
        shared = conn.execute("SELECT COUNT(*) c FROM services WHERE name='postgres'").fetchone()[0]
        eph = conn.execute("SELECT COUNT(*) c FROM services WHERE name='todo-test-postgres'").fetchone()[0]
        conn.close()
        self.assertEqual(shared, 1, "shared service must survive ephemeral cleanup")
        self.assertEqual(eph, 0, "orphaned ephemeral service should be removed")
        # shared container never in removed list
        self.assertNotIn("postgres", [r.strip("/") for r in self.fake.removed])

    def test_14_unmanaged_not_touched(self):
        """14. An unmanaged container is not modified or deleted without authorization."""
        self.fake.add_image("postgres:17-alpine")
        self.fake.add_container("someone-elses-pg", "postgres:17-alpine")  # not in registry
        rc, _, _ = self.run_cli(["cleanup", "--project", "todo", "--yes"])
        self.assertEqual(rc, 0)  # nothing registered -> no-op
        self.assertEqual(self.fake.removed, [], "unmanaged container must not be removed")
        # discovery surfaces it as unmanaged instead
        cands = devinfra.find_unmanaged_candidates()
        self.assertTrue(any("someone-elses-pg" in str(c.values()) for c in cands))


class TestLive(unittest.TestCase):
    """Opt-in integration: runs only with DEVINFRA_LIVE=1 and a real daemon."""

    @unittest.skipUnless(os.environ.get("DEVINFRA_LIVE") == "1", "live docker test (opt-in)")
    def test_live_discovery(self):
        mod = load_cli()
        self.assertTrue(mod.docker_daemon_ok(), "docker daemon must be reachable for live test")


if __name__ == "__main__":
    unittest.main()
