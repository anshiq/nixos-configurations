#!/usr/bin/env bash
# Switches the whole desktop to a named theme (see ../../themes/ - one Nix
# file per theme, rendered by desktop/home.nix into everything this script
# touches): ghostty, kitty, hyprlock, and Hyprland's own border colors each
# get their active config symlink repointed (border colors also get a live
# `hyprctl eval` update - no reload needed for those, see below); Quickshell
# picks up the new palette by watching theme.json (see quickshell/Colors.qml
# and the `install` call below); hyprsunset (the blue-light filter) is
# auto-started going into a "night"-kind theme and auto-stopped going into a
# "day"-kind one, at whatever warmth was last saved via the topbar scroll
# control (see bluelight-*.sh) - it can still be toggled manually via the
# topbar in between switches, but the next switch re-asserts the
# kind-appropriate on/off state.
#
# Helix, yazi, and lazygit each get their active theme file repointed too
# (same symlink-swap pattern as ghostty/kitty above): Helix's config.toml
# always says `theme = "omarchy"`, so retargeting
# helix/themes/omarchy.toml + a SIGUSR1 (Helix reloads config on that
# signal, re-resolving the theme file with it) is enough to reskin a
# running instance. yazi and lazygit have no reload signal, so their
# symlink swap takes effect on next launch - both are normally launched as
# short-lived subprocesses (from Helix's own keybinds, in lazygit's case),
# so that's a non-issue in practice.
#
# Hyprland's border colors are Lua config (hyprland.lua) that also `dofile`s
# a symlinked colors.lua at parse time (see there) - that static path keeps
# a plain `hyprctl reload` correct without this script running, while this
# script's runtime `hyprctl eval` covers the live-switch case without
# needing a reload. Hyprland 0.56 refuses `hyprctl keyword` entirely for
# non-legacy (Lua) parsers ("keyword can't work with non-legacy parsers. Use
# eval.") - `eval` runs a Lua snippet against the live config instead, so
# the border override has to go through hl.config(...).
#
# Usage: theme-switch.sh [<theme-name>|toggle|next]
#   <theme-name>  switch to that exact theme (see themes.list below)
#   toggle        flip between the current theme's "kind" (day/night) and
#                 the other kind's first theme
#   next          cycle to the next theme in themes.list
#   (no arg)      look up ~/.config/waybar/scripts/schedule.list for the
#                 theme whose time window contains right now (the systemd
#                 timer / login-autostart path) - this is what lets the
#                 desktop start on the correct theme immediately at login,
#                 without waiting for the next scheduled timer tick.
set -euo pipefail

scripts_dir="$HOME/.config/waybar/scripts"
themes_file="$scripts_dir/themes.list"
kinds_file="$scripts_dir/theme-kinds.list"
schedule_file="$scripts_dir/schedule.list"

ghostty_cfg="$HOME/.config/ghostty"
kitty_cfg="$HOME/.config/kitty"
hypr_cfg="$HOME/.config/hypr"
helix_cfg="$HOME/.config/helix"
yazi_cfg="$HOME/.config/yazi"
lazygit_cfg="$HOME/.config/lazygit"
# quickshell/ (unlike the directories above) is deployed as a single
# whole-directory xdg.configFile symlink straight into the Nix store, so
# ~/.config/quickshell itself is read-only - theme.json can't be written
# there. It lives in state dir instead; Colors.qml watches it at this path.
quickshell_cfg="$HOME/.config/quickshell"
quickshell_state="$HOME/.local/state/quickshell"
# Plain-text record of the active theme name, for anything that can't watch
# a config-file symlink itself - currently the `zellij` fish function (see
# home.nix), which reads this to launch new sessions on the right theme
# since zellij has no live theme reload of its own.
theme_state_dir="$HOME/.local/state/theme"

current_theme() {
  local current
  current=$(readlink "$ghostty_cfg/config" 2>/dev/null || true)
  echo "${current##*/config-}"
}

case "${1:-}" in
  toggle)
    current_kind=$(awk -v n="$(current_theme)" '$1==n {print $2}' "$kinds_file")
    other_kind="day"
    [ "$current_kind" = "day" ] && other_kind="night"
    mode=$(awk -v k="$other_kind" '$2==k {print $1; exit}' "$kinds_file")
    ;;
  next)
    cur="$(current_theme)"
    mode=$(awk -v cur="$cur" '
      $0==cur { found=1; next }
      found { print; exit }
    ' "$themes_file")
    [ -z "$mode" ] && mode=$(head -n1 "$themes_file")
    ;;
  "")
    now=$(date +%H:%M)
    mode=""
    while read -r t name; do
      [ -z "${t:-}" ] && continue
      if [[ "$now" > "$t" || "$now" == "$t" ]]; then
        mode="$name"
      fi
    done < "$schedule_file"
    # Before the first scheduled entry of the day (e.g. 02:00) - wrap to
    # whatever the last entry of the schedule is (e.g. last night's theme).
    [ -z "$mode" ] && mode=$(tail -n1 "$schedule_file" | awk '{print $2}')
    ;;
  *)
    if grep -qxF "$1" "$themes_file" 2>/dev/null; then
      mode="$1"
    else
      echo "usage: theme-switch.sh [<theme-name>|toggle|next]" >&2
      echo "available themes:" >&2
      sed 's/^/  /' "$themes_file" >&2
      exit 1
    fi
    ;;
