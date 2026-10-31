{ pkgs, ... }:

{
  # Native graphical stack. This is intentionally Hyprland-only, not a full
  # GNOME/KDE desktop environment.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  programs.thunar.enable = true;
  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
  ];

  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true;
  programs.xfconf.enable = true;

  # The login screen is greetd + the Quickshell greeter, see desktop/greeter.nix
  # (it replaced SDDM so the first screen after boot matches the lock screen).

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  # home-manager's programs.hyprlock module does NOT register a PAM service
  # on its own (its own docs say so) - without this, hyprlock authenticates
  # against /etc/pam.d/other, which unconditionally denies (pam_deny.so), so
  # no password would ever unlock it. This was missing before the Quickshell
  # lock screen work below and is fixed here regardless of which lock screen
  # is active. quickshell-lock is the PAM service Quickshell's LockScreen.qml
  # (Quickshell.Services.Pam PamContext) authenticates against - see
  # quickshell/LockScreen.qml.
  security.pam.services.hyprlock = { };
  security.pam.services.quickshell-lock = { };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # PipeWire supplies native Wayland audio and screen-sharing support.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # Reboot/shutdown was hanging on "A stop job is running for user manager
  # for uid 1000" for the full systemd default (90s) before giving up and
  # killing it. Caps that wait at 10s instead - the service is still killed
  # (SIGTERM then SIGKILL) if it doesn't stop cleanly, just much sooner.
  systemd.services."user@".serviceConfig.TimeoutStopSec = "7s";

  # Power button was powering off the machine (logind's default
  # HandlePowerKey=poweroff, which fires before Hyprland ever sees the key).
  # Make logind ignore it so Hyprland's XF86PowerOff bind (hypr/hyprland.lua)
  # can lock the session instead.
  services.logind.settings.Login.HandlePowerKey = "ignore";

  environment.systemPackages = with pkgs; [
    google-chrome
    firefox
    ghostty
    kitty
    networkmanagerapplet
    vscode
    teams-for-linux
    pgadmin4
    tigervnc
    xinit

    # Networking tools (curl, wget, lsof, openssh are in configuration.nix)
    net-tools # ifconfig, netstat, route, arp
    iproute2
    iputils
    ethtool
    bind # dig, nslookup, host (dnsutils is an alias of this)
    netcat
    socat
    nmap
    tcpdump
    wireshark-cli
    httpie
    traceroute
    iperf3
  ];

}
