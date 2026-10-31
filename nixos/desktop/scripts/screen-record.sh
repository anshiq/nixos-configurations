# screen-record toggle|start [--region] [--gif] | stop | status [--json]
# wf-recorder into ~/Videos/Recordings/. --region asks for an area with slurp.
# --gif records the same way, then on stop converts the clip to a GIF (12 fps,
# at most 960 px wide), copies it to the clipboard and drops the mp4.
# The running recorder is tracked by $XDG_RUNTIME_DIR/screen-record.pid (the
# output path is kept next to it in screen-record.file, the mode in
# screen-record.mode).

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/screen-record.pid"
file_file="$runtime_dir/screen-record.file"
mode_file="$runtime_dir/screen-record.mode"
out_dir="$HOME/Videos/Recordings"

usage() {
  echo "usage: screen-record toggle|start [--region] [--gif] | stop | status [--json]" >&2
  exit 1
}

recorder_pid() {
  local pid
  pid=$(cat "$pid_file" 2>/dev/null || true)
  case "$pid" in
    '' | *[!0-9]*) return 1 ;;
  esac
  if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = wf-recorder ] \
    || grep -qs wf-recorder "/proc/$pid/cmdline"; then
    echo "$pid"
    return 0
  fi
  return 1
}

start() {
  recorder_pid >/dev/null && return 0
  local geometry="" file mode=video arg
  for arg in "$@"; do
    case "$arg" in
      --region) geometry=$(slurp) || exit 0 ;;
      --gif) mode=gif ;;
      *) usage ;;
    esac
  done
  mkdir -p "$out_dir"
  file="$out_dir/recording-$(date +%Y-%m-%d_%H-%M-%S).mp4"
  if [ -n "$geometry" ]; then
    wf-recorder -g "$geometry" -f "$file" </dev/null >/dev/null 2>&1 &
  else
    wf-recorder -f "$file" </dev/null >/dev/null 2>&1 &
  fi
  echo "$!" > "$pid_file"
  echo "$file" > "$file_file"
  echo "$mode" > "$mode_file"
  disown
  notify-send -t 2000 "Screen recording" "Recording started$([ "$mode" = gif ] && echo ' (GIF)')" 2>/dev/null || true
}

stop() {
  local pid file mode i gif
  if ! pid=$(recorder_pid); then
    rm -f "$pid_file" "$file_file" "$mode_file"
    return 0
  fi
  file=$(cat "$file_file" 2>/dev/null || true)
  mode=$(cat "$mode_file" 2>/dev/null || echo video)
  # SIGINT lets wf-recorder finalize the file; wait for it (bounded).
  kill -INT "$pid" 2>/dev/null || true
  for i in $(seq 50); do
    kill -0 "$pid" 2>/dev/null || break
    [ "$i" -eq 50 ] && kill -TERM "$pid" 2>/dev/null
    sleep 0.1
  done
  rm -f "$pid_file" "$file_file" "$mode_file"
  if [ "$mode" = gif ] && [ -s "$file" ]; then
    gif="${file%.mp4}.gif"
    notify-send -t 2000 "Screen recording" "Converting to GIF..." 2>/dev/null || true
    if ffmpeg -loglevel error -y -i "$file" \
      -vf "fps=12,scale='min(960,iw)':-2:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
      "$gif"; then
      rm -f "$file"
      wl-copy --type image/gif < "$gif" >/dev/null 2>&1 || true
      notify-send -t 4000 "Screen recording" "GIF saved and copied: $gif" 2>/dev/null || true
      return 0
    fi
    rm -f "$gif"
    notify-send -t 4000 "Screen recording" "GIF conversion failed; kept $file" 2>/dev/null || true
    return 0
  fi
  notify-send -t 4000 "Screen recording" "Saved ${file:-recording}" 2>/dev/null || true
}

case "${1:-}" in
  toggle)
    if recorder_pid >/dev/null; then stop; else start "${@:2}"; fi
    ;;
  start) start "${@:2}" ;;
  stop) stop ;;
  status)
    if recorder_pid >/dev/null; then
      recording=true
      file=$(cat "$file_file" 2>/dev/null || true)
    else
      recording=false
      file=""
    fi
    if [ "${2:-}" = --json ]; then
      jq -cn --argjson recording "$recording" --arg file "$file" '{recording: $recording, file: $file}'
    else
      echo "recording: $recording${file:+ ($file)}"
    fi
    ;;
  *) usage ;;
esac
