#!/usr/bin/env bash
# Runs its arguments as a command, but only while on battery power. Used to
# wrap hypridle's dpms-off/suspend on-timeout actions (see desktop/home.nix)
# so the screen never blanks and the system never suspends while charging.
set -euo pipefail

if grep -qs 1 /sys/class/power_supply/*/online 2>/dev/null; then
  exit 0
fi

exec "$@"
