# screen-record toggle|start [--region] [--gif] [--audio MODE] [--output NAME] [--delay SECONDS]
#             | stop | status [--json]
#             | settings get [--json] | settings set audio|output|delay VALUE
# wf-recorder into ~/Videos/Recordings/. --region asks for an area with slurp.
# --gif records the same way, then on stop converts the clip to a GIF (12 fps,
# at most 960 px wide), copies it to the clipboard and drops the mp4. GIFs
# never have audio.
#
# Defaults for --audio/--output/--delay come from
# ~/.local/state/desktop/screen-record.json, which the Settings app writes, so
# the keybinds, the bar button and the Settings page all record the same way:
#   audio   none | mic | system | both   (default mic)
#           mic = default input, system = what the default output plays,
#           both = the two mixed (a temporary PipeWire null sink + loopbacks,
#           named screen-record-mix, removed on stop and before every start)
#   output  focused | <monitor name>     (default focused; full screen only;
#           a monitor that is not connected falls back to the focused one)
#   delay   seconds before recording starts (default 0)
#
# The running recorder is tracked by $XDG_RUNTIME_DIR/screen-record.pid (the
# output path is kept next to it in screen-record.file, the mode in
# screen-record.mode). While a countdown runs, screen-record.countdown holds
# the waiting process; toggle/stop during it cancels the recording.

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/screen-record.pid"
file_file="$runtime_dir/screen-record.file"
mode_file="$runtime_dir/screen-record.mode"
countdown_file="$runtime_dir/screen-record.countdown"
out_dir="$HOME/Videos/Recordings"
state_dir="$HOME/.local/state/desktop"
settings_file="$state_dir/screen-record.json"
mix_sink=screen-record-mix

default_audio=mic
default_output=focused
default_delay=0

usage() {
  echo "usage: screen-record toggle|start [--region] [--gif] [--audio none|mic|system|both] [--output NAME] [--delay SECONDS]" >&2
  echo "       screen-record stop | status [--json] | settings get [--json] | settings set audio|output|delay VALUE" >&2
  exit 1
}

notify() {
  notify-send -t "$1" "Screen recording" "$2" 2>/dev/null || true
}

is_audio() {
  case "$1" in
    none | mic | system | both) return 0 ;;
  esac
  return 1
}

is_seconds() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
  esac
  [ "${#1}" -le 3 ]
}

# Monitor names are things like eDP-1, HDMI-A-1, DP-2.
is_output() {
  case "$1" in
    '' | *[!A-Za-z0-9_.-]*) return 1 ;;
  esac
}

