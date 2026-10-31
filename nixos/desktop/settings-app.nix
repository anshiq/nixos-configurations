# Desktop settings app: Wi-Fi, Bluetooth, Sound, Display, Power, Appearance,
# Lock screen. The app itself is the standalone Quickshell config in
# ./settings-app/ (QML + a few helper scripts); this module only installs the
# launcher, the desktop entry, and the live symlink to the checkout.
#
# Needs system-side services (see configuration.nix): hardware.bluetooth
# (bluez, for the Bluetooth page) and services.power-profiles-daemon (the
# profile picker on the Power page). Without them those two pages show an
# explanatory "unavailable" state instead of failing.
{ config, pkgs, ... }:

let
  # Same pattern as quickshell/ in desktop/home.nix: a live symlink into the
  # git checkout, not a Nix-store copy, so QML edits apply on the next launch
  # without a rebuild.
  appDir = "/etc/nixos/desktop/settings-app";

  settingsApp = pkgs.writeShellApplication {
    name = "settings-app";
    # Tools the pages shell out to, so the app does not depend on what
    # happens to be in the session's PATH.
    runtimeInputs = with pkgs; [
      quickshell
      networkmanager # nmcli (Wi-Fi page)
      bluez # bluetoothctl (pairing agent on the Bluetooth page)
      brightnessctl # Display page
      power-profiles-daemon # powerprofilesctl (Power page)
      procps # pgrep
    ];
    text = ''
      # settings-app [wifi|bluetooth|sound|display|power|appearance|lockscreen]
      dir="''${XDG_CONFIG_HOME:-$HOME/.config}/settings-app"

      # One window only: if it is already open, bring it forward instead of
      # starting a second copy.
      if quickshell list -p "$dir" 2>/dev/null | grep -q 'Process ID'; then
        hyprctl dispatch 'hl.dsp.focus({ window = "title:^Settings$" })' >/dev/null 2>&1 || true
        exit 0
      fi

      export SETTINGS_PAGE="''${1:-}"
      exec quickshell -n -p "$dir"
    '';
  };
in
{
  xdg.configFile."settings-app".source = config.lib.file.mkOutOfStoreSymlink appDir;

  home.packages = [ settingsApp ];

  xdg.desktopEntries.settings-app = {
    name = "Settings";
    genericName = "System Settings";
    comment = "Wi-Fi, Bluetooth, sound, display, power and appearance";
    exec = "settings-app";
    icon = "preferences-system";
    terminal = false;
    categories = [
      "Settings"
      "System"
    ];
    settings.Keywords = "wifi;wi-fi;network;bluetooth;sound;audio;volume;brightness;display;battery;power;theme;wallpaper;lock;";
    actions = {
      wifi = {
        name = "Wi-Fi";
        exec = "settings-app wifi";
      };
      bluetooth = {
        name = "Bluetooth";
        exec = "settings-app bluetooth";
      };
      sound = {
        name = "Sound";
        exec = "settings-app sound";
      };
      display = {
        name = "Display";
        exec = "settings-app display";
      };
      power = {
        name = "Power";
        exec = "settings-app power";
      };
    };
  };
}
