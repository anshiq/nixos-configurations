#!/usr/bin/env bash
# Switches the whole desktop between the day theme (06:00-17:00) and the
# sunset/night theme (everything else): waybar, ghostty, kitty, wofi, mako,
# and hyprlock each get their active config symlink repointed, then get
# nudged to reload; Hyprland's own border colors are updated live via
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
set -euo pipefail

hour=$(date +%-H)
if [ "$hour" -ge 6 ] && [ "$hour" -lt 17 ]; then
  mode="day"
else
  mode="night"
fi

waybar_cfg="$HOME/.config/waybar"
ghostty_cfg="$HOME/.config/ghostty"
kitty_cfg="$HOME/.config/kitty"
wofi_cfg="$HOME/.config/wofi"
mako_cfg="$HOME/.config/mako"
hypr_cfg="$HOME/.config/hypr"

ln -sfn "$waybar_cfg/style-$mode.css" "$waybar_cfg/style.css"
ln -sfn "$ghostty_cfg/config-$mode" "$ghostty_cfg/config"
ln -sfn "$kitty_cfg/kitty-$mode.conf" "$kitty_cfg/kitty.conf"
ln -sfn "$wofi_cfg/style-$mode.css" "$wofi_cfg/style.css"
ln -sfn "$mako_cfg/config-$mode" "$mako_cfg/config"
ln -sfn "$hypr_cfg/hyprlock-$mode.conf" "$hypr_cfg/hyprlock.conf"

# Symlink swaps don't touch the watched inode, so each running app needs an
# explicit nudge rather than relying on its own file-watcher to notice the
# change. wofi and hyprlock are launched fresh each time, so they just pick
# up the new symlink target on their next run - no nudge needed for them.
pkill -SIGUSR2 -x waybar 2>/dev/null || true
pkill -SIGUSR2 -x ghostty 2>/dev/null || true
pkill -SIGUSR1 -x kitty 2>/dev/null || true
command -v makoctl >/dev/null 2>&1 && makoctl reload 2>/dev/null || true

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
pkill -RTMIN+8 -x waybar 2>/dev/null || true
