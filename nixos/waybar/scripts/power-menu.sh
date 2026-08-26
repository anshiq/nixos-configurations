#!/usr/bin/env bash

confirm() {
  [ "$(printf 'No\nYes\n' | wofi --dmenu --prompt "$1" --width 320 --height 160)" = "Yes" ]
}

choice=$(printf 'Lock\nLogout\nSuspend\nReboot\nShutdown\n' | wofi --dmenu --prompt "Power" --width 320 --height 280)

case "$choice" in
  Lock)
    pidof hyprlock || hyprlock
    ;;
  Logout)
    # The session is UWSM-managed (see desktop/system.nix, withUWSM = true),
    # so it must be torn down via `uwsm stop` rather than `hyprctl dispatch
    # exit` - otherwise the UWSM-generated units don't unwind cleanly and
    # control never gets handed back to SDDM's login screen.
    uwsm stop
    ;;
  Suspend)
    systemctl suspend
    ;;
  Reboot)
    confirm "Reboot now?" && systemctl reboot
    ;;
  Shutdown)
    confirm "Power off now?" && systemctl poweroff
    ;;
esac
