{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Single source of truth for every theme's palette (see ../themes/) and
  # the pure render functions turning one into ghostty/kitty/hyprlock/
  # Quickshell/Hyprland-border config text (../themes/generators.nix).
  # Adding a theme = add one file under ../themes/ - everything below
  # iterates `themes` and `schedule`, no other change needed here.
  themes = import ../themes;
  gen = import ../themes/generators.nix { inherit lib; };
  schedule = import ../themes/schedule.nix;

  # Third-party bar-widget plugins - see ../plugins/default.nix. Read
  # directly (not via IFD on the fetched `src`s - see the activation script
  # below for why) so evaluating this file never needs network access or a
  # plugin's source to already be built.
  externalPlugins = import ../plugins { inherit pkgs; };

  # First-party plugin manifests, read directly from the checkout (real
  # files already on disk, safe at eval time - no IFD). Combined with
  # `externalPlugins` below into plugin-registry.json: the full list of
  # every plugin the shell knows about, independent of whether it's
  # currently enabled on the bar (that's plugin-layout.json's job, edited by
  # quickshell/scripts/plugin.sh).
  # Excludes externalPlugins ids: those directories are activation-script-
  # managed (see home.activation.quickshellPlugins below, which fills them
  # with per-file symlinks into each plugin's fetched store path and marks
  # them with a `.nix-managed` file) and already counted below via
  # externalPlugins directly. Reading their manifest.json *here* instead
  # would follow a tracked symlink to an absolute store path, which errors
  # ("forbidden in pure evaluation mode") once that symlink's target is
  # committed and evaluation runs through git's filtered source tree rather
  # than the live filesystem.
  builtinPluginDirs = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && !(externalPlugins ? ${name})
    ) (builtins.readDir ../quickshell/plugins)
  );
  builtinPluginManifest =
    dir: builtins.fromJSON (builtins.readFile (../quickshell/plugins + "/${dir}/manifest.json"));
  # `origin` (builtin/external) is separate from the manifest's own `kind`
  # field (which describes the widget type, e.g. "bar-widget") - added
  # rather than overwritten.
  pluginRegistry =
    (map (dir: (builtinPluginManifest dir) // { origin = "builtin"; }) builtinPluginDirs)
    ++ (lib.mapAttrsToList (id: p: {
      inherit id;
      name = p.name;
      kind = "bar-widget";
      origin = "external";
    }) externalPlugins);

  # Checked into version control (nixos/desktop/wallpapers/) - the same file
  # is used for the desktop background (swaybg), hyprlock, and the SDDM
  # greeter theme (see desktop/system.nix), so all three always match.
  wallpaper = ./wallpapers/shortcuts-latest.png;
  terminal = "ghostty";
  browser = "google-chrome-stable";

  # Real Omarchy ships `/usr/share/omarchy/bin/omarchy-clipboard-{paste-text,
  # paste-file,open}` as first-class OS binaries; every action in the
  # (manually plugin.sh-added) io.github.vuhuy.clipboard-manager bar
  # plugin's Panel.qml shells out to them via `$OMARCHY_PATH/bin/...`
  # (Panel.qml defaults OMARCHY_PATH to "/usr/share/omarchy", which doesn't
  # exist here). This system has no such distro-level helpers, so this is
  # a minimal stand-in: reads clipboard-history-sync.sh's
  # clipboard-history.json by index, wl-copy's the entry, and - unless
  # --copy-only - sends Shift+Insert via wtype so the paste also lands in
  # the focused app (Shift+Insert works in both terminals and most GUI text
  # fields, which is presumably why real Omarchy's own helper uses it too).
  # `omarchy-clipboard-open`'s "open" has no real equivalent to replicate
  # here, so it's approximated as: open with xdg-open if the entry is a
  # URL or an image file, else just copy it.
  omarchyClipboardShim = pkgs.symlinkJoin {
    name = "omarchy-clipboard-shim";
    paths = [
      (pkgs.writeShellApplication {
        name = "omarchy-clipboard-paste-text";
        runtimeInputs = [
          pkgs.jq
          pkgs.wl-clipboard
          pkgs.wtype
        ];
        text = ''
          copy_only=false
          shift_insert=false
          history_index=""

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --copy-only)
                copy_only=true
                shift
                ;;
              --shift-insert)
                shift_insert=true
                shift
                ;;
              --history-index)
                history_index="$2"
                shift 2
                ;;
              *)
                shift
                ;;
            esac
          done

          history_file="$HOME/.local/state/omarchy/clipboard-history.json"
          [ -f "$history_file" ] || exit 0
          [ -n "$history_index" ] || exit 0

          text=$(jq -r --argjson i "$history_index" '.[$i].text // empty' "$history_file")
          [ -n "$text" ] || exit 0

          printf '%s' "$text" | wl-copy

          if [ "$copy_only" = false ] && [ "$shift_insert" = true ]; then
            sleep 0.15
            wtype -M shift -k Insert -m shift
          fi
        '';
      })
      (pkgs.writeShellApplication {
        name = "omarchy-clipboard-paste-file";
        runtimeInputs = [
          pkgs.wl-clipboard
          pkgs.wtype
        ];
        text = ''
          copy_only=false
          if [ "''${1:-}" = "--copy-only" ]; then
            copy_only=true
            shift
          fi

          mime="''${1:-}"
          path="''${2:-}"
          [ -n "$mime" ] && [ -n "$path" ] || exit 0
          [ -f "$path" ] || exit 0

          wl-copy --type "$mime" < "$path"

          if [ "$copy_only" = false ]; then
            sleep 0.15
            wtype -M shift -k Insert -m shift
          fi
        '';
      })
      (pkgs.writeShellApplication {
        name = "omarchy-clipboard-open";
        runtimeInputs = [
          pkgs.jq
          pkgs.wl-clipboard
          pkgs.xdg-utils
        ];
        text = ''
          history_index=""
          while [ "$#" -gt 0 ]; do
            case "$1" in
              --history-index)
                history_index="$2"
                shift 2
                ;;
              *)
                shift
                ;;
            esac
          done

          history_file="$HOME/.local/state/omarchy/clipboard-history.json"
          [ -f "$history_file" ] || exit 0
          [ -n "$history_index" ] || exit 0

          entry_type=$(jq -r --argjson i "$history_index" '.[$i].type // empty' "$history_file")

          if [ "$entry_type" = "image" ]; then
            path=$(jq -r --argjson i "$history_index" '.[$i].path // empty' "$history_file")
            [ -n "$path" ] && xdg-open "$path"
          else
            text=$(jq -r --argjson i "$history_index" '.[$i].text // empty' "$history_file")
            [ -n "$text" ] || exit 0
            case "$text" in
              http://* | https://*)
                xdg-open "$text"
                ;;
              *)
                printf '%s' "$text" | wl-copy
                ;;
            esac
          fi
        '';
      })
    ];
  };

  # Builds a hyprlock settings attrset from a theme (see ../themes/). One
  # static conf is rendered per theme below and flipped between by
  # theme-switch.sh at runtime, since programs.hyprlock only generates a
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
        # "monospace" generic family so `omarchy font set` (nixos/scripts/omarchy)
        # can repoint it via a fontconfig alias without a rebuild.
        font_family = "monospace";
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
        # "monospace" generic family so `omarchy font set` (nixos/scripts/omarchy)
        # can repoint it via a fontconfig alias without a rebuild.
        font_family = "monospace";
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
    jq # quickshell/scripts/plugin.sh
    libnotify
    obs-studio
    pamixer
    playerctl
    quickshell
    slurp
    swaybg
    wl-clipboard
    wtype
    xdg-utils
  ];

  home.sessionVariables = {
    BROWSER = browser;
    TERMINAL = terminal;
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    # Points plugins/io.github.vuhuy.clipboard-manager/Panel.qml (and any
    # other plugin expecting real Omarchy's distro-level helper binaries)
    # at our stand-ins instead of its "/usr/share/omarchy" default - see
    # omarchyClipboardShim above.
    OMARCHY_PATH = "${omarchyClipboardShim}";
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
  xdg.configFile =
    {
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
    }
    # style.css, ghostty/config, kitty/kitty.conf, hypr/hyprlock.conf, and
    # hypr/colors.lua are NOT managed directly: each is a runtime symlink
    # flipped between per-theme variants (generated below) by
    # theme-switch.sh, so home-manager activation doesn't fight the switcher
    # while the session is running.
    #
    # One variant of each per-theme file is generated per entry in
    # ../themes/ (see ../themes/generators.nix) - adding a theme there
    # automatically gets a full file set here, no change needed in this
    # block.
    // (lib.concatMapAttrs (name: theme: {
      "ghostty/config-${name}".text = gen.toGhosttyConfig theme;
      "kitty/kitty-${name}.conf".text = gen.toKittyConfig theme;
      "hypr/colors-${name}.lua".text = gen.toHyprColorsLua theme;
      "hypr/hyprlock-${name}.conf".text = lib.hm.generators.toHyprconf {
        attrs = hyprlockSettings theme;
        importantPrefixes = [
          "$"
          "bezier"
          "monitor"
          "size"
          "source"
        ];
      };
    }) themes)
    // {
      # theme-switch.sh's own view of what themes exist: one name per line
      # (cycle order for `next`), a "name kind" table (for `toggle`'s
      # day/night lookup), and a "time name" table (for the no-arg
      # clock-based lookup, from ../themes/schedule.nix).
      "waybar/scripts/themes.list".text = lib.concatStringsSep "\n" (builtins.attrNames themes) + "\n";
      "waybar/scripts/theme-kinds.list".text =
        lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t: "${name} ${t.kind}") themes) + "\n";
      "waybar/scripts/schedule.list".text = lib.concatStringsSep "\n" (map (e: "${e.time} ${e.theme}") schedule) + "\n";
    };

  # quickshell/ is deployed as a single out-of-store symlink to the live
  # checkout above (so QML edits are picked up without a rebuild), which
  # means home-manager can't override individual files inside it the way
  # xdg.configFile does elsewhere. Each theme's data file is instead written
  # into the checkout directly on every activation - QML stays hand-edited,
  # theme data stays Nix-generated. theme-switch.sh then copies whichever of
  # these is active into ~/.local/state/quickshell/theme.json (see there for
  # why it's a copy and not a symlink).
  home.activation.quickshellThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: theme: ''
        install -m 644 ${pkgs.writeText "theme-${name}.json" (builtins.toJSON (gen.toQuickshellTheme theme))} \
          "/home/nixos/myprojects/nixos-configurations/nixos/quickshell/theme-${name}.json"
      '') themes
    )
  );

  # Same live-checkout constraint as quickshellThemes above, for plugins:
  # - plugin-registry.json (every known plugin, builtin + external - see
  #   `pluginRegistry` above) is written into the checkout the same way
  #   theme-<name>.json is, for quickshell/PluginRegistry.qml to read.
  # - Each ../plugins/default.nix entry's fetched `src` is placed under
  #   quickshell/plugins/<id>, alongside the hand-written user.* plugin
  #   directories - PluginRow.qml resolves both the same way (by id under
  #   ~/.config/quickshell/plugins/), so an external plugin is
  #   indistinguishable from a first-party one once in place.
  #
  #   `<id>` is a real (writable) directory with each of `src`'s files
  #   symlinked in individually - NOT `<id>` itself symlinked whole to
  #   `src` (a read-only Nix store path) - because a multi-file plugin
  #   needs a real qmldir alongside its own files (see
  #   quickshell/scripts/plugin.sh's generate_plugin_qmldir for why: a
  #   plugin whose widget instantiates sibling files as bare types, e.g.
  #   Panel.qml referencing a sibling Model.qml, hits "X is not a type" at
  #   runtime without one - Quickshell's implicit per-directory type
  #   synthesis doesn't reliably apply under its own `qs:` URL scheme). A
  #   `.nix-managed` marker distinguishes these from hand-written/`plugin.sh
  #   add`-installed directories, so the stale-cleanup below only ever
  #   removes directories this activation itself created.
  home.activation.quickshellPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    let
      pluginsDir = "/home/nixos/myprojects/nixos-configurations/nixos/quickshell/plugins";
    in
    ''
      install -m 644 ${pkgs.writeText "plugin-registry.json" (builtins.toJSON pluginRegistry)} \
        "/home/nixos/myprojects/nixos-configurations/nixos/quickshell/plugin-registry.json"

      for existing in "${pluginsDir}"/*; do
        [ -f "$existing/.nix-managed" ] || continue
        id="$(basename "$existing")"
        case " ${lib.concatStringsSep " " (builtins.attrNames externalPlugins)} " in
          *" $id "*) : ;;
          *) rm -rf "$existing" ;;
        esac
      done
    ''
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (id: plugin: ''
        target="${pluginsDir}/${id}"
        rm -rf "$target"
        mkdir -p "$target"
        for f in ${plugin.src}/*; do
          ln -sfn "$f" "$target/$(basename "$f")"
        done
        touch "$target/.nix-managed"
        if [ ! -e "$target/qmldir" ]; then
          {
            for f in "$target"/*.qml; do
              [ -e "$f" ] || continue
              base=$(basename "$f" .qml)
              echo "$base 1.0 $(basename "$f")"
            done
          } > "$target/qmldir"
        fi
      '') externalPlugins
    )
  );

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
  # All systemd.user services/timers in this module are collected into the
  # two assignments below (rather than one dotted `systemd.user.services.foo
  # = ...;` per unit) so the schedule-driven theme units - one per
  # ../themes/schedule.nix entry, name/count not known until that list is
  # read - can be spliced in with `//`/`lib.listToAttrs` alongside the
  # hand-written ones without Nix's attribute-set-literal rules treating
  # "systemd.user.services.hypridle = ..." and a later flat
  # "systemd.user.services = ..." as conflicting definitions of the same
  # path.
  systemd.user.services =
    {
      hypridle = {
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
      # Polls battery capacity every minute and notifies once at 15% and
      # again at 5% while discharging (see waybar/scripts/battery-notify.sh)
      # - the script itself tracks state so each threshold only fires once
      # per discharge cycle.
      battery-notify = {
        Unit.Description = "Notify on low battery";
        Service = {
          Type = "oneshot";
          ExecStart = "${config.xdg.configHome}/waybar/scripts/battery-notify.sh";
        };
      };
      # Real Omarchy has a built-in `omarchy.clipboard` service that watches
      # the clipboard and writes ~/.local/state/omarchy/clipboard-history.json;
      # this system has none, so the io.github.vuhuy.clipboard-manager bar
      # plugin (manually plugin.sh-added, not Nix-declared - see
      # plugin-layout.json) had an icon but no history to show. `wl-paste
      # --watch` runs the sync script below once per clipboard change,
      # feeding it the new text on stdin.
      clipboard-history = {
        Unit = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
          Description = "Sync clipboard changes into Omarchy's clipboard-history.json";
          After = [ config.wayland.systemd.target ];
          PartOf = [ config.wayland.systemd.target ];
        };
        Install.WantedBy = [ config.wayland.systemd.target ];
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch %h/.config/quickshell/scripts/clipboard-history-sync.sh";
          Restart = "always";
          RestartSec = "10";
        };
      };
    }
    # One timer+service pair per ../themes/schedule.nix entry - applies to
    # ghostty, kitty, hyprlock, Quickshell (bar/launcher/notifications), and
    # Hyprland's own border colors (see waybar/scripts/theme-switch.sh).
    # `systemctl --user list-timers` shows all of them; each is
    # independently inspectable as theme-<name>.timer/.service. Also run
    # once at login (see hypr/hyprland.lua autostart, no-arg
    # theme-switch.sh) so the session starts on whichever theme's window
    # contains the current time, without waiting for the next timer tick.
    // lib.listToAttrs (
      map (entry: {
        name = "theme-${entry.theme}";
        value = {
          Unit.Description = "Switch the desktop to the ${entry.theme} theme";
          Service = {
            Type = "oneshot";
            ExecStart = "%h/.config/waybar/scripts/theme-switch.sh ${entry.theme}";
          };
        };
      }) schedule
    );

  systemd.user.timers =
    {
      battery-notify = {
        Unit.Description = "Check battery level every minute";
        Timer = {
          OnBootSec = "1m";
          OnUnitActiveSec = "1m";
        };
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
            # Catches up on a transition missed while asleep/off at the
            # trigger time, rather than staying on the previous theme until
            # the next one fires.
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      }) schedule
    );

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
}
