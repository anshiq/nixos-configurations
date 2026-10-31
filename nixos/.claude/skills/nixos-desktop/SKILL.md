---
name: nixos-desktop
description: >
  REQUIRED for end-user customization of this NixOS desktop: Hyprland, the
  Quickshell bar/launcher/lock-screen, themes, terminals, idle, screenshots
  and screen recording. Use when editing nixos/hypr/, nixos/quickshell/,
  nixos/themes/, nixos/desktop/ under this repo. Triggers: Hyprland, window
  rules, animations, keybindings, monitors, gaps, borders, blur, bar,
  terminal config, themes, background, quickshell widgets, idle, lock
  screen, screenshots, recording, blue light. Not for general NixOS system
  administration outside this desktop layer.
---

# NixOS Desktop Skill

This NixOS + Hyprland + Quickshell desktop is fully declarative: the checkout
at `/etc/nixos` (`nixos/` in the repo) is the source of truth and `~/.config/*`
is mostly build output.

**Given a customization request, first decide:** does it touch something
Nix-generated (theme colors, ghostty/kitty/helix/yazi/lazygit theme files,
hyprlock, systemd units, desktop commands) - edit the Nix source and rebuild -
or something deployed live and hot-reloading (`hypr/hyprland.lua`,
`quickshell/` QML) - edit the file in the checkout, no rebuild needed.
Editing a generated file under `~/.config/` by hand does nothing permanent.

## Topic Guides

- [`theming.md`](theming.md) - themes, the day/night schedule, adding a theme
- [`hyprland.md`](hyprland.md) - keybindings, monitors, window rules, animations
- [`plugins.md`](plugins.md) - the bar and its widgets

## Critical Safety Rules

**Never hand-edit anything under `~/.config/` that has a Nix source in this
repo** - it is overwritten on the next rebuild and not tracked anywhere.

**Never run `nixos-rebuild switch` without telling the user first.** Validate
with `nixos-rebuild build --flake /etc/nixos#nixos` (builds without
activating), then confirm. Changes to the login greeter need
`nixos-rebuild boot` + reboot, not `switch`.

## System Architecture

| Component | Purpose | Source |
|-----------|---------|--------|
| NixOS + home-manager | Base OS + user environment | `nixos/*.nix`, `nixos/desktop/*.nix` |
| Hyprland (UWSM session) | Compositor/WM | `nixos/hypr/hyprland.lua` |
| Quickshell | Bar, launcher, lock screen, notifications, clipboard picker, power menu | `nixos/quickshell/` (live symlink) |
| Settings app | Wi-Fi, Bluetooth, sound, display, power, ... | `nixos/desktop/settings-app/` |
| Desktop commands | theme-switch, bluelight, screen-record, ... | `nixos/desktop/scripts/` |
| greetd + Quickshell greeter | Login screen | `nixos/desktop/greeter.nix` |

Session services are systemd user units bound to `graphical-session.target`
(defined in `desktop/home.nix`): `quickshell`, `swaybg`, `hypridle`,
`hyprsunset` (blue-light filter, toggled on demand), `cliphist-text`,
`cliphist-image`, `hyprpolkitagent`, `nm-applet`, plus `theme-init` (applies
the scheduled theme at login). Timers: `battery-notify`, `theme-warmth-ramp`,
`theme-<name>`. Runtime state lives in `~/.local/state/desktop/`.

## Commands

```bash
theme-switch [<name>|toggle|next]     # no arg = scheduled theme
theme-status [--json]
bluelight status [--json] | toggle | on | off | set <kelvin> | adjust <+N|-N>
screenshot                            # flameshot gui
screen-record toggle [--region] | start [--region] | stop | status [--json]
idle-settings get [--json] | set <lock> <dpms> <suspend>   # minutes, 0 = never
settings-app [page]

quickshell ipc call launcher openDrun | lockscreen lock | powermenu toggle | clipboard toggle

systemctl --user status quickshell    # shell logs: journalctl --user -u quickshell
hyprctl reload && hyprctl configerrors
```

## Reset to Defaults

```bash
git -C /etc diff nixos/hypr/hyprland.lua
git -C /etc checkout -- nixos/hypr/hyprland.lua
```
Reverting a Nix-generated file's source also needs a rebuild.

## Decision Framework

1. **Theme/colors?** [`theming.md`](theming.md): edit or add a file under
   `themes/`, rebuild.
2. **Hyprland?** [`hyprland.md`](hyprland.md): edit `hypr/hyprland.lua`.
3. **Bar/widgets?** [`plugins.md`](plugins.md).
4. **Automation on an event or a schedule?** Add a `systemd.user` service
   (+ timer) in `desktop/home.nix`, like the theme schedule. Prefer events
   over polling; this is a laptop.
5. **New desktop command?** Add a script to `desktop/scripts/` and an entry
   in `desktop/scripts/default.nix` (writeShellApplication with explicit
   `runtimeInputs`), then list it in `home.packages`.
