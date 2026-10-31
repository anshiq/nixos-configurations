# Desktop settings app: Wi-Fi, Bluetooth, Sound, Display, Power, Capture,
# Appearance, Lock screen, Services, Dev servers, Credentials. The app itself is the standalone Quickshell config in
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
    # happens to be in the session's PATH. The desktop's own commands
    # (theme-switch, bluelight, screen-record, idle-settings, ...), hyprctl
    # and the docker CLI come from the session PATH.
    runtimeInputs = with pkgs; [
      quickshell
      networkmanager # nmcli (Wi-Fi page)
      bluez # bluetoothctl (pairing agent on the Bluetooth page)
      brightnessctl # Display page
      power-profiles-daemon # powerprofilesctl (Power page)
      procps # pgrep
      hyprpicker # colour picker (Capture page)
      xdg-utils # xdg-open (folders on the Capture and Lock screen pages)
      iproute2 # ss (listening ports on the Dev servers page)
      systemd # systemctl / journalctl (Services page)
    ];
    text = ''
      # settings-app [page]
      #   page: wifi bluetooth sound display power capture appearance
      #         lockscreen services devservers credentials
      dir="''${XDG_CONFIG_HOME:-$HOME/.config}/settings-app"

      # One window only: if it is already open, switch it to the requested
      # page and bring it forward instead of starting a second copy.
      if quickshell list -p "$dir" 2>/dev/null | grep -q 'Process ID'; then
        if [ -n "''${1:-}" ]; then
          quickshell ipc -p "$dir" call settings open "$1" >/dev/null 2>&1 || true
        fi
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
    comment = "Wi-Fi, Bluetooth, sound, display, power, capture, appearance and services";
    exec = "settings-app";
    icon = "preferences-system";
    terminal = false;
    categories = [
      "Settings"
      "System"
    ];
    settings.Keywords = "wifi;wi-fi;network;bluetooth;sound;audio;volume;brightness;display;battery;power;theme;wallpaper;lock;screenshot;screen recording;colour picker;color picker;services;docker;dev server;credentials;secrets;";
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
      capture = {
        name = "Capture";
        exec = "settings-app capture";
      };
      appearance = {
        name = "Appearance";
        exec = "settings-app appearance";
      };
      lockscreen = {
        name = "Lock screen";
        exec = "settings-app lockscreen";
      };
      services = {
        name = "Services";
        exec = "settings-app services";
      };
      devservers = {
        name = "Dev servers";
        exec = "settings-app devservers";
      };
      credentials = {
        name = "Credentials";
        exec = "settings-app credentials";
      };
    };
  };
}
