#!/usr/bin/env bash
# Renders desktop/wallpapers/shortcuts-latest.svg (a __TOKEN__ placeholder
# template - see its own header comment) into a themed PNG, using the colors
# from one theme's quickshell theme.json. Called by theme-switch.sh on every
# switch, passing the just-installed theme.json path as $1.
#
# Output goes under $HOME/.local/state/wallpaper/, not ~/.config/wallpapers/ -
# the latter is a read-only home-manager symlink into the Nix store (same
# reason theme.json itself lives in state, see theme-switch.sh's header
# comment on quickshell_state). hyprland.lua points swaybg at the state path
# so it picks up whatever this script last rendered.
set -euo pipefail

theme_json="$1"
template="$HOME/.config/wallpapers/shortcuts-latest.svg"
out_dir="$HOME/.local/state/wallpaper"
mkdir -p "$out_dir"

# Same sed-based field extraction theme-switch.sh already uses for the
# border colors out of this same file - kept identical so both stay correct
# against the same JSON shape.
json_field() {
  sed -n "s/.*\"$2\": *\"#\\{0,1\\}\\([^\"]*\\)\".*/\\1/p" "$1" | head -n1
}

bg=$(json_field "$theme_json" background)
fg=$(json_field "$theme_json" foreground)
bright=$(json_field "$theme_json" brightForeground)
accent=$(json_field "$theme_json" accent)
accent2=$(json_field "$theme_json" borderActive2)
muted=$(json_field "$theme_json" muted)

sed \
  -e "s/__BG__/#${bg}/g" \
  -e "s/__FG__/#${fg}/g" \
  -e "s/__BRIGHT__/#${bright}/g" \
  -e "s/__ACCENT__/#${accent}/g" \
  -e "s/__ACCENT2__/#${accent2}/g" \
  -e "s/__MUTED__/#${muted}/g" \
  "$template" > "$out_dir/wallpaper.svg"

# Render to a temp file then rename - swaybg (or anything else watching this
# path) never observes a half-written PNG.
rsvg-convert -w 1920 -h 1080 "$out_dir/wallpaper.svg" -o "$out_dir/wallpaper.png.tmp"
mv "$out_dir/wallpaper.png.tmp" "$out_dir/wallpaper.png"
