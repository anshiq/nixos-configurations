# Themes

Read this before changing themes, colors, or the day/night schedule.

Themes are Nix attrsets that generate every app's theme files at build time.

```
themes/
├── default.nix      # every theme, keyed by name
├── schedule.nix     # time -> theme, for the auto-switch timers
├── generators.nix   # one theme -> ghostty/kitty/helix/yazi/lazygit/zellij
│                    # text, Quickshell JSON, Hyprland border Lua
└── <name>.nix       # the theme definitions
```

Each theme file defines every field (no defaults): `kind` (`day`/`night`),
`background`, `foreground`, `brightForeground`, `muted`, `selection`, the
base and `bright*` colors, `accent`, `cursor`, and
`borderActive1`/`borderActive2`/`borderInactive`. `desktop/home.nix` renders
a full file set per theme, including `~/.config/desktop/themes/<name>.json`
(the Quickshell palette); the schedule goes to
`~/.config/desktop/schedule.json`.

## Switching

```bash
theme-switch <name>    # apply one theme
theme-switch toggle    # flip day/night kind
theme-switch next      # cycle
theme-switch           # whatever the schedule says for now
theme-status --json    # {"theme": ..., "kind": ...}
```

`theme-switch` repoints the active config symlinks, copies the palette to
`~/.local/state/desktop/theme.json` (Quickshell watches it), updates Hyprland
borders live, re-renders the wallpaper and restarts `swaybg`, and starts the
blue-light filter for night themes (stops it for day themes).

## Making a New Theme

1. Copy an existing theme file, e.g. `cp themes/mono.nix themes/mytheme.nix`.
2. Edit every field.
3. Add `mytheme = import ./mytheme.nix;` to `themes/default.nix`.
4. Optionally add it to `themes/schedule.nix` (keep ascending time order).
5. Rebuild, then `theme-switch mytheme`.

## Fonts

The terminals and hyprlock use the generic `monospace` family, resolved by
`fonts.fontconfig.defaultFonts` in `desktop/system.nix` (JetBrainsMono Nerd
Font). Quickshell QML names its font directly.

## Backgrounds

The desktop background is rendered per theme from the SVG template
`desktop/wallpapers/shortcuts-latest.svg` (`__TOKEN__` placeholders) into
`~/.local/state/desktop/wallpaper.png` by `render-wallpaper`. The stock PNG
(`desktop/wallpapers/shortcuts-latest.png`, deployed as
`~/.config/wallpapers/wallpaper.png`) is the lock-screen and greeter default;
the settings app's Lock screen page can pick another image.

## Blue light

`bluelight` drives the `hyprsunset` user service; the temperature is kept in
`~/.local/state/desktop/bluelight-temp`. `sunset-night` ramps it from 6500K
at 15:00 to 2500K at 18:00 (`theme-warmth-ramp` timer).
