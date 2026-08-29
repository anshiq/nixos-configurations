#!/usr/bin/env bash
# Ramps hyprsunset's warmth from minimal (6500K, cool) at 15:00 up to
# maximum (2500K, warm) by 18:00, then holds there for the rest of
# sunset-night's window and the following black-white window (both
# kind=night - see ../../themes/schedule.nix for the actual times).
# theme-switch.sh resets the saved temp to the ramp's starting point every
# time sunset-night is (re)entered (see its own comment on that); this
# script only ever moves it forward from there.
#
# Run every 10 minutes by theme-warmth-ramp.timer (see desktop/home.nix) -
# a no-op outside 15:00-18:00, and a no-op if the active theme isn't
# kind=night (a manual override to a day theme mid-window should not fight
# it back on) or if hyprsunset isn't currently running (a manual toggle-off
# mid-window stays off until the next theme switch reasserts). Uses
# `hyprctl hyprsunset temperature` (Hyprland 0.56+) to adjust the running
# filter in place - no kill/respawn, no visible flash.
set -euo pipefail

ramp_start=$((15 * 60)) # 15:00
ramp_end=$((18 * 60))   # 18:00
min_temp=6500
max_temp=2500

now_minutes=$(( $(date +%-H) * 60 + $(date +%-M) ))
if [ "$now_minutes" -lt "$ramp_start" ] || [ "$now_minutes" -ge "$ramp_end" ]; then
  exit 0
fi

current=$(readlink "$HOME/.config/ghostty/config" 2>/dev/null || true)
current_theme="${current##*/config-}"
kind=$(awk -v n="$current_theme" '$1==n {print $2}' "$HOME/.config/waybar/scripts/theme-kinds.list")
[ "$kind" = "night" ] || exit 0

pgrep -x hyprsunset >/dev/null || exit 0

elapsed=$(( now_minutes - ramp_start ))
span=$(( ramp_end - ramp_start ))
temp=$(( min_temp - elapsed * (min_temp - max_temp) / span ))

echo "$temp" > "$HOME/.cache/waybar-bluelight-temp"
hyprctl hyprsunset temperature "$temp" >/dev/null 2>&1 || true
