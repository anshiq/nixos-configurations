{ pkgs, ... }:

let
  # Same file checked into nixos/desktop/wallpapers/ and used for the desktop
  # background and hyprlock (see desktop/home.nix) - keeping the boot/logout
  # greeter on the same image.
  wallpaper = ./wallpapers/shortcuts-latest.png;

  # SDDM's bundled "maldives" greeter theme, but with its background pointed
  # at `wallpaper` instead of its own baked-in image. `theme` below is set to
  # this derivation's absolute path rather than a bare name, which sddm's
  # Theme.Current accepts directly for out-of-tree themes (see the nixpkgs
  # sddm module's own example).
  sddmWallpaperTheme = pkgs.runCommand "sddm-theme-maldives-wallpaper" { } ''
        mkdir -p "$out/share/sddm/themes"
        cp -r ${pkgs.kdePackages.sddm}/share/sddm/themes/maldives "$out/share/sddm/themes/maldives-wallpaper"
        chmod -R u+w "$out/share/sddm/themes/maldives-wallpaper"
        cat > "$out/share/sddm/themes/maldives-wallpaper/theme.conf" <<EOF
    [General]
    background=${wallpaper}
    EOF
  '';
in
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
    theme = "${sddmWallpaperTheme}/share/sddm/themes/maldives-wallpaper";
  };

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

  environment.systemPackages = with pkgs; [
    google-chrome
    firefox
    ghostty
    kitty
    networkmanagerapplet
    vscode
    teams-for-linux
  ];

}
