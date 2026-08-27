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
  lock = "pidof hyprlock || hyprlock";

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
    grim
    hypridle
    hyprlock
    hyprpicker
    hyprsunset
    libnotify
    pamixer
    playerctl
    slurp
    swaybg
    waybar
    wl-clipboard
    wofi
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
    "waybar/config".source = ../waybar/config;
    # style.css, ghostty/config, kitty/kitty.conf, wofi/style.css,
    # mako/config, and hypr/hyprlock.conf are NOT managed here: each is a
    # runtime symlink flipped between its day/night variant below by
    # theme-switch.sh, so home-manager activation doesn't fight the
    # day/night switcher while the session is running.
    "waybar/style-day.css".source = ../waybar/style-day.css;
    "waybar/style-night.css".source = ../waybar/style-night.css;
    "ghostty/config-day".source = ../ghostty/config-day;
    "ghostty/config-night".source = ../ghostty/config-night;
    "kitty/kitty-day.conf".source = ../kitty/kitty-day.conf;
    "kitty/kitty-night.conf".source = ../kitty/kitty-night.conf;
    "wofi/style-day.css".source = ../wofi/style-day.css;
    "wofi/style-night.css".source = ../wofi/style-night.css;
    "mako/config-day".source = ../mako/config-day;
    "mako/config-night".source = ../mako/config-night;
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
    # Deployed to a stable path so hyprland.lua (verbatim, untemplated) can
    # point swaybg at it without a Nix store path baked into the Lua file.
    "wallpapers/wallpaper.png".source = wallpaper;
    "wofi/config".source = ../wofi/config;
  };

  # Waybar package comes from home.packages above; config/style from ./waybar/.

  # Keep the service enabled: it provides the package + systemd autostart;
  # config itself is a runtime symlink to ./mako/config-{day,night} (see
  # xdg.configFile above), flipped by theme-switch.sh.
  services.mako.enable = true;
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = lock;
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };
      # dpms-off and suspend go through idle-unless-charging.sh, which is a
      # no-op while on AC power - the screen stays lit and the system stays
      # awake as long as the charger is connected. Locking (600s) is
      # unaffected: it fires on charge or battery, same as always.
      listener = [
        {
          timeout = 600;
          on-timeout = lock;
        }
        {
          timeout = 900;
          on-timeout = "${config.xdg.configHome}/waybar/scripts/idle-unless-charging.sh hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "${config.xdg.configHome}/waybar/scripts/idle-unless-charging.sh systemctl suspend";
        }
      ];
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

  # Day theme 06:00-17:00, sunset/night theme the rest of the time - applies
  # to waybar, ghostty, kitty, wofi, mako, hyprlock, and Hyprland's own
  # border colors (see waybar/scripts/theme-switch.sh). Also run once at
  # login (see hypr/hyprland.lua autostart) so everything starts on the
  # right theme without waiting for the first timer tick.
  systemd.user.services.waybar-theme-switch = {
    Unit.Description = "Switch the whole desktop between day and sunset themes";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.config/waybar/scripts/theme-switch.sh";
    };
  };

  systemd.user.timers.waybar-theme-switch = {
    Unit.Description = "Trigger the waybar day/sunset theme switch at 06:00 and 17:00";
    Timer = {
      OnCalendar = [
        "*-*-* 06:00:00"
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
