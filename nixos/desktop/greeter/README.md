# Login screen (greetd + Quickshell greeter)

The first screen after boot - where you type your password - is a greetd
greeter written in Quickshell that looks like the lock screen
(`quickshell/LockScreen.qml`): blurred wallpaper, clock, pill password field.
It replaced SDDM.

## How it fits together

| Piece | File |
|---|---|
| greetd, `cage`, session command, shared directory | `../greeter.nix` (NixOS module) |
| The greeter UI (this directory is copied into the Nix store) | `shell.qml` |
| Publishes palette + wallpaper for the greeter | `../greeter-sync.nix` (`greeter-sync` command) |

Boot: greetd -> `cage` (kiosk compositor, one fullscreen window) -> Quickshell
greeter, as the unprivileged `greeter` user. On a good password the greeter
tells greetd to start the session (`uwsm start -e -D Hyprland hyprland.desktop`,
the same thing the "Hyprland (uwsm-managed)" session entry ran under SDDM) and
exits. Authentication goes through greetd's PAM service, which includes the
`login` stack - so `pam_gnome_keyring` still unlocks the keyring with your
password.

## Following your theme and wallpaper

The greeter runs before anyone is logged in and cannot read `~/.local/state`.
`greeter-sync` copies what it needs into `/var/lib/quickshell-greeter/`
(created by `greeter.nix`, writable by you, readable by everyone):

- `theme.json` - the palette the bar and lock screen use (watched live by the greeter)
- `wallpaper` - the image chosen on Settings -> Lock screen, else the stock one

It runs at the end of `theme-switch.sh` (so also at every login and scheduled
theme change), from the Settings app when you pick a lock wallpaper, and on
every home-manager activation. Until the first sync the greeter shows the
wallpaper baked in at build time. Pictures you pick are copied world-readable.

## Applying changes - IMPORTANT

Do **not** `nixos-rebuild switch` while logged in when the display manager
changes: it stops the old one (ending your session) and starts greetd on the
same VT. Use

```bash
sudo nixos-rebuild boot --flake /etc/nixos#nixos   # then reboot
```

Later edits to `shell.qml` are ordinary changes: `switch` is fine (greetd does
not restart on switch; the new greeter appears at the next login screen).

## If the login screen is broken

- At the boot menu pick the previous generation (the old SDDM setup).
- Or switch to a text console with `Ctrl+Alt+F2`, log in, and fix/roll back
  (`sudo nixos-rebuild switch --rollback`).

## Previewing the look

```bash
quickshell -p /etc/nixos/desktop/greeter        # windowed preview, not connected to greetd
```

It shows "preview - not connected to greetd" and cannot log in. Float the window
first (it is a normal window in a running session) - and close it afterwards.
