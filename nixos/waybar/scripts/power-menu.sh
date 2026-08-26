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
    hyprctl dispatch exit
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
