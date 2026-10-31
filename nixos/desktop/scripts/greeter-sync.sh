# greeter-sync: publishes the active palette and lock-screen wallpaper for the
# login greeter (desktop/greeter.nix), which runs before login and cannot read
# ~/.local/state. Copies into the shared directory greeter.nix creates:
#   theme.json  <- ~/.local/state/desktop/theme.json
#   wallpaper   <- lockscreen.json's wallpaper, else ~/.config/wallpapers/wallpaper.png
# Note the copied wallpaper is readable by every local user.

dest=/var/lib/quickshell-greeter
state="$HOME/.local/state/desktop"

# Nothing to do until greeter.nix has created the directory.
if [ ! -d "$dest" ] || [ ! -w "$dest" ]; then
  exit 0
fi

# Temp file + rename so the greeter never reads a half-written file; skip
# unchanged files.
publish() {
  if ! cmp -s "$1" "$dest/$2"; then
    cp -L "$1" "$dest/.$2.tmp"
    chmod 0644 "$dest/.$2.tmp"
    mv -f "$dest/.$2.tmp" "$dest/$2"
  fi
}

if [ -r "$state/theme.json" ]; then
  publish "$state/theme.json" theme.json
fi

wallpaper=""
if [ -r "$state/lockscreen.json" ]; then
  wallpaper=$(jq -r '.wallpaper // ""' "$state/lockscreen.json" 2>/dev/null || true)
fi
if [ -z "$wallpaper" ] || [ ! -r "$wallpaper" ]; then
  wallpaper="$HOME/.config/wallpapers/wallpaper.png"
fi
if [ -r "$wallpaper" ]; then
  publish "$wallpaper" wallpaper
fi
