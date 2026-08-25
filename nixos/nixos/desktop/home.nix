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
  menu = "wofi --show drun --allow-images";
  lock = "pidof hyprlock || hyprlock";
  screenshot = "grim -g \"$(slurp)\" - | wl-copy";

  workspaceBinds = builtins.concatLists (
    builtins.genList (
      i:
      let
        workspace = i + 1;
      in
      [
        "SUPER, ${toString workspace}, workspace, ${toString workspace}"
        "SUPER SHIFT, ${toString workspace}, movetoworkspace, ${toString workspace}"
      ]
    ) 9
  );
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
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-style = "Regular";
      font-size = 10;
      window-padding-x = 14;
      window-padding-y = 14;
      window-theme = "ghostty";
      confirm-close-surface = false;
      resize-overlay = "never";
      cursor-style = "block";
      cursor-style-blink = false;
      shell-integration-features = "no-cursor,ssh-env";
      mouse-scroll-multiplier = 0.95;
      async-backend = "epoll";
      background = "#${colors.background}";
      foreground = "#${colors.foreground}";
      cursor-color = "#${colors.brightForeground}";
      selection-background = "#${colors.selection}";
      selection-foreground = "#${colors.brightForeground}";
      palette = [
        "0=#${colors.background}"
        "1=#${colors.red}"
        "2=#${colors.green}"
        "3=#${colors.yellow}"
        "4=#${colors.blue}"
        "5=#${colors.magenta}"
        "6=#${colors.cyan}"
        "7=#${colors.foreground}"
        "8=#${colors.muted}"
        "9=#ff7a93"
        "10=#b9f27c"
        "11=#ff9e64"
        "12=#7da6ff"
        "13=#${colors.magenta}"
        "14=#0db9d7"
        "15=#${colors.brightForeground}"
      ];
      # Ctrl-letter combinations remain available to Fish/Zellij/TUIs.
      keybind = [
        "shift+insert=paste_from_clipboard"
        "control+insert=copy_to_clipboard"
        "shift+enter=csi:13;2u"
      ];
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false; # UWSM owns the session lifecycle.
    xwayland.enable = true;
    settings = {
      "mod" = "SUPER";
      "terminal" = terminal;
      "browser" = browser;
      "menu" = menu;

      monitor = ",preferred,auto,auto";

      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      exec-once = [
        "waybar"
        "mako"
        "nm-applet --indicator"
        "swaybg -i ${wallpaper} -m fill"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      input = {
        kb_layout = "us";
        kb_options = "compose:caps,shift:both_capslock_cancel";
        follow_mouse = 1;
        sensitivity = 0;
        repeat_rate = 40;
        repeat_delay = 250;
        numlock_by_default = true;
        touchpad = {
          natural_scroll = false;
          clickfinger_behavior = true;
          scroll_factor = 0.4;
        };
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(${colors.blue}ee) rgba(${colors.magenta}ee) 45deg";
        "col.inactive_border" = "rgba(${colors.muted}aa)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 0;
        shadow = {
          enabled = false;
        };
        blur = {
          enabled = false;
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "easeOutQuint, 0.23, 1, 0.32, 1"
          "almostLinear, 0.5, 0.5, 0.75, 1.0"
          "quick, 0.15, 0, 0.1, 1"
        ];
        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 3.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, default, popin 87%"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "workspaces, 0, 0, default"
        ];
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
        pseudotile = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        focus_on_activate = true;
        allow_session_lock_restore = true;
      };

      cursor = {
        hide_on_key_press = true;
      };

      bind = [
        "$mod, RETURN, exec, $terminal"
        "$mod SHIFT, RETURN, exec, $browser"
        "$mod SHIFT, B, exec, $browser"
        "$mod, SPACE, exec, $menu"
        "$mod, Q, killactive"
        "$mod, W, killactive"
        "$mod, F, fullscreen, 0"
        "$mod ALT, F, fullscreen, 1"
        "$mod, T, togglefloating"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"
        "$mod, G, togglegroup"
        "$mod, LEFT, movefocus, l"
        "$mod, RIGHT, movefocus, r"
        "$mod, UP, movefocus, u"
        "$mod, DOWN, movefocus, d"
        "$mod SHIFT, LEFT, swapwindow, l"
        "$mod SHIFT, RIGHT, swapwindow, r"
        "$mod SHIFT, UP, swapwindow, u"
        "$mod SHIFT, DOWN, swapwindow, d"
        "$mod, TAB, workspace, e+1"
        "$mod SHIFT, TAB, workspace, e-1"
        "$mod, S, togglespecialworkspace, scratchpad"
        "$mod ALT, S, movetoworkspacesilent, special:scratchpad"
        "$mod CTRL, L, exec, ${lock}"
        ", PRINT, exec, ${screenshot}"
        "$mod, PRINT, exec, hyprpicker -a"
        "$mod, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"
        ", XF86AudioMute, exec, pamixer --toggle-mute"
        ", XF86AudioMicMute, exec, pamixer --default-source --toggle-mute"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ]
      ++ workspaceBinds;

      binde = [
        ", XF86AudioRaiseVolume, exec, pamixer --increase 5"
        ", XF86AudioLowerVolume, exec, pamixer --decrease 5"
        ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      gestures = [
        "3, horizontal, workspace"
      ];

      windowrule = [
        "match:class ^(org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor)$, float on"
        "match:class ^(org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor)$, center on"
        "match:title ^(Picture.?in.?[Pp]icture)$, float on"
        "match:title ^(Picture.?in.?[Pp]icture)$, pin on"
        "match:title ^(Picture.?in.?[Pp]icture)$, keep_aspect_ratio on"
        "match:class ^(chromium|google-chrome)$, tile on"
        "match:class ^(com.mitchellh.ghostty)$, scroll_touchpad on 0.2"
      ];
    };
  };

  programs.waybar = {
    enable = true;
    systemd.enable = false;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 8;
      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "network"
        "pulseaudio"
        "cpu"
        "memory"
        "battery"
      ];
      "hyprland/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
        format = "{icon}";
        format-icons = {
          active = "";
          default = "";
          urgent = "";
        };
      };
      "hyprland/window" = {
        max-length = 60;
        separate-outputs = true;
      };
      clock = {
        format = "  {:%a %d %b  %H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };
      network = {
        format-wifi = "  {essid}";
        format-ethernet = "󰈀  {ifname}";
        format-disconnected = "󰖪  offline";
        tooltip-format = "{ifname}: {ipaddr}";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 muted";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "pamixer --toggle-mute";
      };
      cpu = {
        format = "  {usage}%";
        interval = 5;
      };
      memory.format = "  {}%";
      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = [
          "󰁺"
          "󰁻"
          "󰁽"
          "󰁿"
          "󰂁"
          "󰁹"
        ];
      };
      tray.spacing = 8;
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 12px;
        min-height: 0;
      }
      window#waybar {
        background: #${colors.background};
        color: #${colors.foreground};
        border-bottom: 2px solid #${colors.muted};
      }
      #workspaces button {
        padding: 0 7px;
        color: #${colors.muted};
        background: transparent;
      }
      #workspaces button.active { color: #${colors.blue}; }
      #workspaces button.urgent { color: #${colors.red}; }
      #window, #clock, #tray, #network, #pulseaudio, #cpu, #memory, #battery {
        padding: 0 9px;
      }
      #clock { color: #${colors.blue}; font-weight: bold; }
      #network { color: #${colors.cyan}; }
      #pulseaudio { color: #${colors.green}; }
      #cpu { color: #${colors.magenta}; }
      #memory { color: #${colors.yellow}; }
      #battery.warning { color: #${colors.yellow}; }
      #battery.critical { color: #${colors.red}; }
    '';
  };

  programs.wofi = {
    enable = true;
    settings = {
      width = 560;
      height = 420;
      location = "center";
      show = "drun";
      prompt = "Search";
      allow_images = true;
      insensitive = true;
      no_actions = true;
    };
    style = ''
      * { font-family: "JetBrainsMono Nerd Font"; font-size: 14px; }
      window { background-color: #${colors.background}; border: 2px solid #${colors.blue}; }
      #input { margin: 12px; padding: 10px; color: #${colors.foreground}; background-color: #${colors.lighterBackground}; }
      #inner-box { margin: 0 12px 12px; }
      #entry { padding: 9px; color: #${colors.foreground}; }
      #entry:selected { background-color: #${colors.selection}; color: #${colors.brightForeground}; }
    '';
  };

  services.mako = {
    enable = true;
    settings = {
      font = "JetBrainsMono Nerd Font 11";
      background-color = "#${colors.background}f2";
      text-color = "#${colors.foreground}";
      border-color = "#${colors.blue}";
      border-size = 2;
      border-radius = 0;
      default-timeout = 5000;
      width = 360;
      padding = "12";
      margin = "10";
      icons = true;
    };
  };

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
