# on-battery <command...>
# Runs the command only while the machine is running on battery (hypridle wraps
# its screen-off and suspend actions with this). With no battery at all - a
# desktop PC or a VM - it is always "on AC", so the command is skipped and the
# machine never dims or suspends on idle by itself.

have_battery=0
for supply in /sys/class/power_supply/*; do
  [ -r "$supply/type" ] || continue
  case "$(cat "$supply/type")" in
    Battery)
      # Peripherals (wireless mouse, headset) also show up as Battery with
      # scope=Device; only the machine's own battery counts.
      [ "$(cat "$supply/scope" 2>/dev/null)" = Device ] || have_battery=1
      ;;
    Mains)
      [ "$(cat "$supply/online" 2>/dev/null)" = 1 ] && exit 0
      ;;
  esac
done

[ "$have_battery" = 1 ] || exit 0

exec "$@"
