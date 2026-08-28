#!/usr/bin/env bash
# Reports which theme is currently active, by reading what theme-switch.sh
# last pointed the ghostty config symlink at - the same source of truth
# theme-switch.sh itself uses (see current_theme() there).
set -euo pipefail

link="$HOME/.config/ghostty/config"
target=$(readlink "$link" 2>/dev/null || true)

if [ -n "$target" ]; then
  name="${target##*/config-}"
else
  name="unknown (config symlink missing - run theme-switch.sh)"
fi

echo "Theme: $name (hour $(date +%-H), see ~/.config/waybar/scripts/schedule.list for the auto-switch schedule)"
