# Boot-time login screen: greetd running the Quickshell greeter in ./greeter,
# which looks like the Quickshell lock screen (quickshell/LockScreen.qml).
#
# Flow: greetd starts `cage` (a kiosk compositor that shows one window
# fullscreen) as the unprivileged `greeter` user; cage runs the Quickshell
# greeter; on a good password the greeter asks greetd to start the session
# (UWSM -> Hyprland, the "Hyprland (uwsm-managed)" session entry) and exits.
#
# Palette and wallpaper: the greeter cannot read the user's home, so
# `greeter-sync` (desktop/greeter-sync.nix) publishes copies into sharedDir,
# which this module creates. Until the first sync it uses the wallpaper baked
# in below.
#
# Changing display managers: do NOT `nixos-rebuild switch` while logged in -
# that stops the old display manager (ending your session) and starts greetd on
# the same VT. Use `nixos-rebuild boot` and reboot.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.greeter;

  sharedDir = "/var/lib/quickshell-greeter";

  # Same image the desktop background and hyprlock use; shown by the greeter
  # until the user's own lock wallpaper has been published.
  fallbackWallpaper = ./wallpapers/shortcuts-latest.png;

  loginUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  loginUser = lib.head loginUsers;

  startGreeter = pkgs.writeShellScript "start-quickshell-greeter" ''
    export QT_QPA_PLATFORM=wayland
    # Lets cage fall back to a software GL renderer on a machine/VM without
    # GPU acceleration; unused when real GL is available.
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    export GREETER_USER=${lib.escapeShellArg loginUser}
    export GREETER_SESSION_CMD=${lib.escapeShellArg cfg.sessionCommand}
    export GREETER_SHARED_DIR=${sharedDir}
    export GREETER_FALLBACK_WALLPAPER=${fallbackWallpaper}
    exec ${pkgs.cage}/bin/cage -s -d -- ${pkgs.quickshell}/bin/quickshell -p ${./greeter}
  '';
in
{
  options.desktop.greeter.sessionCommand = lib.mkOption {
    type = lib.types.str;
    default = "${config.programs.uwsm.package}/bin/uwsm start -e -D Hyprland hyprland.desktop";
    description = ''
      Command (split on spaces, no quoting) that greetd runs as the user after
      a successful login. The default is what the "Hyprland (uwsm-managed)"
      session entry executes.
    '';
  };

  config = {
    assertions = [
      {
        assertion = loginUsers != [ ];
        message = "desktop/greeter.nix: no normal user is defined to log in as.";
      }
    ];

    services.greetd = {
      enable = true;
      settings.default_session.command = "${startGreeter}";
    };

    # Where greeter-sync (run as the user) drops theme.json and wallpaper for
    # the greeter to read: writable by the user, readable by everyone.
    systemd.tmpfiles.rules = [
      "d ${sharedDir} 0755 ${loginUser} ${config.users.users.${loginUser}.group} -"
    ];
  };
}