read_settings() {
  audio=$default_audio
  output=$default_output
  delay=$default_delay
  [ -f "$settings_file" ] || return 0
  local a o d
  a=$(jq -r '.audio // empty' "$settings_file" 2>/dev/null || true)
  o=$(jq -r '.output // empty' "$settings_file" 2>/dev/null || true)
  d=$(jq -r '.delay // empty' "$settings_file" 2>/dev/null || true)
  if is_audio "$a"; then audio=$a; fi
  if is_output "$o"; then output=$o; fi
  if is_seconds "$d"; then delay=$((10#$d)); fi
}

write_settings() {
  mkdir -p "$state_dir"
  jq -n --arg audio "$audio" --arg output "$output" --argjson delay "$delay" \
    '{audio: $audio, output: $output, delay: $delay}' > "$settings_file.tmp"
  mv -f "$settings_file.tmp" "$settings_file"
}

settings_json() {
  jq -cn --arg audio "$audio" --arg output "$output" --argjson delay "$delay" \
    '{audio: $audio, output: $output, delay: $delay}'
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

# The screen-record process waiting out a countdown, if any.
countdown_pid() {
  local pid
  pid=$(cat "$countdown_file" 2>/dev/null || true)
  case "$pid" in
    '' | *[!0-9]*) return 1 ;;
  esac
  if grep -qs screen-record "/proc/$pid/cmdline"; then
    echo "$pid"
    return 0
  fi
  return 1
}

cancel_countdown() {
  local pid
  pid=$(countdown_pid) || return 1
  kill -TERM "$pid" 2>/dev/null || true
  rm -f "$countdown_file"
  notify 2000 "Recording cancelled"
  return 0
}

# Remove the mix sink and its loopbacks (also leftovers from a crashed run).
# Loopbacks first, then the sink they feed.
remove_mix() {
  command -v pactl >/dev/null 2>&1 || return 0
  local id
  for id in $(pactl list short modules 2>/dev/null | awk -v s="$mix_sink" 'index($0, s) { print $1 }' | sort -rn); do
    pactl unload-module "$id" >/dev/null 2>&1 || true
  done
}

# Default input, unless there is none (or it is only a monitor of an output).
mic_source() {
  local src
  src=$(pactl get-default-source 2>/dev/null) || return 1
  case "$src" in
    '' | *.monitor) return 1 ;;
  esac
  echo "$src"
}

system_source() {
  local sink
  sink=$(pactl get-default-sink 2>/dev/null) || return 1
  [ -n "$sink" ] || return 1
  echo "$sink.monitor"
}

# Print the PulseAudio device wf-recorder should record for $1 (empty = no
# audio). Falls back to what is available and says so in a notification.
audio_device() {
  local want=$1 mic="" sys=""
  [ "$want" = none ] && return 0
  mic=$(mic_source || true)
  sys=$(system_source || true)
  case "$want" in
    mic)
      if [ -n "$mic" ]; then echo "$mic"; return 0; fi
      notify 4000 "No microphone found; recording without audio"
      ;;
    system)
      if [ -n "$sys" ]; then echo "$sys"; return 0; fi
      notify 4000 "No audio output found; recording without audio"
      ;;
    both)
      if [ -n "$mic" ] && [ -n "$sys" ]; then
        if pactl load-module module-null-sink sink_name="$mix_sink" \
          'sink_properties=device.description="Screen recording mix"' >/dev/null \
          && pactl load-module module-loopback source="$mic" sink="$mix_sink" \
            latency_msec=30 source_dont_move=true sink_dont_move=true >/dev/null \
          && pactl load-module module-loopback source="$sys" sink="$mix_sink" \
            latency_msec=30 source_dont_move=true sink_dont_move=true >/dev/null; then
          echo "$mix_sink.monitor"
          return 0
        fi
        remove_mix
        notify 4000 "Could not mix microphone and system audio; recording the microphone only"
        echo "$mic"
        return 0
      fi
      if [ -n "$mic" ]; then
        notify 4000 "No audio output found; recording the microphone only"
        echo "$mic"
      elif [ -n "$sys" ]; then
        notify 4000 "No microphone found; recording system audio only"
        echo "$sys"
      else
        notify 4000 "No audio devices found; recording without audio"
      fi
      ;;
  esac
}

# Monitor to record in full-screen mode: the chosen one if it is connected,
# otherwise the focused one.
pick_output() {
  local want=$1 monitors
  monitors=$(hyprctl monitors -j 2>/dev/null || echo '[]')
  if [ "$want" != focused ] \
    && jq -e --arg n "$want" 'any(.[]; .name == $n)' <<<"$monitors" >/dev/null 2>&1; then
    echo "$want"
    return 0
  fi
  if [ "$want" != focused ]; then
    notify 4000 "$want is not connected; recording the focused monitor"
  fi
  jq -r 'first(.[] | select(.focused) | .name) // empty' <<<"$monitors" 2>/dev/null || true
}

