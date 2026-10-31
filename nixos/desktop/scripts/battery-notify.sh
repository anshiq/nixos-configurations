# battery-notify: run every minute by battery-notify.timer. Notifies once at
# 15% and once at 5% per discharge cycle; the state resets on AC.

state_file="${XDG_RUNTIME_DIR:-/tmp}/battery-notify-state"

battery=""
for supply in /sys/class/power_supply/*; do
  if [ "$(cat "$supply/type" 2>/dev/null)" = Battery ]; then
    battery=$supply
    break
  fi
done
[ -n "$battery" ] || exit 0

status=$(cat "$battery/status")
capacity=$(cat "$battery/capacity")

if [ "$status" != Discharging ]; then
  rm -f "$state_file"
  exit 0
fi

last=$(cat "$state_file" 2>/dev/null || true)

if [ "$capacity" -le 5 ] && [ "$last" != 5 ]; then
  notify-send -u critical "Battery critical" "${capacity}% remaining - plug in now"
  echo 5 > "$state_file"
elif [ "$capacity" -le 15 ] && [ -z "$last" ]; then
  notify-send -u normal "Battery low" "${capacity}% remaining"
  echo 15 > "$state_file"
fi
