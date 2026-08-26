#!/usr/bin/env bash
# Reports hyprsunset's state as waybar custom-module JSON.
set -euo pipefail

state="$HOME/.cache/waybar-bluelight-temp"
default_temp=4000

mkdir -p "$(dirname "$state")"
[ -f "$state" ] || echo "$default_temp" > "$state"
temp=$(cat "$state")

if pgrep -x hyprsunset >/dev/null; then
  echo "{\"text\":\"☀\",\"alt\":\"on\",\"class\":\"active\",\"tooltip\":\"Blue light filter: on at ${temp}K (click: toggle off, scroll: adjust warmth)\"}"
else
  echo "{\"text\":\"☾\",\"alt\":\"off\",\"class\":\"inactive\",\"tooltip\":\"Blue light filter: off, ${temp}K saved (click: toggle on, scroll: adjust warmth)\"}"
fi
