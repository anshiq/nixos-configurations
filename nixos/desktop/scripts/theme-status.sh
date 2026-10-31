# theme-status [--json]
# Prints the active theme and its kind (day/night).

state_dir="$HOME/.local/state/desktop"
themes_dir="$HOME/.config/desktop/themes"

theme=$(cat "$state_dir/theme" 2>/dev/null || true)
kind=""
if [ -n "$theme" ] && [ -f "$themes_dir/$theme.json" ]; then
  kind=$(jq -r '.mode // ""' "$themes_dir/$theme.json")
fi

if [ "${1:-}" = --json ]; then
  jq -cn --arg theme "$theme" --arg kind "$kind" '{theme: $theme, kind: $kind}'
elif [ -n "$theme" ]; then
  echo "Theme: $theme ($kind)"
else
  echo "Theme: none applied yet (run theme-switch)"
fi
