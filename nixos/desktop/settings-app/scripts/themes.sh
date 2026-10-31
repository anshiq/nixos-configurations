#!/usr/bin/env bash
# Lists what pages/AppearancePage.qml shows, one record per line:
#   current <theme>
#   theme <name> <palette json>
#   schedule <HH:MM> <theme>
# Reads the same deployed files theme-switch.sh uses; changes nothing.
set -u
cfg="$HOME/.config"
scripts="$cfg/waybar/scripts"

cur=$("$scripts/theme-status.sh" 2>/dev/null | sed -n 's/^Theme: \([^ ]*\).*/\1/p')
echo "current ${cur:-}"

if [ -r "$scripts/themes.list" ]; then
  while read -r name; do
    [ -n "$name" ] || continue
    json=$(tr -d '\n' <"$cfg/quickshell/theme-$name.json" 2>/dev/null || true)
    echo "theme $name ${json:-{\}}"
  done <"$scripts/themes.list"
fi

if [ -r "$scripts/schedule.list" ]; then
  while read -r t n; do
    [ -n "$t" ] && echo "schedule $t $n"
  done <"$scripts/schedule.list"
fi
exit 0
