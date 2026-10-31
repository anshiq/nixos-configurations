#!/usr/bin/env bash
# Prints the first battery's sysfs fields (and AC state) as key=value lines for
# pages/PowerPage.qml. Prints nothing on a machine without a battery.
set -u
b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
[ -n "$b" ] || exit 0
for k in status capacity energy_now energy_full energy_full_design power_now \
  charge_now charge_full charge_full_design current_now voltage_now \
  cycle_count technology model_name; do
  [ -r "$b/$k" ] && printf '%s=%s\n' "$k" "$(cat "$b/$k")"
done
for a in /sys/class/power_supply/A*; do
  [ -r "$a/online" ] && printf 'ac=%s\n' "$(cat "$a/online")"
done
exit 0
