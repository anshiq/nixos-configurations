# Every available theme, keyed by name. Adding a theme = add one file here
# (copy an existing one and adjust the fields) plus a line below - nothing
# else in this repo needs to change; desktop/home.nix generates a full file
# set (ghostty, kitty, hyprlock, Hyprland border colors, Quickshell/zellij
# palettes) for every entry in this attrset.
#
# Kept to exactly 4 themes on purpose, one per ../themes/schedule.nix
# window - see that file for the actual times. tokyo-night and ocean-blue
# were dropped (not replaced) to get there.
{
  forest-green = import ./forest-green.nix;
  mono = import ./mono.nix;
  sunset-night = import ./sunset-night.nix;
  black-white = import ./black-white.nix;
}
