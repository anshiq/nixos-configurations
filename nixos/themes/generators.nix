# Pure functions rendering one theme attrset (see ./default.nix) into every
# consumer's own file format. This is the one place that needs to grow if a
# future theme has to feed a new app - every existing consumer (ghostty,
# kitty, Quickshell, Hyprland borders, zellij) goes through here instead of
# hand-duplicating hex codes in its own config file.
{ lib }:
let
  hex = c: "#${c}";
  rgba = c: alpha: "rgba(${c}${alpha})";

  paletteLines = t: [
    "palette = 0=${hex t.background}"
    "palette = 1=${hex t.red}"
    "palette = 2=${hex t.green}"
    "palette = 3=${hex t.yellow}"
    "palette = 4=${hex t.blue}"
    "palette = 5=${hex t.magenta}"
    "palette = 6=${hex t.cyan}"
    "palette = 7=${hex t.foreground}"
    "palette = 8=${hex t.muted}"
    "palette = 9=${hex t.brightRed}"
    "palette = 10=${hex t.brightGreen}"
    "palette = 11=${hex t.brightYellow}"
    "palette = 12=${hex t.brightBlue}"
    "palette = 13=${hex t.brightMagenta}"
    "palette = 14=${hex t.brightCyan}"
    "palette = 15=${hex t.brightForeground}"
  ];

  paletteColorLines = t: [
    "color0  ${hex t.background}"
    "color1  ${hex t.red}"
    "color2  ${hex t.green}"
    "color3  ${hex t.yellow}"
    "color4  ${hex t.blue}"
    "color5  ${hex t.magenta}"
    "color6  ${hex t.cyan}"
    "color7  ${hex t.foreground}"
    "color8  ${hex t.muted}"
    "color9  ${hex t.brightRed}"
    "color10 ${hex t.brightGreen}"
    "color11 ${hex t.brightYellow}"
    "color12 ${hex t.brightBlue}"
    "color13 ${hex t.brightMagenta}"
    "color14 ${hex t.brightCyan}"
    "color15 ${hex t.brightForeground}"
  ];
in
{
  toGhosttyConfig = t: ''
    async-backend = epoll
    background = ${hex t.background}
    confirm-close-surface = false
    cursor-color = ${hex t.cursor}
    cursor-style = block
    cursor-style-blink = false
    # "monospace" (not a literal family name) so `omarchy font set` - which
    # writes a fontconfig alias for the generic family, see nixos/scripts/omarchy
    # - can repoint every app at once without a rebuild. Restart ghostty
    # (SIGUSR2, already sent by theme-switch.sh) to pick up a changed alias.
    font-family = monospace
    font-size = 10
    font-style = Regular
    foreground = ${hex t.foreground}
    keybind = shift+insert=paste_from_clipboard
    keybind = control+insert=copy_to_clipboard
    keybind = shift+enter=csi:13;2u
    mouse-scroll-multiplier = 0.950000
    ${lib.concatStringsSep "\n" (paletteLines t)}
    resize-overlay = never
    selection-background = ${hex t.selection}
    selection-foreground = ${hex t.selectionForeground}
    shell-integration-features = no-cursor,ssh-env
    window-padding-x = 0
    window-padding-y = 0
    window-theme = ghostty
  '';

  toKittyConfig = t: ''
    # "monospace" generic family, same reasoning as toGhosttyConfig above.
    font_family      monospace
    font_size        10.0

    cursor_shape            block
    cursor_blink_interval   0
    confirm_os_window_close 0
    window_padding_width    0
    wheel_scroll_multiplier 0.95

    background            ${hex t.background}
    foreground             ${hex t.foreground}
    cursor                 ${hex t.cursor}
    selection_background   ${hex t.selection}
    selection_foreground   ${hex t.selectionForeground}

    ${lib.concatStringsSep "\n" (paletteColorLines t)}
  '';

  # Matches quickshell/Colors.qml's applyTheme() field set exactly, plus the
  # three border fields it silently ignores (extra JSON keys are harmless) -
  # theme-switch.sh reads those back out for its `hyprctl eval` border
  # update instead of hardcoding them a second time.
  toQuickshellTheme = t: {
    mode = t.kind;
    background = hex t.background;
    foreground = hex t.foreground;
    brightForeground = hex t.brightForeground;
    muted = hex t.muted;
    selection = hex t.selection;
    red = hex t.red;
    green = hex t.green;
    yellow = hex t.yellow;
    blue = hex t.blue;
    magenta = hex t.magenta;
    cyan = hex t.cyan;
    accent = hex t.accent;
    borderActive1 = hex t.borderActive1;
    borderActive2 = hex t.borderActive2;
    borderInactive = hex t.borderInactive;
  };

  # Lua module theme-switch.sh symlinks to hypr/colors.lua; hyprland.lua
  # `dofile`s whatever that currently points at (see hypr/hyprland.lua) so
  # the static border config always matches the active theme, even across a
  # plain `hyprctl reload` that never runs theme-switch.sh.
  toHyprColorsLua = t: ''
    return {
      active = { colors = { "${rgba t.borderActive1 "ee"}", "${rgba t.borderActive2 "ee"}" }, angle = 45 },
      inactive = "${rgba t.borderInactive "aa"}",
    }
  '';

  toZellijTheme = t: {
    fg = hex t.foreground;
    bg = hex t.background;
    black = hex t.muted;
    red = hex t.red;
    green = hex t.green;
    yellow = hex t.yellow;
    blue = hex t.blue;
    magenta = hex t.magenta;
    cyan = hex t.cyan;
    white = hex t.brightForeground;
    orange = hex t.accent;
  };
}
