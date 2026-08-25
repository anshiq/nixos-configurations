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
  };

  wallpaper = ./wallpapers/tokyo-night.webp;
  terminal = "ghostty";
  browser = "chromium";
  lock = "pidof hyprlock || hyprlock";
in
{
  home.packages = with pkgs; [
    brightnessctl
    cliphist
    grim
    hypridle
    hyprlock
    hyprpicker
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
    # Config is deployed verbatim from ./ghostty/config - see xdg.configFile
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
    "ghostty/config".source = ../ghostty/config;
    "waybar/config".source = ../waybar/config;
    "waybar/style.css".source = ../waybar/style.css;
    "wofi/config".source = ../wofi/config;
    "wofi/style.css".source = ../wofi/style.css;
    "mako/config".source = ../mako/config;
  };

  # Waybar package comes from home.packages above; config/style from ./waybar/.

  # Keep the service enabled: it provides the package + systemd autostart;
  # config itself is deployed from ./mako/config via xdg.configFile above.
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
      listener = [
        {
          timeout = 600;
          on-timeout = lock;
        }
        {
          timeout = 900;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 2;
      };
      background = [
        {
          path = toString wallpaper;
          blur_passes = 2;
          blur_size = 6;
          color = "rgb(${colors.background})";
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
          font_color = "rgb(${colors.foreground})";
          inner_color = "rgb(${colors.darkBackground})";
          outer_color = "rgb(${colors.blue})";
          outline_thickness = 2;
          placeholder_text = "Password";
          shadow_passes = 0;
        }
      ];
      label = [
        {
          monitor = "";
          text = "cmd[update:1000] echo \"$(date +'%H:%M')\"";
          color = "rgb(${colors.brightForeground})";
          font_size = 72;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  xdg.enable = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "chromium-browser.desktop";
      "x-scheme-handler/http" = "chromium-browser.desktop";
      "x-scheme-handler/https" = "chromium-browser.desktop";
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
    font = {
      name = "Noto Sans";
      size = 10;
    };
  };

  # Let GUI applications find SSH/GPG credentials through the session keyring.
  services.gnome-keyring.enable = true;
}
