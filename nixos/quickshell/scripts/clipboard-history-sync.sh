#!/usr/bin/env bash
# Bridges `wl-paste --watch` (see systemd.user.services.clipboard-history in
# desktop/home.nix) into the format
# plugins/io.github.vuhuy.clipboard-manager/ClipboardHistory.js expects at
# ~/.local/state/omarchy/clipboard-history.json: a JSON array of
# {"type":"text","text":...} entries, most recent first (index 0 - see
# ClipboardHistory.js's displayRows). Real Omarchy's own omarchy.clipboard
# service writes this file natively; this system has no such service, so
# this script is the whole of its replacement. Text only - copied images
# are not recorded (see ClipboardHistory.js's "image" entry shape if that's
# ever added).
set -euo pipefail

history_dir="$HOME/.local/state/omarchy"
history_file="$history_dir/clipboard-history.json"
max_entries=200

mkdir -p "$history_dir"
[ -f "$history_file" ] || echo "[]" > "$history_file"

text="$(cat)"
[ -n "$text" ] || exit 0

tmp="$(mktemp "$history_file.XXXXXX")"
jq -c --arg text "$text" --argjson max "$max_entries" '
  ([{type: "text", text: $text}] + map(select(.text != $text)))[0:$max]
' "$history_file" > "$tmp" && mv "$tmp" "$history_file"
