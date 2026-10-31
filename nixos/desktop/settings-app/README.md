# Settings app

One window for the everyday settings: **Wi-Fi, Bluetooth, Sound, Display, Power,
Capture, Appearance, Lock screen, Services, Dev servers, Credentials**. A standalone Quickshell config (its own process and
window), not a panel in the bar's shell - a bug here cannot take down the bar or
the lock screen.

Open it with `SUPER+I`, from the launcher ("Settings"), or `settings-app [page]`
(`wifi | bluetooth | sound | display | power | capture | appearance | lockscreen |
services | devservers | credentials`). A second launch switches the open window to
that page (IPC target `settings`, function `open`) and focuses it instead of
opening another.

## Where things live

| Piece | File |
|---|---|
| Launcher, desktop entry, live symlink `~/.config/settings-app` | `../settings-app.nix` (imported from `home.nix`) |
| bluez + power-profiles-daemon (system services the app needs) | `../../configuration.nix` |
| Float/center rule for the window | `../../hypr/hyprland.lua` (`float-settings-app`) |
| Lock-screen wallpaper hook | `../../quickshell/LockScreen.qml` (`customWallpaper`) |
| This app | `shell.qml` (window + sidebar), `pages/*.qml`, shared widgets in the top directory, `scripts/*.sh` |

`shell.qml` loads only the current page, through a `Loader`; switching pages
destroys the old one with its timers and processes. A page file that is missing
(pages are added by different modules) shows a placeholder instead of an error.
A page that declares `property var hostWindow` gets the window (Capture uses it
to hide itself while a screenshot is taken).

Commands the pages call go through `Cmd.qml`; a missing command finishes with
code 127 and the page shows an "unavailable" state instead of hanging. The
desktop commands (`theme-switch`, `theme-status`, `bluelight`, `screenshot`,
`screen-record`, `idle-settings`) come from other modules on the session PATH.

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
- **Display** - `brightnessctl`; night light through `bluelight status --json |
  toggle | set <kelvin>` (shared with the bar). Brightness and night light are
  re-read every 4 s while the page is open, and at once when
  `~/.local/state/desktop/bluelight-temp` changes. Monitors are read-only
  (`hyprctl monitors -j`, on open) because layout lives in `hyprland.lua`.
- **Power** - battery from sysfs (`scripts/battery.sh`, on open and every 30 s
  while open); profiles via `powerprofilesctl` (power-profiles-daemon, on open and
  after a change). Idle timeouts (lock / screen off / suspend, minutes, 0 = never)
  via `idle-settings get --json` / `set`, re-read when
  `~/.local/state/desktop/idle.json` changes. Each part degrades to an explanatory
  "unavailable" state when its service or command is missing.
- **Capture** - `screenshot` and `hyprpicker -a` (the window hides while they
  run), `screen-record start [--region] | stop | status --json`, recordings in
  `~/Videos/Recordings`. Recording state follows
  `$XDG_RUNTIME_DIR/screen-record.pid` (inotify, no polling). Lists the
  PRINT / SUPER+PRINT / SUPER+SHIFT+PRINT keybinds.
- **Appearance** - themes from `~/.config/desktop/themes/*.json`, the active one
  from `theme-status --json` (re-read when `~/.local/state/desktop/theme`
  changes), the schedule from `~/.config/desktop/schedule.json` (read-only, with
  the slot in force marked). Applies with `theme-switch <name> | toggle | next`;
  "Follow schedule" runs `theme-switch` with no argument. Themes are defined in
  `themes/*.nix`; a manual pick lasts until the next scheduled switch.
- **Services / Dev servers / Credentials** - `pages/ServicesPage.qml`,
  `pages/DevServicesPage.qml`, `pages/CredentialsPage.qml` (separate module).
- **Lock screen** - writes `~/.local/state/desktop/lockscreen.json`
  (`{"wallpaper": "/abs/path"}`), which `LockScreen.qml` watches. Images come from
  `../wallpapers/` and `~/Pictures/Wallpapers`. PNG/JPG only: this Qt build has no
  WebP plugin. "Default" previews `~/.local/state/desktop/wallpaper.png`. The lock
  screen falls back to the stock wallpaper if the chosen file
  is missing or fails to decode. The choice is also
  published for the boot login screen (`greeter-sync`, see `../greeter/README.md`).

## Working on it

```bash
quickshell -n -p /etc/nixos/desktop/settings-app          # run directly
SETTINGS_PAGE=power quickshell -n -p /etc/nixos/desktop/settings-app
quickshell ipc -p ~/.config/settings-app call settings open capture
```

To render a page without a visible window (e.g. to screenshot it), run it with
`QT_QPA_PLATFORM=offscreen` and grab the root item with `grabToImage`.

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
