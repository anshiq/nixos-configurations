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

  # The login screen is greetd + the Quickshell greeter, see desktop/greeter.nix.

  security.polkit.enable = true;
  # One keyring daemon for the whole session (SSH/GPG/app secrets), unlocked
  # with the login password through greetd's PAM stack.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # PAM services for the lock screens: without one, authentication falls back
  # to /etc/pam.d/other, which always denies. quickshell-lock is what
  # quickshell/LockScreen.qml authenticates against; hyprlock is the manual
  # fallback locker.
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

  # Caps the wait on a hanging user manager at shutdown ("A stop job is
  # running for user manager") at 7s instead of the 90s default; it is still
  # SIGTERMed then SIGKILLed, just sooner.
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
