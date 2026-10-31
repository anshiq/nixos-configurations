# Desktop commands, one writeShellApplication per script in this directory.
# Callers use them by bare name (they are on PATH via home.packages) or by
# store path (systemd units). writeShellApplication runs shellcheck at build
# time and sets `set -euo pipefail`.
{ pkgs }:

let
  mk =
    {
      name,
      file ? ./${name}.sh,
      runtimeInputs ? [ ],
      preamble ? "",
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = preamble + builtins.readFile file;
    };

  base = with pkgs; [
    coreutils
    gnused
    gawk
    findutils
    jq
  ];
in
rec {
  on-battery = mk {
    name = "on-battery";
    runtimeInputs = [ pkgs.coreutils ];
  };

  greeter-sync = mk {
    name = "greeter-sync";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      jq
    ];
  };

  theme-status = mk {
    name = "theme-status";
    runtimeInputs = base;
  };

  render-wallpaper = mk {
    name = "render-wallpaper";
    runtimeInputs = base ++ [ pkgs.librsvg ];
    preamble = ''
      template=${../wallpapers/shortcuts-latest.svg}
    '';
  };

  theme-warmth-ramp = mk {
    name = "theme-warmth-ramp";
    runtimeInputs = base ++ [
      theme-status
      pkgs.systemd
      pkgs.hyprland
    ];
  };

  theme-switch = mk {
    name = "theme-switch";
    runtimeInputs = base ++ [
      render-wallpaper
      theme-warmth-ramp
      greeter-sync
      pkgs.procps
      pkgs.systemd
      pkgs.hyprland
    ];
  };

  bluelight = mk {
    name = "bluelight";
    runtimeInputs = base ++ [
      pkgs.systemd
      pkgs.hyprland
    ];
  };

  hyprsunset-start = mk {
    name = "hyprsunset-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hyprsunset
    ];
  };

  idle-settings = mk {
    name = "idle-settings";
    runtimeInputs = base ++ [ pkgs.systemd ];
    preamble = ''
      on_battery=${on-battery}/bin/on-battery
    '';
  };

  battery-notify = mk {
    name = "battery-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
    ];
  };

  screenshot = mk {
    name = "screenshot";
    runtimeInputs = [ pkgs.flameshot ];
  };

  screen-record = mk {
    name = "screen-record";
    runtimeInputs = base ++ [
      pkgs.wf-recorder
      pkgs.slurp
      pkgs.libnotify
      pkgs.gnugrep
    ];
  };
}
