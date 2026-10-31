# on-battery <command...>
# Runs the command only while no AC adapter is online (hypridle wraps its
# screen-off and suspend actions with this).

for supply in /sys/class/power_supply/*; do
  [ -r "$supply/type" ] || continue
  if [ "$(cat "$supply/type")" = Mains ] && [ "$(cat "$supply/online" 2>/dev/null)" = 1 ]; then
    exit 0
  fi
done

exec "$@"