esac

ln -sfn "$ghostty_cfg/config-$mode" "$ghostty_cfg/config"
ln -sfn "$kitty_cfg/kitty-$mode.conf" "$kitty_cfg/kitty.conf"
ln -sfn "$hypr_cfg/hyprlock-$mode.conf" "$hypr_cfg/hyprlock.conf"
ln -sfn "$hypr_cfg/colors-$mode.lua" "$hypr_cfg/colors.lua"
ln -sfn "$helix_cfg/themes/$mode.toml" "$helix_cfg/themes/omarchy.toml"
ln -sfn "$yazi_cfg/theme-$mode.toml" "$yazi_cfg/theme.toml"
ln -sfn "$lazygit_cfg/config-$mode.yml" "$lazygit_cfg/config.yml"

mkdir -p "$theme_state_dir"
echo "$mode" > "$theme_state_dir/current"

# Quickshell's Colors.qml watches theme.json for live changes (see
# quickshell/Colors.qml) - a real content copy rather than a symlink swap,
# since a symlink retarget doesn't reliably fire the inotify watch Quickshell
# uses to detect the change. `install` (not `cp`) deliberately: the source is
# a read-only (444) nix store file, and a plain `cp` onto a *new*
# destination inherits that source mode, leaving theme.json permanently
# unwritable (silent `set -e` abort here on every run after the first,
# breaking every switch since - border colors, hyprsunset, and the bar
# palette all live past this line). `install` always writes the given mode
# on the destination instead of inheriting the source's.
theme_json="$quickshell_cfg/theme-$mode.json"
mkdir -p "$quickshell_state"
install -m 644 "$theme_json" "$quickshell_state/theme.json"

# Symlink swaps don't touch the watched inode, so each running app needs an
# explicit nudge rather than relying on its own file-watcher to notice the
# change. hyprlock is launched fresh each time, so it just picks up the new
# symlink target on its next run - no nudge needed for it. Hyprland's Lua
# config is only re-read on `hyprctl reload`/restart, which is exactly what
# the dofile("colors.lua") in hyprland.lua is for - no nudge needed there
# either, the `hyprctl eval` below covers the live update instead. Helix
# reloads its config (and thus re-resolves omarchy.toml) on SIGUSR1; yazi
# and lazygit have no such signal (see file header) so they're left to pick
# up the new symlink on their next launch.
pkill -SIGUSR2 -x ghostty 2>/dev/null || true
pkill -SIGUSR1 -x kitty 2>/dev/null || true
pkill -SIGUSR1 -x hx 2>/dev/null || true

# Pull the border colors out of the same theme.json we just installed (see
# themes/generators.nix's toQuickshellTheme - it carries borderActive1/2/
# borderInactive alongside the fields Colors.qml itself reads) instead of
# hardcoding them a second time here.
json_field() {
  sed -n "s/.*\"$2\": *\"#\\{0,1\\}\\([^\"]*\\)\".*/\\1/p" "$1" | head -n1
}
active1=$(json_field "$theme_json" borderActive1)
active2=$(json_field "$theme_json" borderActive2)
inactive=$(json_field "$theme_json" borderInactive)
hyprctl eval "hl.config({ general = { col = { active_border = { colors = { \"rgba(${active1}ee)\", \"rgba(${active2}ee)\" }, angle = 45 }, inactive_border = \"rgba(${inactive}aa)\" } } })" >/dev/null 2>&1 || true

kind=$(awk -v n="$mode" '$1==n {print $2}' "$kinds_file")

bluelight_state="$HOME/.cache/waybar-bluelight-temp"
bluelight_default_temp=4000
mkdir -p "$(dirname "$bluelight_state")"
[ -f "$bluelight_state" ] || echo "$bluelight_default_temp" > "$bluelight_state"
bluelight_temp=$(cat "$bluelight_state")

if [ "$kind" = "night" ]; then
  if ! pgrep -x hyprsunset >/dev/null; then
    setsid -f hyprsunset -t "$bluelight_temp" >/dev/null 2>&1
    # setsid -f returns as soon as the process forks, before we know it
    # actually stayed up - give it a moment then verify, since a failed
    # launch here would otherwise be silent (stdout/stderr are discarded
    # above) until the next scheduled switch.
    sleep 0.3
    pgrep -x hyprsunset >/dev/null || notify-send "Theme switch" "hyprsunset (blue-light filter) failed to start" 2>/dev/null || true
  fi
else
  { pgrep -x hyprsunset >/dev/null && pkill -x hyprsunset; } || true
fi
