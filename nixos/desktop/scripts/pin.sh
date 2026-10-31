# pin [--clipboard]
# Drag a region (the screen freezes while you pick) and leave it as a floating,
# always-on-top window to refer to while you work. --clipboard pins the image
# currently on the clipboard instead. Close it with Super+Q (or q in the
# window); the Hyprland rule for the `pinned-shot` app id floats and pins it.

dir="${XDG_RUNTIME_DIR:-/tmp}/pins"
mkdir -p "$dir"
file="$dir/pin-$(date +%s%N).png"
trap 'rm -f "$file"' EXIT

if [ "${1:-}" = --clipboard ]; then
  if ! wl-paste --type image/png > "$file" 2>/dev/null || [ ! -s "$file" ]; then
    notify-send -t 3000 "Pin" "No image on the clipboard" 2>/dev/null || true
    exit 1
  fi
else
  freeze_region "$file" || exit 0
fi

mpv --really-quiet --no-config --force-window=yes \
  --wayland-app-id=pinned-shot --title=Pinned \
  --image-display-duration=inf --keep-open=yes --no-osc \
  --autofit-larger=60%x60% --no-border "$file" || true
