#!/usr/bin/env bash
# Lists lock-screen wallpaper candidates for pages/LockScreenPage.qml:
#   state <json from lockscreen.json>      (if one has been saved)
#   img <absolute path>
# PNG/JPG only: this Qt build has no WebP image plugin, and an image Qt cannot
# decode would leave the lock screen with no wallpaper.
# Sources: the repo's desktop/wallpapers/ (this script lives two levels below
# it) and ~/Pictures/Wallpapers (created here so there is somewhere to drop files).
set -u
repo=$(cd -P "$(dirname "$0")/../.." && pwd -P)/wallpapers
user="$HOME/Pictures/Wallpapers"
mkdir -p "$user" 2>/dev/null

state="$HOME/.local/state/desktop/lockscreen.json"
[ -r "$state" ] && echo "state $(tr -d '\n' <"$state")"

for d in "$repo" "$user"; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 2 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) |
    sort | sed 's/^/img /'
done
exit 0
