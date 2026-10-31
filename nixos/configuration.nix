# /etc/nixos/configuration.nix

{
  config,
  lib,
  pkgs,
  ...
}:

{
  ############################
  ## WSL
  ############################
  # NixOS-WSL (flake.nix) supplies the boot, filesystem and init plumbing, so
  # there is no hardware-configuration.nix, bootloader or NetworkManager here.

  wsl.enable = true;
  wsl.defaultUser = "nixos";
  wsl.interop.register = true;
  wsl.wslConf.interop.enabled = true;

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "nixos";

  # Caps the wait on a hanging user manager at shutdown at 7s (default 90s).
  systemd.services."user@".serviceConfig.TimeoutStopSec = "7s";

  # Run selected unpatched precompiled binaries that are not built for NixOS.
  programs.nix-ld.enable = true;

  # The nix-ld module already provides the core runtime (libstdc++, zlib, zstd,
  # bzip2, xz, openssl, curl, libxml2, ...); only extras are listed here.
  programs.nix-ld.libraries = with pkgs; [
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
    dig

    # python native extensions
    libffi
    ncurses

    # browser / GUI (glib already covers a lot, these round it out)
    glib
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
    vulkan-loader
    libGL

    # Audio
    libpulseaudio # needed by the Android emulator's qemu-system-x86_64

    # Android emulator (qemu-system-x86_64 + its bundled Qt UI) - found by
    # trial and error running `emulator -avd ...` directly: it's an
    # unpatched prebuilt binary from the SDK, not a nix package, so every
    # shared lib it dlopens has to be listed here explicitly.
    libpng
    libjpeg
    SDL2
    libxkbfile
    libSM
    libICE
    libbsd

    # Misc
    udev
  ];
  # nix-ld sets NIX_LD_LIBRARY_PATH for the patched interpreter, which covers
  # normal binary loading. Explicit dlopen() calls at runtime (Bun's native
  # addon loader) only honour LD_LIBRARY_PATH, so WSL exports it too. The
  # native desktop/headless branches leave it unset because a global
  # LD_LIBRARY_PATH can override package-specific library resolution.
  environment.variables.LD_LIBRARY_PATH = lib.makeLibraryPath config.programs.nix-ld.libraries;

  ############################
  ## Fish Shell
  ############################

  programs.fish.enable = true;

  users.users.nixos = {
    isNormalUser = true;
    description = "NixOS User";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
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
  # Tools configured through a programs.* module (fish, starship, git, zoxide
  # here; fzf, helix, zellij, yazi in home.nix) are not repeated in this list:
  # the module installs the package. This is the WSL branch: no GUI, and no
  # libvirt/KVM; GUI applications and the Hyprland/Quickshell desktop live on
  # the desktop branch.

  environment.systemPackages = with pkgs; [
    # Editors
    neovim
    vim

    # Git & SSH
    openssh
    gh

    # Networking
    curl
    wget
    lsof
    fastfetch

    # Modern CLI tools
    eza
    bat
    fd
    ripgrep
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

    # Docker (rootless daemon enabled above; compose plugin isn't pulled in
    # automatically by virtualisation.docker.rootless)
    docker-compose

    maven

    # Networking tools (curl, wget, lsof, openssh are above)
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

  environment.sessionVariables = {
    # Time zone database for programs that don't find it on their own.
    TZDIR = "/etc/zoneinfo";
  };

  ############################
  ## Git
  ############################

  programs.git.enable = true;

  ############################
  ## Zoxide
  ############################

  programs.zoxide.enable = true;
  programs.zoxide.enableBashIntegration = true;
  programs.zoxide.enableFishIntegration = true;

  ############################
  ## SSH
  ############################

  services.openssh.enable = true;

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
