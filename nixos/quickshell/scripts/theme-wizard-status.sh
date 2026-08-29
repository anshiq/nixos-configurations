#!/usr/bin/env bash
# One-shot JSON snapshot for the user.themeWizard plugin (Overlay.qml): the
# active theme, every theme's palette + kind, and the day/night schedule
# with its currently-active window - so the wizard needs a single Process
# call instead of juggling FileViews per theme like Colors.qml does for the
# live palette. Read-only; all switching still goes through
# theme-switch.sh, same as the keybind and every other caller.
set -euo pipefail

scripts_dir="$HOME/.config/waybar/scripts"
themes_file="$scripts_dir/themes.list"
kinds_file="$scripts_dir/theme-kinds.list"
schedule_file="$scripts_dir/schedule.list"
quickshell_cfg="$HOME/.config/quickshell"

current_theme() {
  local current
  current=$(readlink "$HOME/.config/ghostty/config" 2>/dev/null || true)
  echo "${current##*/config-}"
}

json_field() {
  sed -n "s/.*\"$2\": *\"#\\{0,1\\}\\([^\"]*\\)\".*/\\1/p" "$1" | head -n1
}

esc() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

current="$(current_theme)"
now="$(date +%H:%M)"

themes_json=""
while read -r name; do
  [ -z "$name" ] && continue
  theme_json="$quickshell_cfg/theme-$name.json"
  [ -f "$theme_json" ] || continue
  kind=$(awk -v n="$name" '$1==n {print $2}' "$kinds_file")
  bg=$(json_field "$theme_json" background)
  fg=$(json_field "$theme_json" foreground)
  accent=$(json_field "$theme_json" accent)
  red=$(json_field "$theme_json" red)
  green=$(json_field "$theme_json" green)
  yellow=$(json_field "$theme_json" yellow)
  blue=$(json_field "$theme_json" blue)
  entry=$(printf '{"name":"%s","kind":"%s","background":"#%s","foreground":"#%s","accent":"#%s","red":"#%s","green":"#%s","yellow":"#%s","blue":"#%s","active":%s}' \
    "$(esc "$name")" "$(esc "$kind")" "$bg" "$fg" "$accent" "$red" "$green" "$yellow" "$blue" \
    "$([ "$name" = "$current" ] && echo true || echo false)")
  themes_json="${themes_json:+$themes_json,}$entry"
done < "$themes_file"

schedule_json=""
active_index=-1
i=0
while read -r t name; do
  [ -z "${t:-}" ] && continue
  if [[ "$now" > "$t" || "$now" == "$t" ]]; then
    active_index=$i
  fi
  entry=$(printf '{"time":"%s","theme":"%s"}' "$(esc "$t")" "$(esc "$name")")
  schedule_json="${schedule_json:+$schedule_json,}$entry"
  i=$((i + 1))
done < "$schedule_file"
# Before the first scheduled entry of the day - the active window wraps
# around from the last entry of the previous day (mirrors theme-switch.sh's
# own no-arg fallback).
[ "$active_index" -eq -1 ] && active_index=$((i - 1))

printf '{"current":"%s","now":"%s","themes":[%s],"schedule":[%s],"activeScheduleIndex":%s}\n' \
  "$(esc "$current")" "$(esc "$now")" "$themes_json" "$schedule_json" "$active_index"
