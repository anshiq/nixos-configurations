#!/usr/bin/env bash
# Backs the idle-timeout settings panel in PowerMenu.qml. hypridle's config
# used to be a static, home-manager-generated (read-only) file - that made
# the timeouts something only a nix edit + rebuild could change. Instead,
# home.nix now runs hypridle with no home-manager-owned config at all and
# this script is the only thing that ever writes ~/.config/hypr/hypridle.conf,
# generating it from a small state file the settings panel can edit at
# runtime (same pattern as quickshell's theme.json).
#
# `generate` (re)writes hypridle.conf from saved settings (or the defaults
# below if none exist yet) without restarting anything - this runs as
# hypridle's own ExecStartPre, so every hypridle start is guaranteed a
# config to read, first-run included.
# `set <lockMin> <screenOffMin> <suspendMin>` is called by the settings
# panel: saves the new values, regenerates the conf, and restarts hypridle
# so the new timeouts take effect immediately.
set -euo pipefail

state_dir="$HOME/.local/state/quickshell"
settings_file="$state_dir/idle-settings.json"
hypridle_conf="$HOME/.config/hypr/hypridle.conf"

default_lock_min=30
default_screenoff_min=32
default_suspend_min=35

mkdir -p "$state_dir" "$(dirname "$hypridle_conf")"

write_conf() {
  local lock_min=$1 screenoff_min=$2 suspend_min=$3
  cat >"$hypridle_conf" <<CONF
general {
    lock_cmd = quickshell ipc call lockscreen lock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
    ignore_dbus_inhibit = false
}

# Fires regardless of AC/battery.
listener {
    timeout = $((lock_min * 60))
    on-timeout = quickshell ipc call lockscreen lock
}

# Screen-off and suspend below only fire on battery - idle-unless-charging.sh
# is a no-op while charging, so the screen stays lit and the system stays
# awake as long as the charger is connected.
listener {
    timeout = $((screenoff_min * 60))
    on-timeout = $HOME/.config/waybar/scripts/idle-unless-charging.sh hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = $((suspend_min * 60))
    on-timeout = $HOME/.config/waybar/scripts/idle-unless-charging.sh systemctl suspend
}
CONF
}

read_settings() {
  lock_min="$default_lock_min"
  screenoff_min="$default_screenoff_min"
  suspend_min="$default_suspend_min"
  if [ -f "$settings_file" ]; then
    lock_min=$(sed -n 's/.*"lockMinutes": *\([0-9]*\).*/\1/p' "$settings_file")
    screenoff_min=$(sed -n 's/.*"screenOffMinutes": *\([0-9]*\).*/\1/p' "$settings_file")
    suspend_min=$(sed -n 's/.*"suspendMinutes": *\([0-9]*\).*/\1/p' "$settings_file")
    lock_min="${lock_min:-$default_lock_min}"
    screenoff_min="${screenoff_min:-$default_screenoff_min}"
    suspend_min="${suspend_min:-$default_suspend_min}"
  fi
}

case "${1:-}" in
generate)
  read_settings
  write_conf "$lock_min" "$screenoff_min" "$suspend_min"
  # Ensure the settings file always exists (with resolved values, defaults
  # included) once hypridle has started at least once, so the settings
  # panel's FileView has something to read even before the user ever
  # changes anything.
  [ -f "$settings_file" ] || printf '{"lockMinutes": %d, "screenOffMinutes": %d, "suspendMinutes": %d}\n' \
    "$lock_min" "$screenoff_min" "$suspend_min" >"$settings_file"
  ;;
set)
  lock_min="${2:?lock minutes required}"
  screenoff_min="${3:?screen-off minutes required}"
  suspend_min="${4:?suspend minutes required}"
  printf '{"lockMinutes": %d, "screenOffMinutes": %d, "suspendMinutes": %d}\n' \
    "$lock_min" "$screenoff_min" "$suspend_min" >"$settings_file"
  write_conf "$lock_min" "$screenoff_min" "$suspend_min"
  systemctl --user restart hypridle.service
  ;;
*)
  echo "usage: idle-settings.sh {generate|set <lockMin> <screenOffMin> <suspendMin>}" >&2
  exit 1
  ;;
esac
