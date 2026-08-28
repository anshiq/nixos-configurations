#!/usr/bin/env bash
# Drop-in replacement for `wofi --dmenu` backed by the Quickshell launcher
# (see ../Launcher.qml). Quickshell is a single long-lived process, so IPC
# calls carry arguments only, not stdin/stdout - this script bridges that:
# stdin becomes a temp file, `quickshell ipc call launcher openDmenu` tells
# the running shell to show a picker over its lines, and this script polls
# for the `<output>.done` marker Launcher.qml touches after the user picks
# (or cancels, writing an empty selection) before printing the result.
set -euo pipefail

tmp_in=$(mktemp)
tmp_out=$(mktemp)
trap 'rm -f "$tmp_in" "$tmp_out" "$tmp_out.done"' EXIT

cat > "$tmp_in"

quickshell ipc call launcher openDmenu "$tmp_in" "$tmp_out"

# The launcher is a GUI the user interacts with, so there's no fixed
# deadline for a selection - keep polling until the done marker appears.
while [ ! -f "$tmp_out.done" ]; do
  sleep 0.1
done

cat "$tmp_out"
