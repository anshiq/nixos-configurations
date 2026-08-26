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

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

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

  environment.systemPackages = with pkgs; [
    chromium
    ghostty
    kitty
    networkmanagerapplet
    vscode
    teams-for-linux
  ];

}
