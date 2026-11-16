# screenshot: drag a region (the screen freezes while you pick, across all
# monitors), then annotate it in satty. In satty: Enter copies to the clipboard,
# the save button writes ~/Pictures/<date>.png, Esc cancels. The window opens on
# the monitor you are on, so there is no monitor picker like flameshot's.
dir="${XDG_RUNTIME_DIR:-/tmp}/screenshots"
mkdir -p "$dir"
file="$dir/shot-$(date +%s%N).png"
trap 'rm -f "$file"' EXIT

freeze_region "$file" || exit 0

# SATTY_OUT: set to a directory to save somewhere other than ~/Pictures.
satty --filename "$file" \
  --output-filename "${SATTY_OUT:-$HOME/Pictures}/%Y-%m-%d_%H-%M-%S.png" \
  --copy-command wl-copy \
  --actions-on-enter save-to-clipboard \
  --actions-on-escape exit \
  --early-exit all \
  --fullscreen current-screen \
  --initial-tool arrow || true
