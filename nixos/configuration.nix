# /etc/nixos/configuration.nix

{
  pkgs,
  ...
}:

{
  imports = [
    # This file must come from the native NixOS installer for the target machine.
    # Generate it with `nixos-generate-config` before the first native rebuild.
    ./hardware-configuration.nix
    ./desktop/system.nix
  ];

  ############################
  ## Native NixOS
  ############################

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nixpkgs.config.allowUnfree = true;

  # WSL settings are intentionally retained only as migration documentation.
  # wsl.enable = true;
  # wsl.defaultUser = "nixos";
  # wsl.interop.register = true;
  # wsl.wslConf.interop.enabled = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  #hardware.bluetooth.enable = true;
  #services.blueman.enable = true;

  # Run selected unpatched precompiled binaries that are not built for NixOS.
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    # core runtime
    stdenv.cc.cc.lib
    zlib
    zstd
    bzip2
    xz
    openssl
    curl
    libxml2
    icu

    cups
    dbus
    expat
    nspr
    nss
    cairo
    pango
    gtk3
    gdk-pixbuf
    harfbuzz

    # python native extensions
    libffi
    ncurses

    # browser / GUI (glib already covers a lot, these round it out)
    glib
    nss
    nspr
    dbus
    fontconfig
    freetype
    alsa-lib
    atk

    # Graphics
    mesa
    libdrm
    libgbm

    # X11
    libX11
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libxcb
    libXinerama
    libxkbcommon

    #gui zed
    wayland
    libxkbcommon
    vulkan-loader
    libGL
    fontconfig
    freetype

    # Audio
    alsa-lib

    # Misc
    udev
  ];
  # Do not export a global LD_LIBRARY_PATH on native NixOS: it can override
  # package-specific library resolution and make otherwise reproducible apps unstable.
  # environment.variables.LD_LIBRARY_PATH =
  #   lib.makeLibraryPath config.programs.nix-ld.libraries;

  ############################
  ## Fish Shell
  ############################

  programs.fish.enable = true;

  users.users.nixos = {
    isNormalUser = true;
    description = "NixOS User";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
    shell = pkgs.fish;
    initialPassword = "a";

  };
  security.sudo.enable = true;

  ############################
  ## Docker (rootless)
  ############################
  # Runs the docker daemon as the invoking user rather than root. The client
  # still needs `docker` on PATH, which comes from
  # virtualisation.docker.rootless's own package injection, but we also add
  # `docker-compose` explicitly below via systemPackages.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    # Google's public Docker Hub mirror. It's backed by Google's global
    # edge network, which peers well in India and is noticeably faster
    # than pulling directly from registry-1.docker.io.
    daemon.settings = {
      registry-mirrors = [ "https://mirror.gcr.io" ];
    };
  };

  ############################
  ## System Packages
  ############################
  #
  # NOTE ON MIGRATION: `zellij`, `yazi`, `lazygit`, and `fzf` are
  # intentionally NOT listed here. They are managed as Home Manager
  # *programs* in home.nix instead (programs.zellij / programs.yazi /
  # programs.fzf), which is the more "Nix-idiomatic" path: it installs
  # the package AND wires up its dotfiles/shell-integration from the
  # same declarative block, rather than splitting "package present"
  # (here) from "package configured" (home.nix) across two files.
  #
  # `zoxide` was on your old Ubuntu box (referenced in config.fish) but
  # you've asked to drop it entirely during this migration - it is not
  # installed anywhere in this config anymore.
  #
  # Native GUI applications and Hyprland services live in desktop/system.nix
  # and desktop/home.nix. Ghostty replaces Alacritty.

  environment.systemPackages = with pkgs; [
    # Shell
    fish
    starship

    # Editors
    neovim
    vim
    helix

    # Git & SSH
    git
    openssh
    gh

    # Networking
    curl
    wget
    lsof

    # Modern CLI tools
    eza
    bat
    fd
    ripgrep
    fzf
    zoxide
    jq
    tree
    unzip
    zip

    # Monitoring
    btop
    htop

    # Utilities
    which
    file
    gnupg

    #keyboard
    xkeyboard-config
    xclip

    # Docker (rootless daemon enabled above; compose plugin isn't pulled in
    # automatically by virtualisation.docker.rootless)
    docker-compose
  ];

  environment.sessionVariables.XKB_CONFIG_ROOT = "${pkgs.xkeyboard-config}/share/X11/xkb";

  ############################
  ## Git
  ############################

  programs.git.enable = true;

  ############################
  ## SSH
  ############################

  #services.openssh.enable = true;

  ############################
  ## Starship Prompt
  ############################

  programs.starship = {
    enable = true;
    settings = {
      scan_timeout = 1000;
    };
  };

  ############################
  ## Nix Settings
  ############################

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  ############################
  ## Locale
  ############################

  time.timeZone = "Asia/Kolkata";

  i18n.defaultLocale = "en_US.UTF-8";

  ############################
  ## State Version
  ############################

  system.stateVersion = "26.05";
}
