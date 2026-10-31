# float-terminal [-e COMMAND [ARGS...]]
# A ghostty window that Hyprland floats and centres (rule for the
# dev.nixos.floatterm class in hypr/hyprland.lua). It opens in the directory it
# was started from, which is what makes Thunar's "Open Terminal Here" land in
# the right folder: exo-open starts it with that folder as its working
# directory. It is also the terminal behind xdg-terminal-exec, so
# terminal-only apps opened from a file manager (Helix, yazi) use it too.
# A separate instance per window (no single-instance D-Bus hand-off), because
# that hand-off would open the window in $HOME instead.
exec ghostty \
  --gtk-single-instance=false \
  --class=dev.nixos.floatterm \
  --working-directory="$PWD" \
  "$@"
