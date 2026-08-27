#!/usr/bin/env bash
# Polled by the battery-notify user timer (see desktop/home.nix). Notifies
# once when battery capacity drops to 15%, then again at 5%, while
# discharging. State is kept in $XDG_RUNTIME_DIR so each threshold fires
# only once per discharge cycle - it resets as soon as the charger is
# plugged back in.
set -euo pipefail

cap_file=$(compgen -G '/sys/class/power_supply/BAT*/capacity' | head -n1) || exit 0
bat_dir=$(dirname "$cap_file")
status=$(cat "$bat_dir/status")
capacity=$(cat "$cap_file")
state_file="${XDG_RUNTIME_DIR:-/tmp}/battery-notify-state"

if [ "$status" != "Discharging" ]; then
  rm -f "$state_file"
  exit 0
fi

last=$(cat "$state_file" 2>/dev/null || echo "")

if [ "$capacity" -le 5 ] && [ "$last" != "5" ]; then
  notify-send -u critical "Battery critical" "${capacity}% remaining - plug in now"
  echo 5 > "$state_file"
elif [ "$capacity" -le 15 ] && [ "$last" != "15" ] && [ "$last" != "5" ]; then
  notify-send -u normal "Battery low" "${capacity}% remaining"
  echo 15 > "$state_file"
fi
