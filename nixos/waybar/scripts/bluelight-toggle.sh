#!/usr/bin/env bash
# Toggles hyprsunset (Hyprland's blue-light filter) on/off and asks waybar
# to re-run bluelight-status.sh so the topbar icon reflects the new state.
set -euo pipefail

if pgrep -x hyprsunset >/dev/null; then
  pkill -x hyprsunset
else
  setsid -f hyprsunset -t 4000 >/dev/null 2>&1
fi

pkill -RTMIN+8 -x waybar 2>/dev/null || true
