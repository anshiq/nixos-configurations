#!/usr/bin/env bash
# Toggles wf-recorder. SIGINT (not SIGKILL) lets it finalize the mp4
# container properly instead of leaving a corrupt file.
set -euo pipefail

out_dir="$HOME/Videos"
mkdir -p "$out_dir"

if pgrep -x wf-recorder >/dev/null; then
  pkill -INT -x wf-recorder
  notify-send "Screen recording" "Stopped"
else
  file="$out_dir/recording-$(date +%Y%m%d-%H%M%S).mp4"
  setsid -f wf-recorder -f "$file" >/dev/null 2>&1
  notify-send "Screen recording" "Started -> $file"
fi

# Ask waybar to re-run record-status.sh so the topbar icon flips immediately
# instead of waiting on wf-recorder's own startup/shutdown latency.
pkill -RTMIN+9 -x waybar 2>/dev/null || true
