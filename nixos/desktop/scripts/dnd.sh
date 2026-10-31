# dnd [status [--json] | toggle | on | off]
# Do not disturb: while on, the notification popups stay silent (critical
# notifications still show). The state is ~/.local/state/desktop/dnd, which
# Quickshell watches.

state_dir="$HOME/.local/state/desktop"
file="$state_dir/dnd"

is_on() {
  [ "$(cat "$file" 2>/dev/null || true)" = on ]
}

write() {
  mkdir -p "$state_dir"
  printf '%s\n' "$1" > "$file.tmp"
  mv -f "$file.tmp" "$file"
}

set_state() {
  if [ "$1" = on ]; then
    # Announce before the popups go quiet.
    notify-send -t 1500 "Do not disturb" "On" 2>/dev/null || true
    sleep 0.2
    write on
  else
    write off
    notify-send -t 1500 "Do not disturb" "Off" 2>/dev/null || true
  fi
}

case "${1:-status}" in
  toggle)
    if is_on; then set_state off; else set_state on; fi
    ;;
  on) set_state on ;;
  off) set_state off ;;
  status)
    if is_on; then dnd=true; else dnd=false; fi
    if [ "${2:-}" = --json ]; then
      jq -cn --argjson dnd "$dnd" '{dnd: $dnd}'
    else
      echo "dnd: $dnd"
    fi
    ;;
  *)
    echo "usage: dnd [status [--json] | toggle | on | off]" >&2
    exit 1
    ;;
esac
