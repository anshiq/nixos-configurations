# NixOS (WSL) Configuration

This is a flake-based NixOS + Home Manager configuration, migrated from an
Ubuntu setup (fish + zellij + yazi + helix + alacritty). It runs under
**NixOS-WSL**.

For the full story of what was migrated, what changed, and why, see
[`MIGRATION.md`](./MIGRATION.md). This file just covers structure and usage.

## Layout

```
nixos/
├── flake.nix              # flake inputs + nixosConfigurations.nixos
├── flake.lock             # pinned input versions (unchanged from before)
├── configuration.nix      # system-level config (WSL, users, system packages)
├── home.nix               # user-level config (fish, zellij, yazi, helix, dev tools)
├── helix/
│   ├── config.toml        # unchanged from your original setup
│   └── languages.toml     # unchanged from your original setup
└── yazi/
    ├── yazi.toml           # your original yazi.toml, imported via lib.importTOML
    ├── keymap.toml         # your original keymap.toml, imported via lib.importTOML
    └── theme.toml          # your original theme.toml, imported via lib.importTOML
```

Nothing under `helix/` or `yazi/` was rewritten — they're your original files,
loaded into the Nix config with `lib.importTOML` / `xdg.configFile.source` so
the TOML stays readable and diffable on its own, while Nix still owns where it
gets placed and what packages back it.

Zellij's config, and all of your fish functions/aliases, are **not** kept as
separate dotfiles — they're written directly as Nix strings inside `home.nix`.
That's a deliberate choice (see `MIGRATION.md` for why), not an oversight.

## Installing

1. Copy this whole `nixos/` folder to `/etc/nixos/` on your machine (or
   wherever you keep your flake — adjust paths if different).
2. From inside that directory:
   ```bash
   sudo nixos-rebuild switch --flake .#nixos
   ```
3. Log out and back in (or restart your WSL shell) so Home Manager's
   fish/zellij/yazi config takes effect for your user session.

## Everyday commands

```bash
sudo nixos-rebuild switch --flake .#nixos   # apply changes
nix flake update                            # update all pinned inputs
nix flake lock --update-input home-manager  # update just one input
```

## What you get out of the box

- **fish** as your shell, with `mkcd`, `gfile`, `y`, `dev` functions and your
  `glog`/`reload`/`zjl`/`zja` aliases, PATH entries, and `BUN_INSTALL`/`GOPATH`
  all wired up automatically.
- **zellij**, previously missing from your Nix config entirely, now installed
  and configured with your exact theme, keybindings, and `dev` layout.
- **yazi**, with your settings/keymap/theme preserved verbatim, plus the
  `git` and `jump-to-char` plugins from nixpkgs (replacing the manual
  rev-pinned fetches in your old `package.toml`).
- **helix**, carried over unchanged — this was already in Nix before.
- A full dev toolchain: C/C++, Java (jdk21), Node (22), Go, Rust, Python, and
  Bun, plus the LSPs/formatters your `languages.toml` expects.

## What's intentionally not here

- **zoxide** — dropped entirely, per your instruction. Not installed,
  not referenced.
- **alacritty.toml** — not migrated. Alacritty is normally a Windows-side GUI
  app when running WSL, not something the Linux guest manages, and you
  confirmed you don't need it configured here. The original `alacritty.toml`
  is not included in this archive; keep managing it on the Windows side if
  you still use it there.

See `MIGRATION.md` for the complete reasoning behind every decision above.
