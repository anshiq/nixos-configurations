# The Bar: Layout, Widgets, and Plugins

Read this before changing the bar, widgets, or installing a third-party
plugin.

Ported from Omarchy's `plugins.md`. The bar/launcher/lock-screen/
notifications all run inside one long-running Quickshell process here too
(`quickshell`, launched by `hyprland.lua`'s autostart) - that part matches
Omarchy exactly. Everything about *how plugins are declared and installed*
is different.

```
nixos/quickshell/plugin-layout.json     # placement: which ids, which section
nixos/quickshell/plugin-registry.json   # Nix-generated - every known plugin, don't hand-edit
nixos/quickshell/plugins/<id>/           # plugin files, builtin or fetched
nixos/plugins/default.nix                # Nix-declared third-party sources (reproducible)
nixos/quickshell/scripts/plugin.sh       # the CLI for all of the above
```

There is no single `shell.json` - Omarchy's one file (layout + widget
settings + idle config in one place) is split here into `plugin-layout.json`
(placement only) and `plugin-registry.json` (existence, Nix-owned). Neither
carries per-widget settings - see the gap list in `SKILL.md`.

## Bar Layout

```bash
~/.config/quickshell/scripts/plugin.sh list                       # what's installed, where
~/.config/quickshell/scripts/plugin.sh enable <id> [left|center|right]
~/.config/quickshell/scripts/plugin.sh disable <id>
```

No `omarchy bar move` - `enable` with a different section moves it (it
drops the id from every section first, so re-enabling elsewhere is a move,
not a duplicate).

## Installing a Third-Party Plugin

**Two ways - pick based on whether you want it reproducible:**

```bash
# Non-declarative - like Omarchy's `omarchy plugin add <url> --enable`.
# Real git clone, permanent (survives rebuilds), but NOT reproducible from
# this repo alone - another machine building this flake won't have it.
~/.config/quickshell/scripts/plugin.sh add <git-url> [--enable]

# Declarative - the Nix-native equivalent, no Omarchy analog. Add an entry
# to nixos/plugins/default.nix (pkgs.fetchFromGitHub, pinned rev+hash),
# then `nixos-rebuild switch`. Reproducible on any machine building this
# flake; `nixos-rebuild switch` IS the install step.
```

Either way, if the plugin ships multiple `.qml` files expecting to
reference each other as bare types (e.g. a widget that instantiates a
sibling `Model.qml`), `plugin.sh add` auto-generates a `qmldir` for it -
Quickshell's implicit same-directory type synthesis doesn't reliably work
under its own `qs:` URL scheme for plugin folders, and a missing qmldir
shows up as `"X is not a type"` in `quickshell log` with the widget simply
never rendering. Check `quickshell log` after installing anything.

## Customizing a Built-In Widget

No `omarchy plugin clone` equivalent - built-in widgets under
`quickshell/plugins/user.*/` are just edited directly in the git checkout.
There's no "clone before edit" step because this is already your own
tracked copy, not a packaged file that updates would overwrite.

## Uninstalling

```bash
~/.config/quickshell/scripts/plugin.sh remove <id>   # manual/non-declarative plugins
```
For a declaratively-added plugin, delete its entry from
`nixos/plugins/default.nix` and `nixos-rebuild switch` - the activation
script's stale-cleanup removes the now-undeclared plugin directory
automatically (it only ever touches directories it marked itself, never a
hand-written `user.*` widget or a `plugin.sh add`-ed one).

## Idle and Lock

No `shell.json` idle config - idle/lock timeouts are set from the running
shell's own power-menu settings panel (see `quickshell/PowerMenu.qml`),
persisted to `~/.local/state/quickshell/idle-settings.json` by
`quickshell/scripts/idle-settings.sh`, not edited as a config file.
