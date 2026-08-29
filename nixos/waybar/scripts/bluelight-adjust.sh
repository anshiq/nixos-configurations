#!/usr/bin/env bash
# Adjusts the saved hyprsunset color temperature by one step per call and,
# if the filter is currently on, applies it live via `hyprctl hyprsunset
# temperature` (Hyprland 0.56+) - adjusts the running filter in place, no
# kill/respawn, no visible flash. $1 is +1 (hotter/warmer, lower Kelvin) or
# -1 (cooler, higher Kelvin) - hook up to waybar scroll.
set -euo pipefail

state="$HOME/.cache/waybar-bluelight-temp"
default_temp=4000
min_temp=2500
max_temp=6500
step=500

mkdir -p "$(dirname "$state")"
[ -f "$state" ] || echo "$default_temp" > "$state"

current=$(cat "$state")
direction="${1:-0}"

new=$(( current - direction * step ))
if [ "$new" -lt "$min_temp" ]; then new=$min_temp; fi
if [ "$new" -gt "$max_temp" ]; then new=$max_temp; fi
echo "$new" > "$state"

if pgrep -x hyprsunset >/dev/null; then
  hyprctl hyprsunset temperature "$new" >/dev/null 2>&1
fi

pkill -RTMIN+8 -x waybar 2>/dev/null || true
