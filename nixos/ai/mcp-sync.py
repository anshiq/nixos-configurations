"""Merge the Nix-declared MCP servers into Claude Code, Codex and opencode.

Usage: mcp-sync.py RENDERED.json

RENDERED.json is {"claude": {...}, "codex": {...}, "opencode": {...}}, each a
map of server name -> that tool's entry (built by ai/mcp.nix). Only servers
named there, or named on a previous run, are touched; everything else in the
config files is preserved. A file is rewritten only when something changed.
Problems are reported as warnings and never fail the activation.
"""

import json
import os
import sys
import tempfile
import tomllib
from pathlib import Path

import tomli_w

HOME = Path(os.environ["HOME"])
STATE = HOME / ".local/state/nix-mcp/managed.json"


def warn(msg):
    print(f"mcp-sync: warning: {msg}", file=sys.stderr)


def atomic_write(path: Path, text: str, default_mode: int = 0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else default_mode
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def merge(table: dict, wanted: dict, previously: list) -> list:
    """Apply `wanted` to `table`; return the list of changes made."""
    changes = []
    for name in sorted(set(previously) - set(wanted)):
        if name in table:
            del table[name]
            changes.append(f"-{name}")
    for name, entry in wanted.items():
        if table.get(name) != entry:
            changes.append(("~" if name in table else "+") + name)
            table[name] = entry
    return changes


def sync_json(path: Path, key: str, wanted, previously, seed: dict):
    data = json.loads(path.read_text()) if path.exists() else dict(seed)
    if not isinstance(data, dict):
        raise ValueError("top level is not an object")
    changes = merge(data.setdefault(key, {}), wanted, previously)
    if changes:
        atomic_write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    return changes


def sync_toml(path: Path, key: str, wanted, previously):
    data = tomllib.loads(path.read_text()) if path.exists() else {}
    changes = merge(data.setdefault(key, {}), wanted, previously)
    if changes:
        atomic_write(path, tomli_w.dumps(data))
    return changes


def opencode_path() -> Path:
    d = HOME / ".config/opencode"
    for name in ("opencode.jsonc", "opencode.json"):
        if (d / name).exists():
            return d / name
    return d / "opencode.json"


def main():
    rendered = json.loads(Path(sys.argv[1]).read_text())
    try:
        state = json.loads(STATE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        state = {}

    targets = {
        "claude": lambda w, p: sync_json(HOME / ".claude.json", "mcpServers", w, p, {}),
        "codex": lambda w, p: sync_toml(HOME / ".codex/config.toml", "mcp_servers", w, p),
        "opencode": lambda w, p: sync_json(
            opencode_path(), "mcp", w, p, {"$schema": "https://opencode.ai/config.json"}
        ),
    }

    for tool, sync in targets.items():
        wanted = rendered.get(tool, {})
        try:
            changes = sync(wanted, state.get(tool, []))
        except Exception as e:  # keep the previous state so removals retry next time
            warn(f"{tool}: not updated ({type(e).__name__}: {e})")
            continue
        state[tool] = sorted(wanted)
        if changes:
            print(f"mcp-sync: {tool}: {' '.join(changes)}")

    atomic_write(STATE, json.dumps(state, indent=2) + "\n", 0o644)


if __name__ == "__main__":
    main()
