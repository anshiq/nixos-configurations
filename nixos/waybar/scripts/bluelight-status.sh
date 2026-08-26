#!/usr/bin/env bash
# Reports hyprsunset's state as waybar custom-module JSON.
set -euo pipefail

if pgrep -x hyprsunset >/dev/null; then
  echo '{"text":"☀","alt":"on","class":"active","tooltip":"Blue light filter: on (click to turn off)"}'
else
  echo '{"text":"☾","alt":"off","class":"inactive","tooltip":"Blue light filter: off (click to turn on)"}'
fi
