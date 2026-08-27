#!/usr/bin/env bash
# Reports wf-recorder's state as waybar custom-module JSON, polled on
# RTMIN+9 signal (see record-toggle.sh).
if pgrep -x wf-recorder >/dev/null; then
  echo '{"text":"󰑊","alt":"on","class":"active","tooltip":"Recording - click to stop"}'
else
  echo '{"text":"󰻂","alt":"off","class":"inactive","tooltip":"Click to start screen recording"}'
fi
