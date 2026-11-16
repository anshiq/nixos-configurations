#!/bin/sh
# yazi opener for non-text files (PDFs, images, ...): `open.sh FILE`.
#
# Two things about plain `xdg-open` made the terminal lose focus:
#  1. xdg-open is routed through xdg-desktop-portal (xdgOpenUsePortal), whose
#     GTK "Open With" chooser pops up as its own window for ~2s and takes
#     focus. Unsetting NIXOS_XDG_OPEN_USE_PORTAL makes xdg-open launch the
#     default app directly, so there is no chooser.
#  2. Hyprland focuses every new window, so the viewer then takes focus too.
#     Under Hyprland we hand focus back to the window yazi runs in, so you
#     can keep browsing; click or hover the viewer (follow_mouse) to use it.
#     Set YAZI_OPEN_KEEP_FOCUS=0 to let the viewer keep focus instead.
#
# Outside Hyprland (e.g. over SSH) this is just a portal-less xdg-open.

hypr=0
if [ "${YAZI_OPEN_KEEP_FOCUS:-1}" != 0 ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] &&
  command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  hypr=1
  prev=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
  before=$(hyprctl clients -j 2>/dev/null | jq -r '.[].address')
fi

env -u NIXOS_XDG_OPEN_USE_PORTAL setsid -f xdg-open "$@" >/dev/null 2>&1

[ "$hypr" = 1 ] && [ -n "$prev" ] || exit 0

# Wait (max ~6s) for the viewer's window to map, then move focus back to
# the terminal - but only if the new window actually took focus, so a
# deliberate focus change by the user in the meantime is left alone.
for _ in $(seq 1 30); do
  sleep 0.2
  active=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
  if [ -n "$active" ] && [ "$active" != "$prev" ] &&
    ! printf '%s\n' "$before" | grep -qxF "$active"; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$prev\" })" >/dev/null 2>&1
    exit 0
  fi
done
