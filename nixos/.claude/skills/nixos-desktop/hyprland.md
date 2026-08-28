# Hyprland Configuration

Read this before changing keybindings, monitors, window rules, or animations.

Ported from Omarchy's `hyprland.md`. Omarchy splits user config across
`bindings.lua`/`monitors.lua`/`input.lua`/`looknfeel.lua`/`autostart.lua`,
loaded after its own defaults. **This system has none of that split** - one
file, `nixos/hypr/hyprland.lua`, holds everything: monitor config, env
vars, autostart, look-and-feel, animations, gestures, and every keybinding,
in that order. There is no separate "defaults then user overrides" layering
- it's the whole config, hand-authored.

```
nixos/hypr/hyprland.lua   # everything - monitors, binds, look-and-feel, autostart
```

**Key behaviors:**
- Hyprland auto-reloads on config save once home-manager has linked the
  file at least once - same as Omarchy, no restart needed for most changes
- Use `hyprctl reload` to force a reload
- After any change, validate with `hyprctl reload` then `hyprctl configerrors`
- No `omarchy refresh hyprland` equivalent - `git checkout -- nixos/hypr/hyprland.lua`
  reverts to the last commit instead

Border colors are the one part of this file that's theme-driven rather than
static - see `theming.md`'s note on `colors-<name>.lua` and
`hypr/hyprland.lua`'s `dofile("colors.lua")` at the top of the look-and-feel
section. Don't hand-edit border colors directly in this file; they're
overwritten by the next theme switch.

## Keybindings

Edit `hl.bind(...)` calls directly in `hyprland.lua` (no separate
`bindings.lua` to open). Format:

```lua
hl.bind(mod .. " + E", hl.dsp.exec_cmd("nautilus"))
```

View current bindings: read the "KEYBINDINGS" section of `hyprland.lua`
directly - there's no `omarchy menu keybindings --print` equivalent.

**When re-binding an existing key:** check the file for the existing
`hl.bind` call on that combination first. Hyprland's Lua API has no
separate `hl.unbind` call pattern documented here the way Omarchy's does -
removing/replacing the existing `hl.bind(...)` line for that key is how
it's done in this file (search for the key combo string before adding a
duplicate binding, which would otherwise silently shadow or conflict).
Always tell the user what a rebound key used to do.

## Display/Monitors

No separate `monitors.lua` - edit the `hl.monitor({...})` call near the top
of `hyprland.lua`:

```lua
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
```

List monitors and supported modes: `hyprctl monitors all` (same as Omarchy).

## Window Rules

**CRITICAL: Hyprland window rules syntax changes frequently between
versions - this applies here exactly as it does on Omarchy.** Before
writing any window rules, fetch current docs from
https://wiki.hypr.land/Configuring/Basics/Window-Rules/ rather than relying
on memorized syntax.

Window rules are `hl.window_rule({...})` calls in the "WINDOW RULES"
section at the bottom of `hyprland.lua` - no `o.window()` helper exists
here (that's an Omarchy-specific wrapper), just the raw Hyprland Lua API.
