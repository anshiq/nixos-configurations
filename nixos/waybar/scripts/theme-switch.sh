#!/usr/bin/env bash
# Switches the whole desktop between the day theme (05:00-17:00) and the
# sunset/night theme (everything else): ghostty, kitty, and hyprlock each get
# their active config symlink repointed, then get nudged to reload (waybar,
# wofi and mako are gone as of Phase 2/4/6 - Quickshell's Colors.qml watches
# theme.json directly, see below); Hyprland's own border colors are updated
# live via
# `hyprctl eval` (no config file/reload involved for those); hyprsunset
# (the blue-light filter) is auto-started going into night and auto-stopped
# going into day, at whatever warmth was last saved via the topbar scroll
# control (see bluelight-*.sh) - it can still be toggled manually via the
# topbar in between switches, but the next switch re-asserts the
# mode-appropriate on/off state. Note: this config is Lua-based
# (hyprland.lua), and Hyprland 0.56 refuses `hyprctl keyword` entirely for
# non-legacy (Lua) parsers ("keyword can't work with non-legacy parsers.
# Use eval.") - `eval` runs a Lua snippet against the live config instead,
# so the border override has to go through hl.config(...).
# Optional arg: "day"/"night" force that mode; "toggle" flips whatever's
# currently active (read from the ghostty symlink, the same source of truth
# theme-status.sh uses). No arg (the systemd timer / login-autostart path)
# keeps the original clock-based behavior. This is what lets a manual
# keybind (see hyprland.lua's mod+SHIFT+T) actually change anything - running
# this with no override just recomputes the same clock-based mode you're
# already in most of the time, which looks like "toggling does nothing".
set -euo pipefail

ghostty_cfg="$HOME/.config/ghostty"

case "${1:-}" in
  day | night)
    mode="$1"
    ;;
  toggle)
    current=$(readlink "$ghostty_cfg/config" 2>/dev/null || true)
    case "$current" in
      */config-night) mode="day" ;;
      *) mode="night" ;;
    esac
    ;;
  "")
    hour=$(date +%-H)
    if [ "$hour" -ge 5 ] && [ "$hour" -lt 17 ]; then
      mode="day"
    else
      mode="night"
    fi
    ;;
  *)
    echo "usage: theme-switch.sh [day|night|toggle]" >&2
    exit 1
    ;;
esac

kitty_cfg="$HOME/.config/kitty"
hypr_cfg="$HOME/.config/hypr"
# quickshell/ (unlike the directories above) is deployed as a single
# whole-directory xdg.configFile symlink straight into the Nix store, so
# ~/.config/quickshell itself is read-only - theme.json can't be written
# there. It lives in state dir instead; Colors.qml watches it at this path.
quickshell_cfg="$HOME/.config/quickshell"
quickshell_state="$HOME/.local/state/quickshell"

ln -sfn "$ghostty_cfg/config-$mode" "$ghostty_cfg/config"
ln -sfn "$kitty_cfg/kitty-$mode.conf" "$kitty_cfg/kitty.conf"
ln -sfn "$hypr_cfg/hyprlock-$mode.conf" "$hypr_cfg/hyprlock.conf"
# Quickshell's Colors.qml watches theme.json for live changes (see
# quickshell/Colors.qml) - a real content copy rather than a symlink swap,
# since a symlink retarget doesn't reliably fire the inotify watch Quickshell
# uses to detect the change. `install` (not `cp`) deliberately: the source is
# a read-only (444) nix store file, and a plain `cp` onto a *new*
# destination inherits that source mode, leaving theme.json permanently
# unwritable (silent `set -e` abort here on every run after the first,
# breaking every switch since - border colors, hyprsunset, and the bar
# palette all live past this line). `install` always writes the given mode
# on the destination instead of inheriting the source's.
mkdir -p "$quickshell_state"
install -m 644 "$quickshell_cfg/theme-$mode.json" "$quickshell_state/theme.json"

# Symlink swaps don't touch the watched inode, so each running app needs an
# explicit nudge rather than relying on its own file-watcher to notice the
# change. hyprlock is launched fresh each time, so it just picks up the new
# symlink target on its next run - no nudge needed for it.
pkill -SIGUSR2 -x ghostty 2>/dev/null || true
pkill -SIGUSR1 -x kitty 2>/dev/null || true

if [ "$mode" = "day" ]; then
  active_border_colors='"rgba(7aa2f7ee)", "rgba(bb9af7ee)"'
  inactive_border="rgba(414868aa)"
else
  active_border_colors='"rgba(ff9e64ee)", "rgba(e0af68ee)"'
  inactive_border="rgba(4a3728aa)"
fi
hyprctl eval "hl.config({ general = { col = { active_border = { colors = { $active_border_colors }, angle = 45 }, inactive_border = \"$inactive_border\" } } })" >/dev/null 2>&1 || true

bluelight_state="$HOME/.cache/waybar-bluelight-temp"
bluelight_default_temp=4000
mkdir -p "$(dirname "$bluelight_state")"
[ -f "$bluelight_state" ] || echo "$bluelight_default_temp" > "$bluelight_state"
bluelight_temp=$(cat "$bluelight_state")

if [ "$mode" = "night" ]; then
  if ! pgrep -x hyprsunset >/dev/null; then
    setsid -f hyprsunset -t "$bluelight_temp" >/dev/null 2>&1
    # setsid -f returns as soon as the process forks, before we know it
    # actually stayed up - give it a moment then verify, since a failed
    # launch here would otherwise be silent (stdout/stderr are discarded
    # above) until the next scheduled switch.
    sleep 0.3
    pgrep -x hyprsunset >/dev/null || notify-send "Sunset theme" "hyprsunset (blue-light filter) failed to start" 2>/dev/null || true
  fi
else
  { pgrep -x hyprsunset >/dev/null && pkill -x hyprsunset; } || true
fi
