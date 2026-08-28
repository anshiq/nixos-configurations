# Every available theme, keyed by name. Adding a theme = add one file here
# (copy an existing one and adjust the fields) plus a line below - nothing
# else in this repo needs to change; desktop/home.nix generates a full file
# set (ghostty, kitty, hyprlock, Hyprland border colors, Quickshell/zellij
# palettes) for every entry in this attrset.
{
  tokyo-night = import ./tokyo-night.nix;
  sunset-night = import ./sunset-night.nix;
  mono = import ./mono.nix;
  forest-green = import ./forest-green.nix;
  ocean-blue = import ./ocean-blue.nix;
}
