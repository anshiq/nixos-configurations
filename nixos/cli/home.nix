# Headless counterpart of the desktop branch's desktop/home.nix: only the
# terminal-app half of the theme system (helix, yazi, lazygit, zellij), plus
# the theme-switch / theme-status commands and the schedule timers. No
# Hyprland, Quickshell, wallpaper, GTK or blue-light pieces.
#
# State paths (~/.config/desktop, ~/.local/state/desktop) match the desktop
# branch on purpose, so home.nix and the themes/ directory merge across
# branches without edits.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  themes = import ../themes;
  gen = import ../themes/generators.nix { inherit lib; };
  schedule = import ../themes/schedule.nix;

  base = with pkgs; [
    coreutils
    gnused
    gawk
    findutils
    jq
  ];

  theme-switch = pkgs.writeShellApplication {
    name = "theme-switch";
    runtimeInputs = base ++ [ pkgs.procps ];
    text = builtins.readFile ./theme-switch.sh;
  };

  theme-status = pkgs.writeShellApplication {
    name = "theme-status";
    runtimeInputs = base;
    text = builtins.readFile ./theme-status.sh;
  };
in
{
  home.packages = [
    theme-switch
    theme-status
  ];

  xdg.enable = true;

  xdg.configFile = {
    # theme-switch's data: the palette JSON per theme (read for its day/night
    # mode) and the clock-based schedule.
    "desktop/schedule.json".text = builtins.toJSON schedule;
  }
  # Per-theme variants. The active helix/themes/current.toml, yazi/theme.toml
  # and lazygit/config.yml are symlinks theme-switch repoints at runtime, so
  # they are deliberately not managed here.
  // lib.concatMapAttrs (name: theme: {
    "desktop/themes/${name}.json".text = builtins.toJSON (gen.toQuickshellTheme theme);
    "helix/themes/${name}.toml".text = gen.toHelixTheme theme;
    "yazi/theme-${name}.toml".text = gen.toYaziTheme theme;
    "lazygit/config-${name}.yml".text = gen.toLazygitTheme theme;
  }) themes;

  systemd.user.services =
    {
      # Applies the scheduled theme when the user manager starts.
      theme-init = {
        Unit.Description = "Apply the scheduled terminal theme";
        Install.WantedBy = [ "default.target" ];
        Service = {
          Type = "oneshot";
          ExecStart = "${theme-switch}/bin/theme-switch";
        };
      };
    }
    # One service+timer pair per ../themes/schedule.nix entry.
    // lib.listToAttrs (
      map (entry: {
        name = "theme-${entry.theme}";
        value = {
          Unit.Description = "Switch the terminal theme to ${entry.theme}";
          Service = {
            Type = "oneshot";
            ExecStart = "${theme-switch}/bin/theme-switch ${entry.theme}";
          };
        };
      }) schedule
    );

  systemd.user.timers = lib.listToAttrs (
    map (entry: {
      name = "theme-${entry.theme}";
      value = {
        Unit.Description = "Trigger the ${entry.theme} theme at ${entry.time}";
        Timer = {
          OnCalendar = "*-*-* ${entry.time}:00";
          # Catch up on a switch missed while the machine was off.
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    }) schedule
  );
}
