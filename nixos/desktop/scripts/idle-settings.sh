# idle-settings get [--json] | set <lock> <dpms> <suspend> | generate
# Idle timeouts in minutes (0 = never), stored in
# ~/.local/state/desktop/idle.json as {"lock", "dpms", "suspend"}.
#   generate  write ~/.config/hypr/hypridle.conf from them (hypridle's
#             ExecStartPre, so it always has a config)
#   set       save, regenerate, restart hypridle
# Screen-off and suspend only fire on battery ($on_battery, set by Nix).

state_dir="$HOME/.local/state/desktop"
settings_file="$state_dir/idle.json"
hypridle_conf="$HOME/.config/hypr/hypridle.conf"

default_lock=30
default_dpms=32
default_suspend=35

usage() {
  echo "usage: idle-settings get [--json] | set <lock> <dpms> <suspend> | generate" >&2
  exit 1
}

is_minutes() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
  esac
}

read_settings() {
  lock=$default_lock
  dpms=$default_dpms
  suspend=$default_suspend
  [ -f "$settings_file" ] || return 0
  local l d s
  l=$(jq -r '.lock // empty' "$settings_file" 2>/dev/null || true)
  d=$(jq -r '.dpms // empty' "$settings_file" 2>/dev/null || true)
  s=$(jq -r '.suspend // empty' "$settings_file" 2>/dev/null || true)
  if is_minutes "$l"; then lock=$l; fi
  if is_minutes "$d"; then dpms=$d; fi
  if is_minutes "$s"; then suspend=$s; fi
}

write_settings() {
  mkdir -p "$state_dir"
  jq -n --argjson lock "$lock" --argjson dpms "$dpms" --argjson suspend "$suspend" \
    '{lock: $lock, dpms: $dpms, suspend: $suspend}' > "$settings_file.tmp"
  mv -f "$settings_file.tmp" "$settings_file"
}

write_conf() {
  mkdir -p "$(dirname "$hypridle_conf")"
  {
    cat <<CONF
general {
    lock_cmd = quickshell ipc call lockscreen lock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
    ignore_dbus_inhibit = false
}
CONF
    if [ "$lock" -gt 0 ]; then
      cat <<CONF

listener {
    timeout = $((lock * 60))
    on-timeout = quickshell ipc call lockscreen lock
}
CONF
    fi
    if [ "$dpms" -gt 0 ]; then
      cat <<CONF

listener {
    timeout = $((dpms * 60))
    on-timeout = $on_battery hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
}
CONF
    fi
    if [ "$suspend" -gt 0 ]; then
      cat <<CONF

listener {
    timeout = $((suspend * 60))
    on-timeout = $on_battery systemctl suspend
}
CONF
    fi
  } > "$hypridle_conf.tmp"
  mv -f "$hypridle_conf.tmp" "$hypridle_conf"
}

case "${1:-}" in
  get)
    read_settings
    if [ "${2:-}" = --json ]; then
      jq -cn --argjson lock "$lock" --argjson dpms "$dpms" --argjson suspend "$suspend" \
        '{lock: $lock, dpms: $dpms, suspend: $suspend}'
    else
      echo "lock: ${lock}m, dpms: ${dpms}m, suspend: ${suspend}m (0 = never)"
    fi
    ;;
  generate)
    read_settings
    write_conf
    [ -f "$settings_file" ] || write_settings
    ;;
  set)
    if ! is_minutes "${2:-}" || ! is_minutes "${3:-}" || ! is_minutes "${4:-}"; then
      usage
    fi
    lock=$((10#$2))
    dpms=$((10#$3))
    suspend=$((10#$4))
    write_settings
    write_conf
    systemctl --user restart hypridle.service
    ;;
  *) usage ;;
esac
