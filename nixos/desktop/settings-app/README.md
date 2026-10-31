# Settings app

One window for the everyday settings: **Wi-Fi, Bluetooth, Sound, Display, Power,
Appearance, Lock screen**. A standalone Quickshell config (its own process and
window), not a panel in the bar's shell - a bug here cannot take down the bar or
the lock screen.

Open it with `SUPER+I`, from the launcher ("Settings"), or `settings-app [page]`
(`wifi | bluetooth | sound | display | power | appearance | lockscreen`).
A second launch focuses the open window instead of opening another.

## Where things live

| Piece | File |
|---|---|
| Launcher, desktop entry, live symlink `~/.config/settings-app` | `../settings-app.nix` (imported from `home.nix`) |
| bluez + power-profiles-daemon (system services the app needs) | `../../configuration.nix` |
| Float/center rule for the window | `../../hypr/hyprland.lua` (`float-settings-app`) |
| Lock-screen wallpaper hook | `../../quickshell/LockScreen.qml` (`customWallpaper`) |
| This app | `shell.qml` (window + sidebar), `pages/*.qml`, shared widgets in the top directory, `scripts/*.sh` |

Like `quickshell/`, the app is a live symlink into this checkout: QML edits apply
on the next launch, no rebuild. The Nix side (launcher, desktop entry, services,
Hyprland rule) needs `nixos-rebuild switch`.

## How each page gets its data

- **Wi-Fi** - `nmcli` (same approach as the bar's `NetworkPanel.qml`): it reports
  readable errors, and covers hidden SSIDs and forgetting profiles, which
  `Quickshell.Networking` does not expose. A failed *first* attempt on a network
  deletes the half-made profile so the next try asks for the password again.
- **Bluetooth** - `Quickshell.Bluetooth` (BlueZ over D-Bus, live). Pairing needs a
  BlueZ *agent* to answer passkey/PIN prompts and Quickshell 0.3.0 has none, so
  `BtAgent.qml` runs `bluetoothctl --agent KeyboardDisplay` **only while the page is
  open** and surfaces its prompts in the UI.
- **Sound** - `Quickshell.Services.Pipewire` (volume, mute, default device).
- **Display** - `brightnessctl`; night light shares state with the bar's blue-light
  widget (`~/.cache/waybar-bluelight-temp`, `bluelight-toggle.sh`); monitors are
  read-only (`hyprctl monitors -j`) because layout lives in `hyprland.lua`.
- **Power** - battery from sysfs (no daemon needed); profiles via
  `powerprofilesctl` (power-profiles-daemon). Both degrade to an explanatory
  "unavailable" state when the service is not running.
- **Appearance** - lists the deployed themes and calls `theme-switch.sh`. Themes
  are still defined in `themes/*.nix`; a manual pick lasts until the next scheduled
  switch.
- **Lock screen** - writes `~/.local/state/quickshell/lockscreen.json`
  (`{"wallpaper": "/abs/path"}`), which `LockScreen.qml` watches. Images come from
  `../wallpapers/` and `~/Pictures/Wallpapers`. PNG/JPG only: this Qt build has no
  WebP plugin. The lock screen falls back to the stock wallpaper if the chosen file
  is missing or fails to decode. The choice is also
  published for the boot login screen (`greeter-sync`, see `../greeter/README.md`).

## Working on it

```bash
quickshell -n -p /etc/nixos/desktop/settings-app          # run directly
SETTINGS_PAGE=power quickshell -n -p /etc/nixos/desktop/settings-app
```

Hyprland's config is Lua here: `hyprctl dispatch` takes Lua (`hl.dsp...`), and
`hyprctl eval 'hl.window_rule({...})'` adds a rule live (dropped by `hyprctl reload`),
handy for floating the window before the Nix-deployed rule exists.

To exercise the Bluetooth page without hardware, `python-dbusmock`'s `bluez5`
template can serve a fake `org.bluez` on a private bus; point the app at it with
`DBUS_SYSTEM_BUS_ADDRESS=...`. A stand-in `bluetoothctl` on `PATH` can feed the
agent prompts.

## Known limits

- Wi-Fi passwords are passed to `nmcli` on its command line (briefly visible to
  other local users via `ps`) - the same as the bar's network panel.
- The Bluetooth pairing/agent path and the power-profile picker have been
  exercised against mocks only; the first run against real bluez/PPD is the real test.
