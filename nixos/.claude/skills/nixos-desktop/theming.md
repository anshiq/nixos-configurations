# Themes

Read this before changing themes, colors, or the day/night schedule.

Ported from Omarchy's `theming.md`. The mechanism is completely different -
Omarchy themes are directories of config files copied into `~/.config/`
live; ours are Nix attrsets that *generate* those files at build time. Read
`themes/generators.nix` before assuming any file-format detail carries
over.

## How it actually works

```
themes/
├── default.nix       # every theme, keyed by name - the registry
├── schedule.nix       # time -> theme name, for the auto-switch timers
├── generators.nix     # pure functions: one theme -> ghostty/kitty/hyprlock/
│                       # Quickshell-JSON/Hyprland-border-Lua/zellij text
├── tokyo-night.nix, sunset-night.nix, mono.nix, forest-green.nix,
│   ocean-blue.nix     # the actual theme definitions
```

Each theme file is a plain attrset: `background`, `foreground`,
`brightForeground`, `muted`, `selection`, `red`/`green`/`yellow`/`blue`/
`magenta`/`cyan`, `accent`, `cursor`, `bright*` variants, and
`borderActive1`/`borderActive2`/`borderInactive` for Hyprland's window
borders. `desktop/home.nix` loops over every entry in `themes/default.nix`
and renders a full file set for each one - ghostty, kitty, hyprlock,
Quickshell's `theme-<name>.json`, and Hyprland's `colors-<name>.lua` - via
`generators.nix`. Nothing about a theme's *files* is hand-written except
the theme's own definition.

## Switching themes

```bash
~/.config/waybar/scripts/theme-switch.sh <name>   # e.g. ocean-blue
~/.config/waybar/scripts/theme-switch.sh toggle   # flip day/night `kind`
~/.config/waybar/scripts/theme-switch.sh next     # cycle all themes
~/.config/waybar/scripts/theme-status.sh          # what's active now
```

No `omarchy theme list`/`current` equivalent exists as a single command -
`ls themes/*.nix` for the list, `theme-status.sh` for current.

## Making a New Theme

1. Copy an existing theme file, e.g. `cp themes/tokyo-night.nix themes/mytheme.nix`.
2. Edit every field to the new palette. All fields are required - there's
   no "inherit unset fields from a base theme" mechanism (unlike Omarchy's
   `colors.toml` + role fallback chain in `Color.qml`).
3. Add one line to `themes/default.nix`: `mytheme = import ./mytheme.nix;`.
4. Optionally add it to `themes/schedule.nix` if it should run automatically
   at a given time.
5. `sudo nixos-rebuild switch --flake nixos-configurations/nixos#nixos` -
   **this step has no Omarchy equivalent and is easy to forget**: editing
   the `.nix` file alone does nothing until rebuilt, unlike Omarchy where
   `~/.config/omarchy/themes/<name>/colors.toml` takes effect on
   `omarchy theme set` immediately.
6. `theme-switch.sh mytheme` to apply it live.

## What You Can and Can't Overlay

Omarchy lets you overlay just `colors.toml` on top of a stock theme and
keep everything else. There is no overlay concept here - every theme file
must define every field, because `generators.nix` reads the whole attrset
with no defaults. If you only want to tweak one color of an existing theme,
copy the whole file (step 1 above) rather than trying to partially
override it.

## Fonts

No `omarchy font set` equivalent. The font
(`"JetBrainsMono Nerd Font"`) is a literal string repeated across
`desktop/home.nix`, `quickshell/Bar.qml`, and the generator functions in
`themes/generators.nix`. Changing it means editing all of those - there is
no single fontconfig-alias indirection like Omarchy's `omarchy-font-set`
provides. This is a real gap (see the SKILL.md gap list) worth centralizing
into one Nix value if it comes up often.

## Backgrounds

The wallpaper is one file (`desktop/wallpapers/shortcuts-latest.png`),
shared by swaybg, hyprlock, and the SDDM greeter (see
`desktop/system.nix`) - deliberately kept in sync, unlike Omarchy where
each theme carries its own background set and `omarchy theme bg next`
cycles through them. There is no per-theme background or cycling here.
