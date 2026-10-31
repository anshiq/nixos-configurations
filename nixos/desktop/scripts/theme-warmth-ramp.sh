# theme-warmth-ramp [target]
# sunset-night's blue-light ramp: 6500K at 15:00 warming linearly to 2500K by
# 18:00, then held.
#   target   print the temperature the ramp reads right now
#   (none)   apply it, only inside the ramp window, only while a night theme is
#            active and the filter is on (run by theme-warmth-ramp.timer)

ramp_start=$((15 * 60))
ramp_end=$((18 * 60))
cool=6500
warm=2500
state_dir="$HOME/.local/state/desktop"

now=$((10#$(date +%H) * 60 + 10#$(date +%M)))

target() {
  if [ "$now" -lt "$ramp_start" ]; then
    echo "$cool"
  elif [ "$now" -ge "$ramp_end" ]; then
    echo "$warm"
  else
    echo $((cool - (now - ramp_start) * (cool - warm) / (ramp_end - ramp_start)))
  fi
}

if [ "${1:-}" = target ]; then
  target
  exit 0
fi

if [ "$now" -lt "$ramp_start" ] || [ "$now" -gt "$ramp_end" ]; then
  exit 0
fi
[ "$(theme-status --json | jq -r .kind)" = night ] || exit 0
systemctl --user --quiet is-active hyprsunset.service || exit 0

temp=$(target)
mkdir -p "$state_dir"
echo "$temp" > "$state_dir/bluelight-temp.tmp"
mv -f "$state_dir/bluelight-temp.tmp" "$state_dir/bluelight-temp"
hyprctl hyprsunset temperature "$temp" >/dev/null 2>&1 || true
