# bluelight status [--json] | toggle | on | off | set <kelvin> | adjust <+N|-N>
# Blue-light filter = the hyprsunset user service. The temperature lives in
# ~/.local/state/desktop/bluelight-temp; the service reads it on start, and a
# change is pushed to a running filter over Hyprland IPC (no restart, no
# flash). adjust takes a Kelvin delta (negative = warmer).

state_dir="$HOME/.local/state/desktop"
temp_file="$state_dir/bluelight-temp"
default_temp=4000
min_temp=2500
max_temp=6500

usage() {
  echo "usage: bluelight status [--json] | toggle | on | off | set <kelvin> | adjust <+N|-N>" >&2
  exit 1
}

is_on() {
  systemctl --user --quiet is-active hyprsunset.service
}

current_temp() {
  local t
  t=$(cat "$temp_file" 2>/dev/null || true)
  case "$t" in
    '' | *[!0-9]*) echo "$default_temp" ;;
    *) echo "$t" ;;
  esac
}

save_temp() {
  local t=$1
  [ "$t" -lt "$min_temp" ] && t=$min_temp
  [ "$t" -gt "$max_temp" ] && t=$max_temp
  mkdir -p "$state_dir"
  echo "$t" > "$temp_file.tmp"
  mv -f "$temp_file.tmp" "$temp_file"
  if is_on; then
    hyprctl hyprsunset temperature "$t" >/dev/null 2>&1 || true
  fi
}

case "${1:-}" in
  status)
    if is_on; then on=true; else on=false; fi
    if [ "${2:-}" = --json ]; then
      jq -cn --argjson on "$on" --argjson temp "$(current_temp)" '{on: $on, temp: $temp}'
    else
      echo "on: $on, temp: $(current_temp)K"
    fi
    ;;
  toggle)
    if is_on; then
      systemctl --user stop hyprsunset.service
    else
      systemctl --user start hyprsunset.service
    fi
    ;;
  on) systemctl --user start hyprsunset.service ;;
  off) systemctl --user stop hyprsunset.service ;;
  set)
    case "${2:-}" in
      '' | *[!0-9]*) usage ;;
    esac
    save_temp "$2"
    ;;
  adjust)
    delta="${2:-}"
    case "$delta" in
      +[0-9]* | -[0-9]* | [0-9]*) ;;
      *) usage ;;
    esac
    delta="${delta#+}"
    case "${delta#-}" in
      *[!0-9]*) usage ;;
    esac
    save_temp $(($(current_temp) + delta))
    ;;
  *) usage ;;
esac
