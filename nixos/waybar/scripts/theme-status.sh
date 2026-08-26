#!/usr/bin/env bash
# Reports which desktop theme (day/night) is currently active, by reading
# what theme-switch.sh last pointed waybar's style.css symlink at - the
# same source of truth every themed app is flipped from.
set -euo pipefail

link="$HOME/.config/waybar/style.css"
# One level only - readlink -f would keep resolving through to the backing
# nix store path, whose basename home-manager rewrites (e.g. "style-
# night.css" becomes "hm_stylenight.css"), losing the day/night distinction.
target=$(readlink "$link" 2>/dev/null || true)

case "$target" in
  */style-day.css) mode="day" ;;
  */style-night.css) mode="night" ;;
  *) mode="unknown (style.css symlink missing - run theme-switch.sh)" ;;
esac

echo "Theme: $mode (hour $(date +%-H), day window is 06:00-17:00)"