start() {
  recorder_pid >/dev/null && return 0
  countdown_pid >/dev/null && return 0
  read_settings
  local geometry="" file mode=video arg region=false device="" mon=""
  while [ $# -gt 0 ]; do
    arg=$1
    shift
    case "$arg" in
      --region) region=true ;;
      --gif) mode=gif ;;
      --audio | --output | --delay)
        [ $# -gt 0 ] || usage
        case "$arg" in
          --audio) is_audio "$1" || usage; audio=$1 ;;
          --output) is_output "$1" || usage; output=$1 ;;
          --delay) is_seconds "$1" || usage; delay=$((10#$1)) ;;
        esac
        shift
        ;;
      *) usage ;;
    esac
  done
  [ "$mode" = gif ] && audio=none

  # Pick the area first, then count down, so the countdown is the last thing
  # before the first frame.
  if [ "$region" = true ]; then
    geometry=$(slurp) || exit 0
  fi
  if [ "$delay" -gt 0 ]; then
    echo "$$" > "$countdown_file"
    notify $((delay * 1000)) "Recording starts in $delay s (run screen-record stop to cancel)"
    sleep "$delay"
    # Cancelled (or superseded) while waiting.
    [ "$(cat "$countdown_file" 2>/dev/null || true)" = "$$" ] || exit 0
    rm -f "$countdown_file"
  fi

  remove_mix
  device=$(audio_device "$audio")
  if [ -z "$geometry" ]; then
    mon=$(pick_output "$output")
  fi

  local -a cmd=(wf-recorder)
  if [ -n "$geometry" ]; then
    cmd+=(-g "$geometry")
  elif [ -n "$mon" ]; then
    cmd+=(-o "$mon")
  fi
  if [ -n "$device" ]; then
    cmd+=(--audio="$device")
  fi
  mkdir -p "$out_dir"
  file="$out_dir/recording-$(date +%Y-%m-%d_%H-%M-%S).mp4"
  cmd+=(-f "$file")
  "${cmd[@]}" </dev/null >/dev/null 2>&1 &
  echo "$!" > "$pid_file"
  echo "$file" > "$file_file"
  echo "$mode" > "$mode_file"
  disown

  # wf-recorder exits at once on a bad output or audio device; report that
  # instead of a recording that never happened.
  sleep 0.5
  if ! recorder_pid >/dev/null; then
    rm -f "$pid_file" "$file_file" "$mode_file" "$file"
    remove_mix
    notify 4000 "Recording failed to start"
    echo "screen-record: wf-recorder exited right away" >&2
    exit 1
  fi

  local what=""
  [ "$mode" = gif ] && what=" (GIF)"
  case "$device" in
    '') ;;
    "$mix_sink.monitor") what="$what with microphone and system audio" ;;
    *.monitor) what="$what with system audio" ;;
    *) what="$what with microphone" ;;
  esac
  notify 2000 "Recording started$what"
}

stop() {
  local pid file mode i gif
  if ! pid=$(recorder_pid); then
    cancel_countdown || true
    rm -f "$pid_file" "$file_file" "$mode_file"
    remove_mix
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
  remove_mix
  if [ "$mode" = gif ] && [ -s "$file" ]; then
    gif="${file%.mp4}.gif"
    notify 2000 "Converting to GIF..."
    if ffmpeg -loglevel error -y -i "$file" \
      -vf "fps=12,scale='min(960,iw)':-2:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
      "$gif"; then
      rm -f "$file"
      wl-copy --type image/gif < "$gif" >/dev/null 2>&1 || true
      notify 4000 "GIF saved and copied: $gif"
      return 0
    fi
    rm -f "$gif"
    notify 4000 "GIF conversion failed; kept $file"
    return 0
  fi
  notify 4000 "Saved ${file:-recording}"
}

settings_cmd() {
  read_settings
  case "${1:-}" in
    get)
      if [ "${2:-}" = --json ]; then
        settings_json
      else
        echo "audio: $audio, output: $output, delay: ${delay}s"
      fi
      ;;
    set)
      [ $# -eq 3 ] || usage
      case "$2" in
        audio) is_audio "$3" || usage; audio=$3 ;;
        output) is_output "$3" || usage; output=$3 ;;
        delay) is_seconds "$3" || usage; delay=$((10#$3)) ;;
        *) usage ;;
      esac
      write_settings
      ;;
    *) usage ;;
  esac
}

case "${1:-}" in
  toggle)
    if recorder_pid >/dev/null; then
      stop
    elif ! cancel_countdown; then
      start "${@:2}"
    fi
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
    if countdown_pid >/dev/null; then counting=true; else counting=false; fi
    if [ "${2:-}" = --json ]; then
      jq -cn --argjson recording "$recording" --argjson countdown "$counting" --arg file "$file" \
        '{recording: $recording, countdown: $countdown, file: $file}'
    else
      echo "recording: $recording${file:+ ($file)}$([ "$counting" = true ] && echo ' (countdown running)')"
    fi
    ;;
  settings) settings_cmd "${@:2}" ;;
  *) usage ;;
esac
