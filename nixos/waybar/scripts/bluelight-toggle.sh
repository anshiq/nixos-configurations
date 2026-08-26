#!/usr/bin/env bash
# Toggles hyprsunset (Hyprland's blue-light filter) on/off at the saved
# temperature (see bluelight-adjust.sh) and asks waybar to re-run
# bluelight-status.sh so the topbar icon reflects the new state.
set -euo pipefail

state="$HOME/.cache/waybar-bluelight-temp"
default_temp=4000

mkdir -p "$(dirname "$state")"
[ -f "$state" ] || echo "$default_temp" > "$state"
temp=$(cat "$state")

if pgrep -x hyprsunset >/dev/null; then
  pkill -x hyprsunset
else
  setsid -f hyprsunset -t "$temp" >/dev/null 2>&1
fi

pkill -RTMIN+8 -x waybar 2>/dev/null || true
