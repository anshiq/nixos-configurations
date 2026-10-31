# ExecStart of hyprsunset.service: the filter at the saved temperature.

temp=$(cat "$HOME/.local/state/desktop/bluelight-temp" 2>/dev/null || true)
case "$temp" in
  '' | *[!0-9]*) temp=4000 ;;
esac
exec hyprsunset -t "$temp"
