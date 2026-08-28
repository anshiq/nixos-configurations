{
  config,
  lib,
  pkgs,
  ...
}:

let
  colors = {
    background = "1a1b26";
    darkBackground = "13141c";
    lighterBackground = "24283b";
    selection = "292e42";
    muted = "414868";
    foreground = "a9b1d6";
    brightForeground = "c0caf5";
    red = "f7768e";
    green = "9ece6a";
    yellow = "e0af68";
    blue = "7aa2f7";
    magenta = "bb9af7";
    cyan = "7dcfff";
    accent = "7aa2f7"; # = blue; used by hyprlockSettings below
  };

  # Warm/sunset counterpart to `colors` above, used for the night variant of
  # hyprlock (see hyprlockSettings below) - same palette family as the
  # waybar/ghostty/kitty night themes.
  nightColors = {
    background = "1e1512";
    darkBackground = "140d09";
    foreground = "e0c2a8";
    brightForeground = "f5e3d0";
    accent = "ffb37a";
  };

  # Checked into version control (nixos/desktop/wallpapers/) - the same file
  # is used for the desktop background (swaybg), hyprlock, and the SDDM
  # greeter theme (see desktop/system.nix), so all three always match.
  wallpaper = ./wallpapers/shortcuts-latest.png;
  terminal = "ghostty";
  browser = "google-chrome-stable";

  # Builds a hyprlock settings attrset from a color set (`colors` or
  # `nightColors`). Rendered to two static confs below and flipped between
  # by theme-switch.sh at runtime, since programs.hyprlock only generates a
  # single ~/.config/hypr/hyprlock.conf from one settings block.
  hyprlockSettings = c: {
    general = {
      hide_cursor = true;
      grace = 2;
    };
    background = [
      {
        path = toString wallpaper;
        blur_passes = 2;
        blur_size = 6;
        color = "rgb(${c.background})";
      }
    ];
    input-field = [
      {
        size = "300, 52";
        position = "0, -40";
        monitor = "";
        dots_center = true;
        fade_on_empty = false;
        font_family = "JetBrainsMono Nerd Font";
        font_color = "rgb(${c.foreground})";
        inner_color = "rgb(${c.darkBackground})";
        outer_color = "rgb(${c.accent})";
        outline_thickness = 2;
        placeholder_text = "Password";
        shadow_passes = 0;
      }
    ];
    label = [
      {
        monitor = "";
        text = "cmd[update:1000] echo \"$(date +'%H:%M')\"";
        color = "rgb(${c.brightForeground})";
        font_size = 72;
        font_family = "JetBrainsMono Nerd Font";
        position = "0, 100";
        halign = "center";
        valign = "center";
      }
    ];
  };
