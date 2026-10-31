{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Every theme's palette (../themes/) and the functions rendering one into
  # each app's config format (../themes/generators.nix). Adding a theme = add
  # one file under ../themes/; everything below iterates `themes`/`schedule`.
  themes = import ../themes;
  gen = import ../themes/generators.nix { inherit lib; };
  schedule = import ../themes/schedule.nix;

  # Desktop commands (theme-switch, bluelight, screen-record, ...).
  scripts = import ./scripts { inherit pkgs; };

  # Graphical-session services start with the UWSM session and stop with it.
  sessionTarget = config.wayland.systemd.target;
  sessionUnit = description: {
    Description = description;
    ConditionEnvironment = "WAYLAND_DISPLAY";
    After = [ sessionTarget ];
    PartOf = [ sessionTarget ];
  };

  stateDir = "${config.home.homeDirectory}/.local/state/desktop";

  papirusNoBlue =
    pkgs.runCommand "papirus-dark-no-blue"
      {
        nativeBuildInputs = [
          pkgs.papirus-folders
          pkgs.gtk3
        ];
      }
      ''
        mkdir -p $out/share/icons
        # Papirus-Dark's own folder.svg is a *symlink* into the sibling
        # Papirus (light) theme at some sizes - folders are shared between the
        # two variants, only genuinely dark-specific icons differ. Copying
        # Papirus-Dark alone leaves that symlink dangling, which makes `[ -w
        # folder.svg ]` false and sends papirus-folders down its sudo-reexec
        # path (fine interactively, fatal in this sandbox with no sudo/tty) -
        # copying both keeps every such symlink resolvable.
        cp -r ${pkgs.papirus-icon-theme}/share/icons/Papirus $out/share/icons/Papirus
        cp -r ${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark $out/share/icons/Papirus-Dark
        chmod -R u+w $out/share/icons/Papirus $out/share/icons/Papirus-Dark
        # papirus-folders takes a theme *name*, not a path - it resolves it by
        # searching $XDG_DATA_DIRS/icons/<name>/index.theme (see its
        # get_theme_dir()), so point that search at our copy instead of trying
        # to hand it $out directly.
        HOME="$TMPDIR" XDG_DATA_DIRS="$out/share" \
          papirus-folders -o -t Papirus-Dark -C white
        gtk-update-icon-cache -f -t "$out/share/icons/Papirus-Dark"
      '';

  # Static lock-screen/greeter fallback image (the desktop background is
  # rendered per theme by render-wallpaper).
  wallpaper = ./wallpapers/shortcuts-latest.png;
  terminal = "ghostty";
  browser = "google-chrome-stable";

  # Moves runtime state from the paths used before ~/.local/state/desktop.
  # Only moves when the new file is missing; never fails activation.
  migrateState = pkgs.writeShellScript "migrate-desktop-state" ''
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
      ]
    }
    state="$HOME/.local/state/desktop"
    mkdir -p "$state" || exit 0

    move() {
      if [ -e "$1" ] && [ ! -e "$2" ]; then
        mv -f "$1" "$2" || true
      fi
    }

    move "$HOME/.local/state/quickshell/theme.json" "$state/theme.json"
    move "$HOME/.local/state/quickshell/lockscreen.json" "$state/lockscreen.json"
    move "$HOME/.local/state/theme/current" "$state/theme"
    move "$HOME/.cache/waybar-bluelight-temp" "$state/bluelight-temp"
    move "$HOME/.local/state/wallpaper/wallpaper.png" "$state/wallpaper.png"

    old_idle="$HOME/.local/state/quickshell/idle-settings.json"
    if [ -e "$old_idle" ] && [ ! -e "$state/idle.json" ]; then
      if jq '{lock: (.lockMinutes // 30), dpms: (.screenOffMinutes // 32), suspend: (.suspendMinutes // 35)}' \
        "$old_idle" > "$state/idle.json.tmp" 2>/dev/null; then
        mv -f "$state/idle.json.tmp" "$state/idle.json" && rm -f "$old_idle"
      else
        rm -f "$state/idle.json.tmp"
      fi
    fi

    # helix/config.toml names the theme "current"; point it at the active one.
    helix_themes="$HOME/.config/helix/themes"
    theme=$(cat "$state/theme" 2>/dev/null || true)
    if [ -n "$theme" ] && [ ! -e "$helix_themes/current.toml" ] && [ -e "$helix_themes/$theme.toml" ]; then
      ln -sfn "$helix_themes/$theme.toml" "$helix_themes/current.toml" || true
    fi
    exit 0
  '';
