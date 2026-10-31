# render-wallpaper <theme.json>
# Fills the __TOKEN__ placeholders of the wallpaper SVG template ($template,
# set by Nix) with the theme's colors and renders
# ~/.local/state/desktop/wallpaper.png, atomically.

theme_json="${1:?usage: render-wallpaper <theme.json>}"
out_dir="$HOME/.local/state/desktop"
mkdir -p "$out_dir"

color() {
  jq -r --arg k "$1" '.[$k] // "#000000"' "$theme_json"
}

tmp_svg=$(mktemp "$out_dir/.wallpaper.XXXXXX.svg")
trap 'rm -f "$tmp_svg" "$out_dir/.wallpaper.png.tmp"' EXIT

sed \
  -e "s/__BG__/$(color background)/g" \
  -e "s/__FG__/$(color foreground)/g" \
  -e "s/__BRIGHT__/$(color brightForeground)/g" \
  -e "s/__ACCENT__/$(color accent)/g" \
  -e "s/__ACCENT2__/$(color borderActive2)/g" \
  -e "s/__MUTED__/$(color muted)/g" \
  "$template" > "$tmp_svg"

rsvg-convert -w 1920 -h 1080 "$tmp_svg" -o "$out_dir/.wallpaper.png.tmp"
mv -f "$out_dir/.wallpaper.png.tmp" "$out_dir/wallpaper.png"
