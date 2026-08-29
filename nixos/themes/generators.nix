# Pure functions rendering one theme attrset (see ./default.nix) into every
# consumer's own file format. This is the one place that needs to grow if a
# future theme has to feed a new app - every existing consumer (ghostty,
# kitty, Quickshell, Hyprland borders, zellij, Helix, yazi, lazygit) goes
# through here instead of hand-duplicating hex codes in its own config file.
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

  # Full Helix `theme.toml`, staged per-theme at helix/themes/<name>.toml.
  # helix/config.toml itself always says `theme = "omarchy"`; theme-switch.sh
  # symlinks helix/themes/omarchy.toml at whichever variant is active and
  # sends Helix SIGUSR1, which reloads config (and thus re-resolves the
  # theme file) without a restart.
  toHelixTheme = t: ''
    "ui.background" = { bg = "${hex t.background}" }
    "ui.text" = "${hex t.foreground}"
    "ui.text.focus" = { fg = "${hex t.brightForeground}", modifiers = ["bold"] }
    "ui.cursor.primary" = { fg = "${hex t.background}", bg = "${hex t.cursor}" }
    "ui.cursor.match" = { fg = "${hex t.accent}", modifiers = ["underlined"] }
    "ui.selection" = { bg = "${hex t.selection}" }
    "ui.selection.primary" = { bg = "${hex t.selection}" }
    "ui.cursorline.primary" = { bg = "${hex t.selection}" }
    "ui.linenr" = { fg = "${hex t.muted}" }
    "ui.linenr.selected" = { fg = "${hex t.accent}", modifiers = ["bold"] }
    "ui.statusline" = { fg = "${hex t.foreground}", bg = "${hex t.darkBackground}" }
    "ui.statusline.inactive" = { fg = "${hex t.muted}", bg = "${hex t.darkBackground}" }
    "ui.bufferline" = { fg = "${hex t.muted}", bg = "${hex t.darkBackground}" }
    "ui.bufferline.active" = { fg = "${hex t.background}", bg = "${hex t.accent}", modifiers = ["bold"] }
    "ui.popup" = { fg = "${hex t.foreground}", bg = "${hex t.darkBackground}" }
    "ui.window" = { fg = "${hex t.muted}" }
    "ui.help" = { fg = "${hex t.foreground}", bg = "${hex t.darkBackground}" }
    "ui.menu" = { fg = "${hex t.foreground}", bg = "${hex t.darkBackground}" }
    "ui.menu.selected" = { fg = "${hex t.background}", bg = "${hex t.accent}" }
    "ui.virtual.ruler" = { bg = "${hex t.muted}" }
    "ui.virtual.whitespace" = "${hex t.muted}"
    "ui.virtual.indent-guide" = "${hex t.muted}"
    "warning" = "${hex t.yellow}"
    "error" = "${hex t.red}"
    "info" = "${hex t.blue}"
    "hint" = "${hex t.cyan}"
    "diagnostic.error" = { underline = { color = "${hex t.red}", style = "curl" } }
    "diagnostic.warning" = { underline = { color = "${hex t.yellow}", style = "curl" } }
    "diagnostic.info" = { underline = { color = "${hex t.blue}", style = "curl" } }
    "diagnostic.hint" = { underline = { color = "${hex t.cyan}", style = "curl" } }
    "keyword" = "${hex t.magenta}"
    "keyword.control" = "${hex t.magenta}"
    "function" = "${hex t.blue}"
    "function.builtin" = "${hex t.blue}"
    "function.macro" = "${hex t.cyan}"
    "string" = "${hex t.green}"
    "string.special" = "${hex t.cyan}"
    "comment" = { fg = "${hex t.muted}", modifiers = ["italic"] }
    "constant" = "${hex t.accent}"
    "constant.numeric" = "${hex t.accent}"
    "constant.builtin" = "${hex t.accent}"
    "variable" = "${hex t.foreground}"
    "variable.parameter" = "${hex t.foreground}"
    "variable.builtin" = "${hex t.red}"
    "variable.other.member" = "${hex t.foreground}"
    "type" = "${hex t.cyan}"
    "type.builtin" = "${hex t.cyan}"
    "attribute" = "${hex t.yellow}"
    "tag" = "${hex t.red}"
    "namespace" = "${hex t.cyan}"
    "operator" = "${hex t.foreground}"
    "punctuation" = "${hex t.muted}"
    "punctuation.bracket" = "${hex t.foreground}"
    "punctuation.delimiter" = "${hex t.foreground}"
    "markup.heading" = { fg = "${hex t.blue}", modifiers = ["bold"] }
    "markup.bold" = { modifiers = ["bold"] }
    "markup.italic" = { modifiers = ["italic"] }
    "markup.link.url" = { fg = "${hex t.cyan}", modifiers = ["underlined"] }
    "markup.raw" = "${hex t.green}"
    "diff.plus" = "${hex t.green}"
    "diff.minus" = "${hex t.red}"
    "diff.delta" = "${hex t.yellow}"
  '';

  # yazi's theme.toml, staged per-theme at yazi/theme-<name>.toml.
  # theme-switch.sh symlinks yazi/theme.toml at whichever variant is
  # active (yazi has no reload signal, so this takes effect on next launch).
  toYaziTheme = t: ''
    [manager]
    cwd = { fg = "${hex t.blue}" }
    hovered = { fg = "${hex t.background}", bg = "${hex t.accent}" }
    preview_hovered = { underline = true }
    find_keyword = { fg = "${hex t.accent}", bold = true, italic = true }
    find_position = { fg = "${hex t.yellow}", bg = "reset", bold = true, italic = true }
    marker_selected = { fg = "${hex t.green}", bg = "${hex t.selection}" }
    marker_copied = { fg = "${hex t.yellow}", bg = "${hex t.selection}" }
    marker_cut = { fg = "${hex t.red}", bg = "${hex t.selection}" }
    marker_marked = { fg = "${hex t.accent}", bg = "${hex t.selection}" }
    border_symbol = "│"
    border_style = { fg = "${hex t.muted}" }

    [status]
    separator_open  = ""
    separator_close = ""
    separator_style = { fg = "${hex t.muted}", bg = "${hex t.muted}" }
    mode_normal = { fg = "${hex t.background}", bg = "${hex t.accent}", bold = true }
    mode_select = { fg = "${hex t.background}", bg = "${hex t.green}", bold = true }
    mode_unset = { fg = "${hex t.background}", bg = "${hex t.yellow}", bold = true }
    progress_label = { fg = "${hex t.foreground}" }
    progress_normal = { fg = "${hex t.accent}", bg = "${hex t.muted}" }
    progress_error = { fg = "${hex t.red}", bg = "${hex t.muted}" }
    permissions_t = { fg = "${hex t.green}" }
    permissions_r = { fg = "${hex t.yellow}" }
    permissions_w = { fg = "${hex t.red}" }
    permissions_x = { fg = "${hex t.cyan}" }
    permissions_s = { fg = "${hex t.muted}" }

    [tabs]
    active = { fg = "${hex t.background}", bg = "${hex t.accent}", bold = true }
    inactive = { fg = "${hex t.muted}", bg = "${hex t.darkBackground}" }

    # yazi ships its own built-in filetype rules (directories hardcoded to
    # literal "blue", regardless of any [manager]/[status] overrides above)
    # - these override that default with the active theme's own colors, so
    # e.g. mono's folders come out gray and sunset-night's come out orange
    # instead of every theme showing yazi's baked-in blue.
    [filetype]
    rules = [
      { url = "*/", fg = "${hex t.blue}" },
      { url = "*", is = "orphan", fg = "${hex t.red}" },
      { url = "*", is = "exec", fg = "${hex t.green}" },
      { mime = "image/*", fg = "${hex t.yellow}" },
      { mime = "{audio,video}/*", fg = "${hex t.magenta}" },
      { mime = "application/{zip,gzip,x-tar,x-bzip2,x-7z-compressed,x-rar}", fg = "${hex t.red}" },
      { mime = "inode/empty", fg = "${hex t.muted}" },
    ]
  '';

  # lazygit's `gui.theme` block, staged per-theme at lazygit/config-<name>.yml.
  # theme-switch.sh symlinks lazygit/config.yml at whichever variant is
  # active (lazygit has no reload signal, but it's a short-lived subprocess
  # launched fresh each time, so this is a non-issue in practice).
  toLazygitTheme = t: ''
    gui:
      theme:
        activeBorderColor:
          - "${hex t.accent}"
          - bold
        inactiveBorderColor:
          - "${hex t.muted}"
        searchingActiveBorderColor:
          - "${hex t.yellow}"
          - bold
        optionsTextColor:
          - "${hex t.accent}"
        selectedLineBgColor:
          - "${hex t.selection}"
        selectedRangeBgColor:
          - "${hex t.selection}"
        cherryPickedCommitBgColor:
          - "${hex t.muted}"
        cherryPickedCommitFgColor:
          - "${hex t.accent}"
        unstagedChangesColor:
          - "${hex t.red}"
        defaultFgColor:
          - "${hex t.foreground}"
  '';
}
