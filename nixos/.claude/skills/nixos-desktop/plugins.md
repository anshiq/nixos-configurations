# The Bar and Its Widgets

Read this before changing the bar or its widgets.

The bar, launcher, lock screen, notifications, clipboard picker and power
menu all run in one Quickshell process (the `quickshell` systemd user
service). Its QML lives in `nixos/quickshell/`, deployed to
`~/.config/quickshell` as a live symlink into the checkout, so edits apply on
save without a rebuild.

Read `nixos/quickshell/` itself (its `shell.qml` and any README) for the
current widget layout and how widgets are registered before changing them.

Widgets call the desktop commands by bare name (`theme-switch`, `bluelight`,
`screen-record`, `idle-settings`, ...; see `SKILL.md`) and watch state files
under `~/.local/state/desktop/` rather than polling.

## Debugging

```bash
journalctl --user -u quickshell -f     # logs
systemctl --user restart quickshell
```

## Idle and Lock

Idle timeouts are edited from the shell's power settings (or
`idle-settings set <lock> <dpms> <suspend>`), stored in
`~/.local/state/desktop/idle.json`, and `idle-settings` regenerates
`~/.config/hypr/hypridle.conf` from them. Screen-off and suspend only fire on
battery.