in
{
  home.packages =
    (with pkgs; [
      brightnessctl
      cliphist
      flameshot
      hypridle
      hyprpicker
      hyprsunset
      libnotify
      playerctl
      quickshell
      slurp
      swaybg
      wf-recorder
      wl-clipboard
      wtype
      xdg-utils
    ])
    ++ (with scripts; [
      theme-switch
      theme-status
      bluelight
      screenshot
      screen-record
      render-wallpaper
      idle-settings
      theme-warmth-ramp
      ocr
      pin
      dnd
      screen-share
      float-terminal
    ])
    ++ (with pkgs; [
      # File-manager helpers: Thunar's "Open Terminal Here" custom action
      # (~/.config/Thunar/uca.xml) runs `exo-open`; the archive plugin's
      # Create/Extract entries need an archiver; GLib launches terminal-only
      # apps (Helix, yazi) through xdg-terminal-exec.
      xfce.exo
      file-roller
      p7zip
      xdg-terminal-exec
    ]);

  home.sessionVariables = {
    BROWSER = browser;
    TERMINAL = terminal;
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    # ghostty/config itself is a symlink theme-switch points at config-<theme>.
  };

  # hwdec = "auto-safe": hardware decode when available, software otherwise.
  programs.mpv = {
    enable = true;
    config = {
      hwdec = "auto-safe";
    };
  };

  xdg.configFile = {
    # Hyprland >= 0.55 is configured in Lua, deployed verbatim. The system
    # module (desktop/system.nix) installs Hyprland; UWSM runs the session.
    "hypr/hyprland.lua".source = ../hypr/hyprland.lua;

    # An out-of-store symlink into the checkout so Quickshell's live reload
    # picks up QML edits without a rebuild. It must be declared here: a
    # hand-made symlink is a file home-manager does not own and would block
    # activation. The shell therefore needs the checkout at /etc/nixos.
    "quickshell".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/quickshell";

    # Stock lock-screen wallpaper (LockScreen.qml, settings app, greeter-sync).
    "wallpapers/wallpaper.png".source = wallpaper;

    # theme-switch's data: one palette per theme (copied to
    # ~/.local/state/desktop/theme.json on switch) and the schedule.
    "desktop/schedule.json".text = builtins.toJSON schedule;

    # The file manager's terminal is float-terminal (see the helper and
    # desktop entry under "xdg.dataFile"/"xdg.desktopEntries" below).
    "xfce4/helpers.rc".text = "TerminalEmulator=float-terminal\n";
    "xdg-terminals.list".text = "float-terminal.desktop\n";
  }
  # Per-theme variants. The active ghostty/config, kitty/kitty.conf,
  # hypr/colors.lua, helix/themes/current.toml, yazi/theme.toml and
  # lazygit/config.yml are symlinks theme-switch repoints at runtime, so they
  # are deliberately not managed here.
  // lib.concatMapAttrs (name: theme: {
    "desktop/themes/${name}.json".text = builtins.toJSON (gen.toQuickshellTheme theme);
    "ghostty/config-${name}".text = gen.toGhosttyConfig theme;
    "kitty/kitty-${name}.conf".text = gen.toKittyConfig theme;
    "hypr/colors-${name}.lua".text = gen.toHyprColorsLua theme;
    "helix/themes/${name}.toml".text = gen.toHelixTheme theme;
    "yazi/theme-${name}.toml".text = gen.toYaziTheme theme;
    "lazygit/config-${name}.yml".text = gen.toLazygitTheme theme;
  }) themes;

  # App Config Rotator config (quickshell/plugins/user.appcredrotator/),
  # read by the plugin from ~/.local/share/appcredrotator/apps.json. See
  # ../appcredrotator/README.md.
  xdg.dataFile."appcredrotator/apps.json".source =
    config.lib.file.mkOutOfStoreSymlink /etc/nixos/appcredrotator/apps.json;

  home.activation.migrateDesktopState = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -z "''${DRY_RUN:-}" ]; then
      ${migrateState} || true
    fi
  '';

  systemd.user.services = {
    quickshell = {
      Unit = sessionUnit "Quickshell desktop shell";
      Install.WantedBy = [ sessionTarget ];
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/quickshell";
        Restart = "on-failure";
        RestartSec = "2";
        Environment = [ "TZDIR=/etc/zoneinfo" ];
      };
    };

    # Applies the scheduled theme at login (also renders the wallpaper swaybg
    # shows, and starts the blue-light filter for night themes).
    theme-init = {
      Unit = sessionUnit "Apply the scheduled desktop theme";
      Install.WantedBy = [ sessionTarget ];
      Service = {
        Type = "oneshot";
        ExecStart = "${scripts.theme-switch}/bin/theme-switch";
      };
    };

    # Ordered after theme-init so the first start finds a rendered wallpaper;
    # theme-switch restarts it after each re-render.
    swaybg = {
      Unit = sessionUnit "Desktop wallpaper" // {
        After = [
          sessionTarget
          "theme-init.service"
        ];
        ConditionPathExists = "${stateDir}/wallpaper.png";
      };
      Install.WantedBy = [ sessionTarget ];
      Service = {
        ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${stateDir}/wallpaper.png -m fill";
        Restart = "on-failure";
      };
    };

    # Blue-light filter; started/stopped by bluelight and theme-switch, not at
    # login directly.
    hyprsunset = {
      Unit = sessionUnit "Blue-light filter";
      Service = {
        ExecStart = "${scripts.hyprsunset-start}/bin/hyprsunset-start";
        Restart = "on-failure";
        RestartSec = "2";
      };
    };

    # No services.hypridle module: that would own hypridle.conf, which
    # idle-settings generates from ~/.local/state/desktop/idle.json.
    hypridle = {
      Unit = sessionUnit "Idle lock, screen-off and suspend";
      Install.WantedBy = [ sessionTarget ];
      Service = {
        ExecStartPre = "${scripts.idle-settings}/bin/idle-settings generate";
        ExecStart = "${pkgs.hypridle}/bin/hypridle";
        Restart = "on-failure";
        RestartSec = "10";
      };
    };

    cliphist-text = {
      Unit = sessionUnit "Clipboard history (text)";
      Install.WantedBy = [ sessionTarget ];
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };

    cliphist-image = {
      Unit = sessionUnit "Clipboard history (images)";
      Install.WantedBy = [ sessionTarget ];
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };

    hyprpolkitagent = {
      Unit = sessionUnit "Polkit authentication agent";
      Install.WantedBy = [ sessionTarget ];
      Service = {
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Restart = "on-failure";
        RestartSec = "2";
      };
    };

    # NetworkManager secret agent (prompts for Wi-Fi passwords that aren't
    # stored). Network selection itself is the bar's job; its tray icon is
    # hidden there.
    nm-applet = {
      Unit = sessionUnit "NetworkManager secret agent";
      Install.WantedBy = [ sessionTarget ];
      Service = {
        ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
        Restart = "on-failure";
        RestartSec = "5";
      };
    };

    battery-notify = {
      Unit.Description = "Notify on low battery";
      Service = {
        Type = "oneshot";
        ExecStart = "${scripts.battery-notify}/bin/battery-notify";
      };
    };

    theme-warmth-ramp = {
      Unit.Description = "Advance sunset-night's blue-light warmth ramp";
      Service = {
        Type = "oneshot";
        ExecStart = "${scripts.theme-warmth-ramp}/bin/theme-warmth-ramp";
      };
    };
  }
  # One service+timer pair per ../themes/schedule.nix entry.
  // lib.listToAttrs (
    map (entry: {
      name = "theme-${entry.theme}";
      value = {
        Unit.Description = "Switch the desktop to the ${entry.theme} theme";
        Service = {
          Type = "oneshot";
          ExecStart = "${scripts.theme-switch}/bin/theme-switch ${entry.theme}";
        };
      };
    }) schedule
  );

  systemd.user.timers = {
    # Two sysfs reads a minute; notify-send only at the thresholds.
    battery-notify = {
      Unit.Description = "Check battery level every minute";
      Timer = {
        OnBootSec = "1m";
        OnUnitActiveSec = "1m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
    # Only fires inside the 15:00-18:00 ramp window.
    theme-warmth-ramp = {
      Unit.Description = "Step the blue-light warmth ramp every 10 minutes from 15:00 to 18:00";
      Timer.OnCalendar = [
        "*-*-* 15..17:00/10:00"
        "*-*-* 18:00:00"
      ];
      Install.WantedBy = [ "timers.target" ];
    };
  }
  // lib.listToAttrs (
    map (entry: {
      name = "theme-${entry.theme}";
      value = {
        Unit.Description = "Trigger the ${entry.theme} theme at ${entry.time}";
        Timer = {
          OnCalendar = "*-*-* ${entry.time}:00";
          # Catch up on a switch missed while asleep or off.
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    }) schedule
  );

  # Manual fallback locker (Quickshell's LockScreen.qml is the real one); its
  # PAM service is in desktop/system.nix.
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
          color = "rgb(0d0d0d)";
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "300, 52";
          position = "0, -40";
          dots_center = true;
          fade_on_empty = false;
          font_family = "monospace";
          font_color = "rgb(cccccc)";
          inner_color = "rgb(000000)";
          outer_color = "rgb(aaaaaa)";
          outline_thickness = 2;
          placeholder_text = "Password";
          shadow_passes = 0;
        }
      ];
      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(ffffff)";
          font_size = 72;
          font_family = "monospace";
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  xdg.enable = true;

  # Floating terminal (scripts/float-terminal.sh) as the file manager's
  # terminal, in the three places that look for one:
  #  - exo (Thunar's "Open Terminal Here"): a helper plus helpers.rc
  #  - xdg-terminal-exec (GLib, for Terminal=true apps): a terminal desktop
  #    entry plus xdg-terminals.list
  xdg.dataFile."xfce4/helpers/float-terminal.desktop".text = ''
    [Desktop Entry]
    NoDisplay=true
    Version=1.0
    Type=X-XFCE-Helper
    X-XFCE-Category=TerminalEmulator
    X-XFCE-Commands=float-terminal
    X-XFCE-CommandsWithParameter=float-terminal -e sh -c "%s"
    Icon=utilities-terminal
    Name=Floating Terminal
  '';
  xdg.desktopEntries.float-terminal = {
    name = "Floating Terminal";
    genericName = "Terminal Emulator";
    exec = "float-terminal";
    icon = "utilities-terminal";
    terminal = false;
    categories = [
      "System"
      "TerminalEmulator"
    ];
    settings.X-TerminalArgExec = "-e";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Archives open in file-roller (also what Thunar's archive plugin drives).
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
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
      # Recolored folders (see papirusNoBlue above) - everything else in
      # the theme is untouched.
      package = papirusNoBlue;
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
    # Adwaita/Adwaita-dark's own stylesheet hardcodes blue for selections,
    # focus rings, links, and checked controls (`@theme_selected_bg_color:
    # #3584e4` etc.) - independent of both the terminal-app theme system
    # above and papirusNoBlue's icon recolor, since it's GTK3's own named
    # colors, not an icon or a generated app config. Redefining them here
    # re-themes every GTK3 app (pavucontrol, nm-connection-editor,
    # blueman-manager, thunar, ...) without switching off Adwaita-dark
    # itself. GTK cascades `@define-color` by last-defined-wins, so these
    # override the theme's own definitions as long as this file loads after
    # it - home-manager appends gtk.css after the theme import.
    gtk3.extraCss = ''
      @define-color theme_selected_bg_color #c8c8c8;
      @define-color theme_selected_fg_color #000000;
      @define-color link_color #cccccc;
      @define-color visited_link_color #999999;
    '';
  };
}