in
{
  home.packages = with pkgs; [
    bibata-cursors
    brightnessctl
    cliphist
    flameshot
    grim
    hypridle
    hyprlock
    hyprpicker
    hyprsunset
    libnotify
    obs-studio
    pamixer
    playerctl
    quickshell
    slurp
    swaybg
    wl-clipboard
    xdg-utils
  ];

  home.sessionVariables = {
    BROWSER = browser;
    TERMINAL = terminal;
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    # Config is deployed verbatim from ./ghostty/config-{day,night} - see
    # xdg.configFile. The active ghostty/config is a runtime symlink flipped
    # by theme-switch.sh, same pattern as waybar/style.css below.
  };

  # Video/audio playback (files and streams). hwdec = "auto-safe" lets mpv
  # use DRM/Wayland hardware decode when available and fall back to
  # software decode otherwise, rather than forcing one path.
  programs.mpv = {
    enable = true;
    config = {
      hwdec = "auto-safe";
    };
  };

  # Hyprland >= 0.55 configs are Lua (hyprlang is deprecated). The module's
  # `settings` generator emits hyprlang-style options that 0.55+ rejects,
  # so the full config lives in ./hypr/hyprland.lua and is deployed
  # verbatim - same pattern as ./helix and ./yazi.
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false; # UWSM owns the session lifecycle.
    xwayland.enable = true;
  };

  # Static configs deployed verbatim from dedicated directories
  # (same pattern as ./helix and ./yazi).
  xdg.configFile = {
    "hypr/hyprland.lua".source = ../hypr/hyprland.lua;
    # Quickshell replacement for waybar/wofi/mako/hyprlock, migrated in
    # phases - see /home/nixos/.claude/plans/stateless-wishing-willow.md.
    # Bar/launcher/power menu/notifications/lock screen all have full parity
    # now (Phase 7 done - see LockScreen.qml); waybar/wofi are retired.
    # hyprlock stays installed as a manual fallback for the lock screen
    # only, not autostarted. Whole directory deployed since the QML config
    # is split across multiple files (Bar.qml, Colors.qml, per-module files).
    #
    # Deliberately an *out-of-store* symlink straight into the working tree
    # rather than `.source = ../quickshell` (the pattern every other config
    # here uses). Quickshell reloads QML from disk on the fly, so pointing at
    # the checkout makes editing a widget or writing a new plugin a
    # save-and-look loop instead of a `cp -r` + `nixos-rebuild switch` round
    # trip - which is the entire reason for the plugin system.
    #
    # It MUST be declared here rather than hand-made with `ln -s`. A hand-made
    # symlink is a file home-manager does not own, and checkLinkTargets aborts
    # the whole activation on one of those *before linking anything*, so every
    # other file under ~/.config silently stops updating while `nixos-rebuild
    # switch` still exits 0. That is exactly what happened here, and it is why
    # the theme-toggle and keybind fixes never reached the running system
    # despite being committed and built. See home-manager.backupFileExtension
    # in flake.nix for the second layer of protection.
    #
    # Trade-off to know about: the running desktop shell now depends on this
    # checkout existing at this path. Moving or deleting it leaves the session
    # with no bar/launcher/lock screen (hyprlock stays installed as the
    # documented manual fallback - see LockScreen.qml).
    "quickshell".source = config.lib.file.mkOutOfStoreSymlink "/home/nixos/myprojects/nixos-configurations/nixos/quickshell";
    # style.css, ghostty/config, kitty/kitty.conf, and hypr/hyprlock.conf are
    # NOT managed here: each is a runtime symlink flipped between its
    # day/night variant below by theme-switch.sh, so home-manager activation
    # doesn't fight the day/night switcher while the session is running.
    "ghostty/config-day".source = ../ghostty/config-day;
    "ghostty/config-night".source = ../ghostty/config-night;
    "kitty/kitty-day.conf".source = ../kitty/kitty-day.conf;
    "kitty/kitty-night.conf".source = ../kitty/kitty-night.conf;
    "hypr/hyprlock-day.conf".text = lib.hm.generators.toHyprconf {
      attrs = hyprlockSettings colors;
      importantPrefixes = [
        "$"
        "bezier"
        "monitor"
        "size"
        "source"
      ];
    };
    "hypr/hyprlock-night.conf".text = lib.hm.generators.toHyprconf {
      attrs = hyprlockSettings nightColors;
      importantPrefixes = [
        "$"
        "bezier"
        "monitor"
        "size"
        "source"
      ];
    };
    "waybar/scripts/power-menu.sh" = {
      source = ../waybar/scripts/power-menu.sh;
      executable = true;
    };
    "waybar/scripts/theme-switch.sh" = {
      source = ../waybar/scripts/theme-switch.sh;
      executable = true;
    };
    "waybar/scripts/bluelight-toggle.sh" = {
      source = ../waybar/scripts/bluelight-toggle.sh;
      executable = true;
    };
    "waybar/scripts/bluelight-status.sh" = {
      source = ../waybar/scripts/bluelight-status.sh;
      executable = true;
    };
    "waybar/scripts/bluelight-adjust.sh" = {
      source = ../waybar/scripts/bluelight-adjust.sh;
      executable = true;
    };
    "waybar/scripts/theme-status.sh" = {
      source = ../waybar/scripts/theme-status.sh;
      executable = true;
    };
    "waybar/scripts/idle-unless-charging.sh" = {
      source = ../waybar/scripts/idle-unless-charging.sh;
      executable = true;
    };
    "waybar/scripts/battery-notify.sh" = {
      source = ../waybar/scripts/battery-notify.sh;
      executable = true;
    };
    "waybar/scripts/screenshot.sh" = {
      source = ../waybar/scripts/screenshot.sh;
      executable = true;
    };
    # Deployed to a stable path so hyprland.lua (verbatim, untemplated) can
    # point swaybg at it without a Nix store path baked into the Lua file.
    "wallpapers/wallpaper.png".source = wallpaper;
  };

  # waybar/wofi removed in Phase 2/4 - Quickshell's Bar/Launcher (see
  # ../quickshell/) have full parity and reuse the scripts above directly.

  # mako removed in Phase 6 - notifications are now served by Quickshell's
  # NotificationServer (see quickshell/Notifications.qml), which registers
  # as the org.freedesktop.Notifications DBus provider itself.
  # Idle timeouts (lock/screen-off/suspend) used to be static values baked
  # into a home-manager-generated (read-only) hypridle.conf - changing them
  # meant editing this file and rebuilding. They're now runtime-configurable
  # from the power menu's settings panel (see quickshell/PowerMenu.qml), so
  # hypridle.conf itself is generated by quickshell/scripts/idle-settings.sh
  # from ~/.local/state/quickshell/idle-settings.json instead of by
  # home-manager - hence no `services.hypridle` module usage (that module
  # owns ~/.config/hypr/hypridle.conf itself, which would fight the script's
  # writes) and a hand-rolled systemd unit below instead. `generate` runs as
  # ExecStartPre so hypridle always has a config to read, even on first run
  # before any setting has been changed (falls back to the script's
  # defaults). The settings panel calls `idle-settings.sh set <mins>...`
  # directly, which rewrites the conf and restarts this unit itself.
  systemd.user.services.hypridle = {
    Unit = {
      ConditionEnvironment = "WAYLAND_DISPLAY";
      Description = "hypridle";
      After = [ config.wayland.systemd.target ];
      PartOf = [ config.wayland.systemd.target ];
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
    Service = {
      ExecStartPre = "%h/.config/quickshell/scripts/idle-settings.sh generate";
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "always";
      RestartSec = "10";
    };
  };

  # Package + PAM wiring only - no `settings` here, since that generates
  # ~/.config/hypr/hyprlock.conf directly and would collide with the
  # hyprlock-day.conf/-night.conf pair below. Those are rendered with the
  # same generator the module itself uses (see hyprlockSettings above) and
  # theme-switch.sh symlinks whichever one is active to hyprlock.conf.
  programs.hyprlock.enable = true;

  xdg.enable = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop";
      "audio/flac" = "mpv.desktop";
      "audio/x-wav" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 20;
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };
  };

  # Let GUI applications find SSH/GPG credentials through the session keyring.
  services.gnome-keyring.enable = true;

  # Day theme 05:00-17:00, sunset/night theme the rest of the time - applies
  # to ghostty, kitty, hyprlock, Quickshell (bar/launcher/notifications), and
  # Hyprland's own border colors (see waybar/scripts/theme-switch.sh). Also
  # run once at login (see hypr/hyprland.lua autostart) so everything starts
  # on the right theme without waiting for the first timer tick.
  systemd.user.services.waybar-theme-switch = {
    Unit.Description = "Switch the whole desktop between day and sunset themes";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.config/waybar/scripts/theme-switch.sh";
    };
  };

  systemd.user.timers.waybar-theme-switch = {
    Unit.Description = "Trigger the day/sunset theme switch at 05:00 and 17:00";
    Timer = {
      OnCalendar = [
        "*-*-* 05:00:00"
        "*-*-* 17:00:00"
      ];
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Polls battery capacity every minute and notifies once at 15% and again
  # at 5% while discharging (see waybar/scripts/battery-notify.sh) - the
  # script itself tracks state so each threshold only fires once per
  # discharge cycle.
  systemd.user.services.battery-notify = {
    Unit.Description = "Notify on low battery";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.xdg.configHome}/waybar/scripts/battery-notify.sh";
    };
  };

  systemd.user.timers.battery-notify = {
    Unit.Description = "Check battery level every minute";
    Timer = {
      OnBootSec = "1m";
      OnUnitActiveSec = "1m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
