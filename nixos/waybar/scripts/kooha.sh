#!/usr/bin/env bash
# Kooha's window lives on the silent "kooha" special workspace (see the
# window rule in hypr/hyprland.lua), since Hyprland can't minimize it the
# way GNOME does. Every click toggles that workspace into/out of view, so
# you can bring it forward to press Record/Stop and tuck it away again.
# The toggle runs *before* launching so a first-time launch lands on the
# now-visible workspace instead of opening silently hidden.
hyprctl dispatch togglespecialworkspace kooha
pgrep -x kooha >/dev/null || setsid -f kooha >/dev/null 2>&1
