# screen-record toggle [--region] | start [--region] | stop | status [--json]
# wf-recorder into ~/Videos/Recordings/. --region asks for an area with slurp.
# The running recorder is tracked by $XDG_RUNTIME_DIR/screen-record.pid (the
# output path is kept next to it in screen-record.file).

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/screen-record.pid"
file_file="$runtime_dir/screen-record.file"
out_dir="$HOME/Videos/Recordings"

usage() {
  echo "usage: screen-record toggle [--region] | start [--region] | stop | status [--json]" >&2
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
  local geometry="" file
  if [ "${1:-}" = --region ]; then
    geometry=$(slurp) || exit 0
  fi
  mkdir -p "$out_dir"
  file="$out_dir/recording-$(date +%Y-%m-%d_%H-%M-%S).mp4"
  if [ -n "$geometry" ]; then
    wf-recorder -g "$geometry" -f "$file" </dev/null >/dev/null 2>&1 &
  else
    wf-recorder -f "$file" </dev/null >/dev/null 2>&1 &
  fi
  echo "$!" > "$pid_file"
  echo "$file" > "$file_file"
  disown
  notify-send -t 2000 "Screen recording" "Recording started" 2>/dev/null || true
}

stop() {
  local pid file i
  if ! pid=$(recorder_pid); then
    rm -f "$pid_file" "$file_file"
    return 0
  fi
  file=$(cat "$file_file" 2>/dev/null || true)
  # SIGINT lets wf-recorder finalize the file; wait for it (bounded).
  kill -INT "$pid" 2>/dev/null || true
  for i in $(seq 50); do
    kill -0 "$pid" 2>/dev/null || break
    [ "$i" -eq 50 ] && kill -TERM "$pid" 2>/dev/null
    sleep 0.1
  done
  rm -f "$pid_file" "$file_file"
  notify-send -t 4000 "Screen recording" "Saved ${file:-recording}" 2>/dev/null || true
}

case "${1:-}" in
  toggle)
    if recorder_pid >/dev/null; then stop; else start "${2:-}"; fi
    ;;
  start) start "${2:-}" ;;
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
