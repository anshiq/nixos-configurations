#!/usr/bin/env bash
# Switches waybar between the day theme (09:00-17:00) and the sunset/night
# theme (everything else) by repointing the style.css symlink and asking
# any running waybar to reload its CSS.
set -euo pipefail

cfg="$HOME/.config/waybar"
hour=$(date +%-H)

if [ "$hour" -ge 9 ] && [ "$hour" -lt 17 ]; then
  target="$cfg/style-day.css"
else
  target="$cfg/style-night.css"
fi

ln -sfn "$target" "$cfg/style.css"

pkill -SIGUSR2 -x waybar 2>/dev/null || true
