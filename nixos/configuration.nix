# /etc/nixos/configuration.nix
#
# Everything shared by every machine. Hardware lives in hosts/<name>/ (its
# hardware-configuration.nix plus the modules/hardware/* pieces it opts into:
# boot loader, CPU, VM guest); flake.nix builds one system per host. See
# hosts/README.md.

{
  lib,
  pkgs,
  ...
}:

{
  ############################
  ## Native NixOS
  ############################

  nixpkgs.config.allowUnfree = true;

  ############################
  ## Boot speed
  ############################
  # Measured 2026-11-11 with systemd-analyze on a 2-core Ryzen 3 3250U laptop.

  # No boot menu wait (it cost 3-6s every boot). The menu is still reachable:
  # hold Space while the machine powers on to pick an older generation.
  boot.loader.timeout = 0;

  # Quiet boot console: systemd/kernel/udev messages go to the journal only
  # (`journalctl -b`), not to the framebuffer console.
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
  ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;

  # Each host sets its own name; this is only the fallback.
  networking.hostName = lib.mkDefault "nixos";
  networking.networkmanager.enable = true; # nmcli / nmtui

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
  # Do not export a global LD_LIBRARY_PATH on native NixOS: it can override
  # package-specific library resolution and make otherwise reproducible apps unstable.
  # environment.variables.LD_LIBRARY_PATH =
  #   lib.makeLibraryPath config.programs.nix-ld.libraries;

  ############################
  ## Fish Shell
  ############################

  programs.fish.enable = true;
  # The fish module turns on the man-page index (needed for its man
  # completions) and builds it with a mandb.service on *every boot* (rsync +
  # mandb, ~123 MB read). Build it into the system closure instead.
  documentation.man.cache.generateAtRuntime = false;

  users.users.nixos = {
    isNormalUser = true;
    description = "NixOS User";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "kvm"
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
  # Boot speed: don't start dockerd (and its restart=unless-stopped containers)
  # at the same moment as everything else on a 2-core CPU. A timer starts it
  # 15s after the user manager comes up (i.e. after login). `systemctl --user
  # start docker` still works any time; until then the docker CLI reports it
  # cannot connect to the daemon.
  systemd.user.services.docker.wantedBy = lib.mkForce [ ];
  systemd.user.timers.docker-delayed = {
    description = "Start rootless Docker shortly after login";
    wantedBy = [ "default.target" ];
    timerConfig = {
      OnActiveSec = "15s";
      Unit = "docker.service";
    };
  };

  ############################
  ## QEMU/KVM Virtualization (libvirt, driven with virsh)
  ############################
  virtualisation.libvirtd.enable = true;
  # Boot speed: libvirtd.socket stays enabled, so the first client (virsh,
  # virt-manager) starts the daemon on demand instead of at boot.
  # libvirt-guests only autostarts/suspends VMs, of which there are none.
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];
  systemd.services.libvirt-guests.wantedBy = lib.mkForce [ ];

  ############################
  ## System Packages
  ############################
  #
  # Tools configured through a programs.* module (fish, starship, git, zoxide
  # here; fzf, helix, zellij, yazi in home.nix) are not repeated in this list:
  # the module installs the package. This is the headless branch: GUI
  # applications and the Hyprland/Quickshell desktop live on the desktop branch.

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
    openssl

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

    # Text / file tools
    sd # intuitive find-and-replace (sed alternative)
    delta # git diff pager, wired up in programs.git.config below

    # Sync & backup
    rsync
    rclone
    restic

    # Windows-formatted drives (read/write NTFS)
    ntfs3g

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
  # delta as the pager for diff/log/show/blame (system gitconfig; ~/.gitconfig
  # still overrides).
  programs.git.config = {
    core.pager = "delta";
    interactive.diffFilter = "delta --color-only";
    delta = {
      navigate = true;
      line-numbers = true;
    };
    merge.conflictStyle = "zdiff3";
  };

  ############################
  ## Zoxide
  ############################

  programs.zoxide.enable = true;
  programs.zoxide.enableBashIntegration = true;
  programs.zoxide.enableFishIntegration = true;

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

  # Keep the store from growing without bound: weekly GC of anything older
  # than 14 days (current + recent generations stay), and hard-link dedupe.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  # SSD TRIM, compressed swap in RAM, and firmware updates (`fwupdmgr`).
  services.fstrim.enable = true;
  zramSwap.enable = true;
  services.fwupd.enable = true;

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
