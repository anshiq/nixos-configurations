# /etc/nixos/configuration.nix

{ config, lib, pkgs, ... }:

{
  imports = [
   
  ];

  ############################
  ## WSL Configuration
  ############################

  wsl.enable = true;
  wsl.defaultUser = "nixos";
  wsl.interop.register= true;
  wsl.wslConf.interop.enabled = true;

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


  ############################
  ## Fish Shell
  ############################

  programs.ssh.startAgent = true;
  
  ############################
  ## System Packages
  ############################

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
  ];

  ############################
  ## Git
  ############################

  programs.git.enable = true;

  ############################
  ## SSH
  ############################

  services.openssh.enable = true;

  ############################
  ## Starship Prompt
  ############################

  programs.starship.enable = true;

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
