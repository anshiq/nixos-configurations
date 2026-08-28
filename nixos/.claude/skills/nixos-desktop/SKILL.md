---
name: nixos-desktop
description: >
  REQUIRED for end-user customization of this NixOS desktop: Hyprland, the
  Quickshell bar/launcher/lock-screen, themes, terminals, or plugins.
  Use when editing nixos/hypr/, nixos/quickshell/, nixos/themes/,
  nixos/plugins/, nixos/ghostty/, or nixos/kitty/ under this repo.
  Triggers: Hyprland, window rules, animations, keybindings, monitors, gaps,
  borders, blur, bar, terminal config, themes, background, quickshell
  plugins, idle, lock screen, screenshots. Ported from Omarchy's own
  end-user skill (adapted for a Nix-declarative system - see "How this
  differs from Omarchy" below), not for general NixOS system administration
  outside this desktop layer.
---

# NixOS Desktop Skill

Manage this NixOS + Hyprland + Quickshell desktop, adapted from
[Omarchy](https://omarchy.org/)'s own end-user customization skill. Omarchy
runs on Arch with a runtime-mutable `~/.config/`; this system is
Nix-declarative - the working tree at `nixos-configurations/nixos/` **is**
the source of truth, `~/.config/*` is a build artifact.

## How this differs from Omarchy (read this first)

| | Omarchy | This system |
|---|---|---|
| Where you edit | `~/.config/` directly, live | `nixos-configurations/nixos/` (the git checkout), then rebuild |
| Applying a change | Most things hot-reload on save | Hyprland/Quickshell config hot-reload once already deployed; **theme, ghostty, kitty, and hyprlock files are Nix-generated** and need `nixos-rebuild switch` to regenerate |
| Reset to defaults | `omarchy refresh <app>` | `git checkout -- <file>` (it's just a git-tracked file) or `git diff` to see what changed |
| Plugin install | `omarchy plugin clone`/`omarchy plugin add <url>` | `quickshell/scripts/plugin.sh add <url> [--enable]` (non-declarative) or add an entry to `nixos/plugins/default.nix` (declarative, Nix-fetched, reproducible) |
| CLI surface | One `omarchy` dispatcher for everything | No unified CLI - `nixos-rebuild`, `plugin.sh`, `theme-switch.sh` are separate tools (see the gap list at the end) |
| Config source of truth | `~/.config/omarchy/shell.json` (bar+idle+plugins, one file) | Three files: `plugin-layout.json` (placement), `plugin-registry.json` (Nix-generated, what exists), plus Nix-declared theme/schedule data |

**Given a customization request, first decide:** does it touch something
Nix-generated (theme colors, ghostty/kitty/hyprlock config, systemd
timers) - edit the Nix source and rebuild - or something deployed verbatim
and hot-reloading (hyprland.lua, quickshell QML, plugin-layout.json) - edit
the file directly in the checkout, no rebuild needed. Getting this wrong is
the single most common mistake: editing `~/.config/quickshell/theme-*.json`
by hand does nothing permanent, it's overwritten by the next
`nixos-rebuild switch`.

## Topic Guides

- [`theming.md`](theming.md) - themes, the day/night/custom schedule, adding a new theme
- [`hyprland.md`](hyprland.md) - keybindings, monitors, window rules, animations
- [`plugins.md`](plugins.md) - the bar: layout, widgets, installing third-party plugins

No hooks/capture guides exist yet - see "Features Omarchy has that this
system doesn't" below; both are real gaps, not oversights.

## Critical Safety Rules

**Never hand-edit anything under `~/.config/` that has a Nix source in this
repo** - it will be silently overwritten on the next `nixos-rebuild
switch`, and the edit is not tracked anywhere. Always edit the source in
`nixos-configurations/nixos/` instead. The one exception: `plugin-layout.json`
and manually-`plugin.sh add`-ed plugin files are never Nix-managed, so
hand-editing/using the CLI on those is correct and permanent.

**Never run `nixos-rebuild switch` without telling the user first** - it
mutates the running system (boot entries, services, user environment) and
is not easily reversible from inside a broken session. Prefer
`sudo nixos-rebuild build --flake nixos-configurations/nixos#nixos` (builds
without activating) to validate a change, then confirm before `switch`.

## System Architecture

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **NixOS + home-manager** | Base OS + user environment, declarative | `nixos-configurations/nixos/*.nix` |
| **Hyprland** | Wayland compositor/WM | `nixos/hypr/hyprland.lua` |
| **Quickshell** | Bar, launcher, lock screen, notifications (one process) | `nixos/quickshell/` |
| **Ghostty/kitty** | Terminals | `nixos/ghostty/`, `nixos/kitty/` - generated, see `theming.md` |
| **hyprlock** | Lock screen (manual fallback; Quickshell's own lock screen is primary) | generated, see `theming.md` |

## Command Discovery

There is no unified CLI (see the gap list). The tools that exist:

```bash
# Rebuild/apply Nix-side changes (themes, plugins declared in plugins/default.nix)
sudo nixos-rebuild build --flake nixos-configurations/nixos#nixos   # validate only
sudo nixos-rebuild switch --flake nixos-configurations/nixos#nixos  # apply - confirm with user first

# Quickshell bar plugins (see plugins.md)
~/.config/quickshell/scripts/plugin.sh list
~/.config/quickshell/scripts/plugin.sh add <git-url> [--enable]
~/.config/quickshell/scripts/plugin.sh enable <id> [left|center|right]
~/.config/quickshell/scripts/plugin.sh disable <id>
~/.config/quickshell/scripts/plugin.sh remove <id>

# Theme switching (see theming.md)
~/.config/waybar/scripts/theme-switch.sh <name>|toggle|next
~/.config/waybar/scripts/theme-status.sh

# Hyprland validation
hyprctl reload && hyprctl configerrors

# Quickshell diagnostics
quickshell log            # live logs from the running shell
quickshell kill; quickshell   # restart in foreground to see QML errors live
```

## Safe Customization Patterns

### Edit Source, Then Apply

```bash
# 1. Read current config
cat nixos-configurations/nixos/hypr/hyprland.lua

# 2. Nothing to back up separately - it's a git-tracked file. Check `git diff`
#    after editing, and `git checkout -- <file>` to revert.

# 3. Make changes with Edit tool, in the CHECKOUT, never in ~/.config/ for
#    anything Nix-generated.

# 4. Apply:
# - hyprland.lua / quickshell/*.qml / plugin-layout.json: hot-reload once
#   home-manager has linked them at least once (no rebuild needed for
#   subsequent edits) - see AGENTS.md's "Verifying changes" section
# - themes/*.nix, plugins/default.nix, anything under desktop/home.nix:
#   needs `nixos-rebuild switch` to regenerate the deployed files
```

### Reset to Defaults

```bash
cd nixos-configurations
git diff nixos/hypr/hyprland.lua          # see what changed
git checkout -- nixos/hypr/hyprland.lua   # revert to last commit
```
Note this only reverts the *source*; if the reverted file is
Nix-generated, also `nixos-rebuild switch` to re-deploy it.

## Decision Framework

1. **Is it a theme customization?** Follow [`theming.md`](theming.md); add a
   new theme file under `themes/`, don't hand-edit generated ghostty/kitty
   configs.
2. **Is it Hyprland config?** Follow [`hyprland.md`](hyprland.md); edit
   `hypr/hyprland.lua` directly (see the gap about it being monolithic).
3. **Is it the bar/a plugin?** Follow [`plugins.md`](plugins.md); use
   `plugin.sh`, or add a Nix-declared entry for reproducibility.
4. **Is it automation on an event (theme change, boot, low battery)?**
   No hooks system exists - the closest primitive is a
   `systemd.user.service`/`.timer` pair in `desktop/home.nix` (see how
   the theme schedule itself is built) - or ask the user if this is worth
   building as a real feature first.
5. **Is it a screenshot/recording?** Only `waybar/scripts/screenshot.sh`
   (flameshot) exists - screen recording, OCR, and file sharing are gaps.

## Example Requests

- "Change my theme to ocean-blue" -> `theme-switch.sh ocean-blue`
- "Add a new theme called sunset" -> copy `themes/tokyo-night.nix`, edit
  colors, add to `themes/default.nix`, `nixos-rebuild switch`
- "Add a keybinding for Super+E to open the file manager" -> check existing
  bindings in `hypr/hyprland.lua` first, then `hl.bind(...)`
- "Configure my external monitor" -> `hl.monitor({...})` in
  `hypr/hyprland.lua` (no separate `monitors.lua` here - see `hyprland.md`)
- "Install this Omarchy plugin" -> `plugin.sh add <url> --enable`, then
  check `quickshell log` for QML errors (multi-file plugins may need a
  generated `qmldir` - `plugin.sh` does this automatically)
- "Make this plugin permanent/reproducible" -> move it into
  `plugins/default.nix` as a `pkgs.fetchFromGitHub`, `nixos-rebuild switch`
- "Reset the bar to defaults" -> `git checkout -- nixos/quickshell/plugin-layout.json`

## Features Omarchy Has That This System Doesn't

Ported this skill from Omarchy's own; while reading it, these are real
gaps worth knowing about rather than assuming exist here:

1. **No unified CLI dispatcher.** Omarchy has one `omarchy <group> <action>`
   entry point with self-documenting `--help` at every level
   (`omarchy commands`, `omarchy commands --json`). We have three unrelated
   tools (`nixos-rebuild`, `plugin.sh`, `theme-switch.sh`) with no shared
   discovery mechanism.
2. **No automation hooks system.** Omarchy runs user scripts on events
   (`theme-set.d/`, `post-boot.d/`, `battery-low.d/`, `post-update.d/`) via
   `omarchy hook install <event> <script>`. We have no generic
   event-to-script mechanism at all - only the specific
   `systemd.user.timers` we hand-built for the theme schedule.
3. **No screen recording.** Omarchy: `omarchy screenrecord --fullscreen`
   with desktop/mic/webcam audio options. We only have flameshot for still
   screenshots.
4. **No OCR text capture.** Omarchy: `omarchy capture text` selects a
   region and extracts text to the clipboard. Nothing equivalent here.
5. **No file-sharing integration.** Omarchy ships LocalSend
   (`omarchy share file/folder/clipboard`) and Tailscale Taildrop
   (`omarchy tailscale send/receive`) as first-class commands. Neither is
   wired up here.
6. **No font management command.** Omarchy: `omarchy font list/current/set`
   switches the system font live via a fontconfig alias every app already
   points at. Our font is a hardcoded string
   (`"JetBrainsMono Nerd Font"`) in multiple Nix files - changing it means
   editing several places, not one command. Worth centralizing.
7. **No "clone before edit" workflow for built-in widgets.** Omarchy's
   `omarchy plugin clone omarchy.workspaces` copies a first-party widget to
   a user-owned name and switches the bar to it, so the original is never
   touched and updates don't clobber the customization. Our `user.*`
   widgets are just edited in place in the git-tracked checkout - fine for
   a single-user Nix repo, but there's no equivalent for "try a variant
   without losing the original" in one command.
8. **No per-widget settings persistence.** Omarchy's `shell.json` layout
   entries carry inline settings (`{id, refreshIntervalSec, ...}`) that
   `BarWidget.setting()` reads and `updateEntryInline()` writes back. Our
   `plugin-layout.json` is bare id strings only - every widget's
   `setting(key, fallback)` call always returns `fallback`, so no plugin
   can remember a user preference across restarts (confirmed: a real
   plugin's right-click "cycle display mode" feature silently can't
   persist here).
9. **No reminder/notification-scheduling command.** Omarchy:
   `omarchy reminder <minutes> [message]`, backed by systemd timers +
   notifications, with `show`/`clear`. Nothing equivalent here (though the
   theme-schedule timer machinery in `desktop/home.nix` is the right
   building block if this gets built).
10. **No interactive setup wizards or package-management command.**
    Omarchy: `omarchy setup <thing>`, `omarchy pkg add/drop <pkgs>` (handles
    pacman+AUR uniformly). Here that's just editing
    `environment.systemPackages`/`home.packages` in Nix directly - which is
    more correct for reproducibility, but has no guided/interactive path
    for someone unfamiliar with Nix.
11. **No system debug-bundle command.** Omarchy: `omarchy debug --no-sudo
    --print` produces one diagnostic log (versions, hardware, config state)
    and can upload it for sharing. No equivalent single command exists
    here.
12. **No crash-diagnosis/mute workflow.** Omarchy ships a
    `diagnose-crash` skill (coredumpctl-based triage) plus
    `omarchy-crash-mute` to silence a repeat-crashing program's
    notifications. `systemd-coredump`/`coredumpctl` work identically on
    NixOS, so the diagnosis procedure itself would port near-verbatim if
    wanted - it just hasn't been.
